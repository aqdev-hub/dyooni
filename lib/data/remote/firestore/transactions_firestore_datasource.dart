import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/transaction.dart';

class TransactionsFirestoreDataSource {
  TransactionsFirestoreDataSource(this._firestore, this._auth);
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _collection {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('A signed-in user is required for cloud data.');
    return _firestore.collection('users').doc(uid).collection('transactions');
  }

  Future<List<Transaction>> getAll() async => (await _collection.orderBy('updatedAt', descending: true).get()).docs.map(_fromDoc).toList();
  Stream<List<Transaction>> watchAll() => _collection.orderBy('updatedAt', descending: true).snapshots().map((snapshot) => snapshot.docs.map(_fromDoc).toList());

  Future<void> save(Transaction transaction) async {
    final json = transaction.toJson()..['updatedAt'] = DateTime.now().toIso8601String();
    await _collection.doc(transaction.id).set(json);
  }

  /// `save()` already writes via `.doc(id).set(...)`, which is an upsert — so "update" is
  /// literally the same call as "create" here. Kept as its own named method (rather than having
  /// callers call `save` for both) so the repository layer above reads as edit-vs-create at the
  /// call site, matching the [TransactionsRepository] interface.
  Future<void> update(Transaction transaction) => save(transaction);

  Future<void> delete(String id) => _collection.doc(id).delete();

  Future<void> deleteForAccount(String accountId) async {
    final snapshot = await _collection.where('accountId', isEqualTo: accountId).get();
    for (final chunk in _chunks(snapshot.docs, 450)) {
      final batch = _firestore.batch();
      for (final document in chunk) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }

  Transaction _fromDoc(DocumentSnapshot<Map<String, dynamic>> document) => Transaction.fromJson({...document.data()!, 'id': document.id});

  Iterable<List<T>> _chunks<T>(List<T> values, int size) sync* {
    for (var index = 0; index < values.length; index += size) {
      yield values.sublist(index, index + size > values.length ? values.length : index + size);
    }
  }
}
