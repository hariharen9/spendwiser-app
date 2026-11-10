import 'package:cloud_firestore/cloud_firestore.dart';

/// Document and collection references for the web app's Firestore schema.
///
/// Everything lives under `spenders/{uid}`; the app never touches `analytics`.
class FirestoreRefs {
  FirestoreRefs(this.db, this.uid);

  final FirebaseFirestore db;
  final String uid;

  DocumentReference<Map<String, dynamic>> get user =>
      db.collection('spenders').doc(uid);

  CollectionReference<Map<String, dynamic>> get transactions =>
      user.collection('transactions');

  CollectionReference<Map<String, dynamic>> get accounts =>
      user.collection('accounts');

  CollectionReference<Map<String, dynamic>> get budgets =>
      user.collection('budgets');

  DocumentReference<Map<String, dynamic>> get totalBudget =>
      user.collection('totalBudget').doc('current');

  CollectionReference<Map<String, dynamic>> get goals =>
      user.collection('goals');

  CollectionReference<Map<String, dynamic>> get loans =>
      user.collection('loans');

  CollectionReference<Map<String, dynamic>> get recurring =>
      user.collection('recurring_transactions');

  CollectionReference<Map<String, dynamic>> get shortcuts =>
      user.collection('shortcuts');

  CollectionReference<Map<String, dynamic>> get participants =>
      user.collection('billSplittingParticipants');

  CollectionReference<Map<String, dynamic>> get splitGroups =>
      user.collection('billSplittingGroups');

  CollectionReference<Map<String, dynamic>> expenses(String groupId) =>
      splitGroups.doc(groupId).collection('expenses');

  CollectionReference<Map<String, dynamic>> settledPayments(String groupId) =>
      splitGroups.doc(groupId).collection('settledPayments');
}
