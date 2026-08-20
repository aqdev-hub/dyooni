import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/utils/app_exception.dart';
import '../../data/remote/auth/user_directory_remote_datasource.dart';
import '../../data/repositories/auth/auth_repository.dart';
import '../../data/repositories/auth/auth_repository_impl.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Backs phone-number login (see AuthRepositoryImpl._resolveEmail) — a single small Firestore
/// collection, not the full data layer's Firestore migration (still on the roadmap, unrelated).
final userDirectoryRemoteDataSourceProvider = Provider<UserDirectoryRemoteDataSource>(
  (ref) => UserDirectoryRemoteDataSource(ref.watch(firestoreProvider)),
);

// Drive scope requested up front, on the single shared instance — moved here from a second,
// ad-hoc `GoogleSignIn(...)` that auth_repository_impl.dart used to create inline. That bug
// meant sign-in used one plugin instance while sign-out cleared a different one, leaving a
// stale session behind — a very plausible cause of "works once, fails oddly after."
const _driveScope = 'https://www.googleapis.com/auth/drive.file';
final googleSignInProvider = Provider<GoogleSignIn>((ref) => GoogleSignIn(scopes: [_driveScope]));

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.watch(firebaseAuthProvider),
    ref.watch(googleSignInProvider),
    ref.watch(userDirectoryRemoteDataSourceProvider),
  ),
);

/// Whether a user is currently signed in — read once at app start by `SplashGate` to decide the
/// initial route (home vs. login), and can be watched anywhere else that needs live auth state.
final authStateProvider = StreamProvider<bool>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

/// Login form submission state — `AsyncData(null)` is idle/success, `AsyncError` carries an
/// `AppException` whose `code` the screen maps to a localized message.
final loginControllerProvider =
    AsyncNotifierProvider.autoDispose<LoginController, void>(LoginController.new);

class LoginController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({required String identifier, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithEmail(
            identifier: identifier,
            password: password,
          ),
    );
  }

  Future<void> submitWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).signInWithGoogle());
  }

  Future<void> submitWithFacebook() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).signInWithFacebook());
  }

  Future<void> sendPasswordResetEmail(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).sendPasswordResetEmail(email));
  }
}

final signupControllerProvider =
    AsyncNotifierProvider.autoDispose<SignupController, void>(SignupController.new);

class SignupController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
    required bool acceptedTerms,
  }) async {
    if (password != confirmPassword) {
      state = AsyncError(
        const ValidationException('passwordsDontMatch'),
        StackTrace.current,
      );
      return;
    }
    if (!acceptedTerms) {
      state = AsyncError(const ValidationException('mustAcceptTerms'), StackTrace.current);
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signUpWithEmail(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone,
            password: password,
          ),
    );
  }
}
