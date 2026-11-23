/// What the profile screen shows about the signed-in person. A plain Dart value so `logic/` and
/// `view/` never touch Firebase types.
class AuthProfile {
  const AuthProfile({
    required this.displayName,
    required this.email,
    required this.phone,
    this.photoUrl,
    this.createdAt,
    this.lastSignInAt,
    this.emailVerified = false,
    this.providers = const [],
  });

  final String displayName;
  final String email;
  final String phone;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;
  final bool emailVerified;

  /// Firebase provider ids: `password`, `google.com`, `facebook.com`.
  final List<String> providers;

  bool get usesPassword => providers.contains('password');
}

/// `logic/` imports this interface only — never Firebase APIs directly (see repository-di.md).
abstract class AuthRepository {
  Future<void> signInWithEmail({required String identifier, required String password});

  Future<void> signUpWithEmail({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  });

  /// Signs in via Google AND requests Drive scope in the same consent flow, per the confirmed
  /// architecture decision (one sign-in, two purposes — see README "الخلفية السحابية").
  Future<void> signInWithGoogle();

  Future<void> signInWithFacebook();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();

  /// Proves the person at the keyboard owns the signed-in account, without changing the session:
  /// e-mail accounts must pass their account [password]; Google / Facebook accounts are asked to
  /// sign in with that provider again. Throws [ValidationException] (`invalidCredentials`, …) when
  /// it fails and `ValidationException('cancelled')` when the person backs out of the provider.
  Future<void> reauthenticate({String? password});

  /// The signed-in person's profile, or `null` when nobody is signed in.
  AuthProfile? get currentProfile;

  /// Changes the display name (Firebase profile). Throws [ValidationException] on failure.
  Future<void> updateDisplayName(String name);

  /// Sends the e-mail verification link to the signed-in person.
  Future<void> sendEmailVerification();

  Stream<bool> get authStateChanges;
}
