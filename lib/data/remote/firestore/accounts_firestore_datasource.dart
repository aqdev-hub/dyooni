import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/account.dart';

class AccountsFirestoreDataSource {
  AccountsFirestoreDataSource(this._firestore, this._auth);
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _collection {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('A signed-in user is required for cloud data.');
    return _firestore.collection('users').doc(uid).collection('accounts');
  }

  Future<List<Account>> getAll() async => (await _collection.orderBy('updatedAt', descending: true).get()).docs.map(_fromDoc).toList();
  Stream<List<Account>> watchAll() => _collection.orderBy('updatedAt', descending: true).snapshots().map((snapshot) => snapshot.docs.map(_fromDoc).toList());

  Future<void> save(Account account) async {
    final json = account.toJson()..['updatedAt'] = DateTime.now().toIso8601String();
    await _collection.doc(account.id).set(json);
  }

  Future<void> delete(String id) => _collection.doc(id).delete();

  Account _fromDoc(DocumentSnapshot<Map<String, dynamic>> document) => Account.fromJson({...document.data()!, 'id': document.id});
}
