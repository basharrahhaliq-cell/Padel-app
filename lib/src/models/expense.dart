import 'package:cloud_firestore/cloud_firestore.dart';

/// A club expense recorded by the owner (balls, water, salaries,
/// electricity…). branchId '' means a general expense for the club.
class Expense {
  final String id;
  final String date; // yyyy-MM-dd
  final String branchId;
  final String branchName;
  final String description;
  final double amount;

  const Expense({
    required this.id,
    required this.date,
    required this.branchId,
    required this.branchName,
    required this.description,
    required this.amount,
  });

  factory Expense.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Expense(
      id: doc.id,
      date: (data['date'] as String?) ?? '',
      branchId: (data['branchId'] as String?) ?? '',
      branchName: (data['branchName'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      amount: ((data['amount'] as num?) ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'date': date,
        'branchId': branchId,
        'branchName': branchName,
        'description': description,
        'amount': amount,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
