import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padel_app/src/screens/admin/accounting_screen.dart';
import 'package:padel_app/src/services/firestore_service.dart';
import 'package:padel_app/src/theme.dart';
import 'package:padel_app/src/utils/time_utils.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Accounting shows income, expenses and profit',
      (tester) async {
    final db = FakeFirebaseFirestore();
    final today = dateKey(DateTime.now());
    await db.collection('branches').doc('airport-road').set(
        {'name': 'Airport Road', 'order': 0});
    // One booking with $25 cash recorded this month.
    await db.collection('bookings').add({
      'branchId': 'airport-road',
      'branchName': 'Airport Road',
      'courtId': 'court-1',
      'courtName': 'Court 1',
      'date': today,
      'startMinutes': 18 * 60,
      'durationMinutes': 60,
      'userId': 'u1',
      'userName': 'Test',
      'userPhone': '+9613123456',
      'price': 30.0,
      'paidAmount': 25.0,
      'status': 'confirmed',
      'isBlock': false,
    });
    // A package paid $300.
    await db.collection('walletTopUps').add({
      'uid': 'u1',
      'customerName': 'Test',
      'packageName': 'VIP',
      'paid': 300.0,
      'credit': 400.0,
      'date': today,
    });
    // An expense of $40.
    await db.collection('expenses').add({
      'date': today,
      'branchId': '',
      'branchName': '',
      'description': 'Padel balls',
      'amount': 40.0,
    });

    await tester.pumpWidget(Provider(
      create: (_) => FirestoreService(db),
      child: MaterialApp(
          theme: AppTheme.light(), home: const AccountingScreen()),
    ));
    await tester.pumpAndSettle();

    // Income 25 + 300 = 325; expenses 40; profit 285.
    expect(find.text('\$325.00'), findsOneWidget);
    expect(find.text('\$285.00'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Padel balls'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Padel balls'), findsOneWidget);
    expect(find.textContaining('− \$40.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
