import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/utils/app_exception.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/phone_utils.dart';
import '../../remote/auth/user_directory_remote_datasource.dart';
import 'auth_repository.dart';

/// Requires a real Firebase project: run `flutterfire configure` to generate
/// `firebase_options.dart` and call `Firebase.initializeApp()` in `main.dart` before this
/// repository is used — see README "الخلفية السحابية والمصادقة".
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._firebaseAuth, this._googleSignIn, this._userDirectory);

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final UserDirectoryRemoteDataSource _userDirectory;

  @override
  Future<void> signInWithEmail({required String identifier, required String password}) async {
    // Resolved OUTSIDE the try/catch below on purpose: a missing-phone-mapping failure here is
    // already the correct ValidationException('userNotFound') — routing it through the generic
    // FirebaseAuthException/catch-all block below would just re-wrap it as a less specific error.
    final email = await _resolveEmail(identifier);
    try {
      await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw ValidationException(_mapAuthErrorCode(e.code), internalDetail: e.message);
    } catch (e, st) {
      appLogger.e('signInWithEmail failed', error: e, stackTrace: st);
      throw UnexpectedException(internalDetail: e.toString());
    }
  }

  /// The login field accepts either an email OR a phone number (see loginIdentifierLabel).
  /// Firebase Auth's email/password provider has no native phone identifier, so a phone number
  /// is resolved to the email it was registered with via [_userDirectory] — populated at
  /// sign-up time in [signUpWithEmail]. Fixes the reported bug where a correct phone + password
  /// always failed: the identifier was previously passed straight to Firebase as `email` no
  /// matter what the user typed.
  Future<String> _resolveEmail(String identifier) async {
    if (looksLikeEmail(identifier)) return identifier;
    try {
      final normalized = normalizePhoneForLookup(identifier);
      final email = await _userDirectory.lookupEmailByPhone(normalized);
      if (email == null) throw const ValidationException('userNotFound');
      return email;
    } on AppException {
      rethrow;
    } catch (e, st) {
      appLogger.e('phone lookup failed', error: e, stackTrace: st);
      throw UnexpectedException(internalDetail: e.toString());
    }
  }

  @override
  Future<void> signUpWithEmail({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName('$firstName $lastName');

      // Saves the phone -> email mapping that makes phone-number LOGIN possible (see
      // _resolveEmail above). Known edge case, stated plainly: if this write fails after the
      // Firebase account above was already created successfully, the account exists but won't be
      // findable by phone until the person signs in with email at least once and this batch adds
      // a retry — no silent data loss of the account itself, just of the phone shortcut.
      if (phone.trim().isNotEmpty) {
        await _userDirectory.savePhoneMapping(
          normalizedPhone: normalizePhoneForLookup(phone),
          email: email,
        );
      }
      // TODO(flutter-architect): persist phone + names to a Firestore `users/{uid}` document once
      // the collection schema is defined (Phase 1 data layer) — Firebase Auth alone doesn't store
      // a phone number for email/password accounts.
    } on FirebaseAuthException catch (e) {
      throw ValidationException(_mapAuthErrorCode(e.code), internalDetail: e.message);
    } catch (e, st) {
      appLogger.e('signUpWithEmail failed', error: e, stackTrace: st);
      throw UnexpectedException(internalDetail: e.toString());
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      // Uses the SAME injected instance every time (see googleSignInProvider in
      // logic/auth/auth_provider.dart) — previously this created a second, separate GoogleSignIn
      // instance here, so sign-out (which clears `_googleSignIn`) never actually cleared the one
      // sign-in itself had used. That mismatch is a very plausible cause of unreliable Google
      // sign-in behavior; this is now fixed structurally, not worked around.
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // user cancelled — not an error
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw ValidationException(_mapAuthErrorCode(e.code), internalDetail: e.message);
    } catch (e, st) {
      appLogger.e('signInWithGoogle failed', error: e, stackTrace: st);
      throw UnexpectedException(internalDetail: e.toString());
    }
  }

  @override
  Future<void> signInWithFacebook() async {
    try {
      final result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.cancelled) return; // user cancelled — not an error
      if (result.status != LoginStatus.success || result.accessToken == null) {
        throw const UnexpectedException(internalDetail: 'Facebook login did not return a token');
      }
      final credential = FacebookAuthProvider.credential(result.accessToken!.tokenString);
      await _firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw ValidationException(_mapAuthErrorCode(e.code), internalDetail: e.message);
    } catch (e, st) {
      appLogger.e('signInWithFacebook failed', error: e, stackTrace: st);
      throw UnexpectedException(internalDetail: e.toString());
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw ValidationException(_mapAuthErrorCode(e.code), internalDetail: e.message);
    } catch (e, st) {
      appLogger.e('sendPasswordResetEmail failed', error: e, stackTrace: st);
      throw UnexpectedException(internalDetail: e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    // FIX for "logout doesn't take effect until the app is restarted": this used to be
    // `Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut(), FacebookAuth...logOut()])`.
    // Google's and Facebook's plugins can throw when signOut/logOut is called on a session that
    // provider never actually started (a real, commonly-seen behavior of both SDKs — e.g. a user
    // who only ever signed in with email/password). `Future.wait` propagates the FIRST such
    // failure straight up through `signOut()`. The drawer's `_confirmLogout` awaited this with no
    // try/catch, so that exception silently stopped execution right there — BEFORE it ever
    // reached `context.go('/login')`. Firebase's own session was still cleared underneath
    // (`_firebaseAuth.signOut()` had already run inside the same `Future.wait`), which is exactly
    // why the NEXT app launch — where `SplashGate` reads `authStateProvider` completely fresh —
    // correctly showed the login screen, while the CURRENT session stayed stuck on Home.
    // Each provider's sign-out now runs independently and a failure in one can never hide the
    // other two succeeding or block the caller from reaching its own navigation code.
    await _firebaseAuth.signOut();
    await _safeSignOut(() => _googleSignIn.signOut());
    await _safeSignOut(() => FacebookAuth.instance.logOut());
  }

  Future<void> _safeSignOut(Future<void> Function() signOutCall) async {
    try {
      await signOutCall();
    } catch (e, st) {
      // Logged, never rethrown — see the doc comment on signOut() above for why a provider that
      // was never actually used throwing here must not block the rest of sign-out.
      appLogger.e('Non-Firebase sign-out step failed (ignored)', error: e, stackTrace: st);
    }
  }

  @override
  Stream<bool> get authStateChanges =>
      _firebaseAuth.authStateChanges().map((user) => user != null);

  /// Maps Firebase's error codes to l10n keys — `view/` never sees a Firebase-specific string.
  String _mapAuthErrorCode(String code) => switch (code) {
        'invalid-email' => 'invalidEmail',
        'user-not-found' => 'userNotFound',
        'wrong-password' || 'invalid-credential' => 'invalidCredentials',
        'email-already-in-use' => 'emailAlreadyInUse',
        'weak-password' => 'passwordTooShort',
        'network-request-failed' => 'networkUnreachable',
        'too-many-requests' => 'tooManyRequests',
        'user-disabled' => 'userDisabled',
        _ => 'unexpectedError',
      };
}
