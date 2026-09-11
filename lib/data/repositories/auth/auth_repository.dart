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

  Stream<bool> get authStateChanges;
}
