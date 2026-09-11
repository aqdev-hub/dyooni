import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/app_exception.dart';

/// Talks to Firestore only — a single small "phone -> email" lookup collection that makes
/// phone-number sign-in possible on top of Firebase Auth's email/password provider (which has no
/// native concept of a phone identifier for that sign-in method). No business rules here — see
/// AuthRepositoryImpl for what a missing mapping means.
///
/// REQUIRES a Firestore security rule allowing `phone_lookup/{doc}` to be READ before the caller
/// is authenticated — the whole point is resolving an email BEFORE sign-in succeeds, so this
/// cannot be gated behind `request.auth != null` the way the rest of the app's future Firestore
/// data will be. WRITE only ever happens immediately after the caller's own successful sign-up
/// (see AuthRepositoryImpl.signUpWithEmail), so it can safely require `request.auth != null`.
/// Suggested rule, until this collection gets a dedicated Cloud Function instead:
/// ```
/// match /phone_lookup/{phone} {
///   allow read: if true;
///   allow write: if request.auth != null;
/// }
/// ```
/// Known trade-off, stated plainly: that read rule makes phone->email pairs guessable by anyone
/// who can reach Firestore — acceptable for this batch's scope, not a final answer for privacy.
class UserDirectoryRemoteDataSource {
  const UserDirectoryRemoteDataSource(this._firestore);
  final FirebaseFirestore _firestore;

  static const _collection = 'phone_lookup';

  Future<void> savePhoneMapping({required String normalizedPhone, required String email}) async {
    try {
      await _firestore.collection(_collection).doc(normalizedPhone).set({'email': email});
    } catch (e) {
      throw StorageException(internalDetail: e.toString());
    }
  }

  Future<String?> lookupEmailByPhone(String normalizedPhone) async {
    try {
      final doc = await _firestore.collection(_collection).doc(normalizedPhone).get();
      return doc.data()?['email'] as String?;
    } catch (e) {
      throw StorageException(internalDetail: e.toString());
    }
  }
}
