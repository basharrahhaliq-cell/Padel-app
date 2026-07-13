import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padel_app/l10n/app_localizations.dart';
import 'package:padel_app/src/screens/admin/customers_screen.dart';
import 'package:padel_app/src/screens/admin/pricing_screen.dart';
import 'package:padel_app/src/screens/admin/revenue_screen.dart';
import 'package:padel_app/src/services/firestore_service.dart';
import 'package:provider/provider.dart';

/// Renders the owner screens against a fake database seeded exactly like
/// the real club, to catch crashes/white-screens before they reach phones.
Future<FakeFirebaseFirestore> seededDb() async {
  final db = FakeFirebaseFirestore();
  const prices = {'60': 30.0, '90': 42.0, '120': 55.0};
  final airport = db.collection('branches').doc('airport-road');
  await airport.set({'name': 'Airport Road', 'order': 0});
  await airport.collection('courts').doc('court-1').set(
      {'name': 'Court 1', 'type': 'outdoor', 'order': 0, 'prices': prices});
  await airport.collection('courts').doc('court-2').set(
      {'name': 'Court 2', 'type': 'indoor', 'order': 1, 'prices': prices});
  final hazmieh = db.collection('branches').doc('hazmieh');
  await hazmieh.set({'name': 'Hazmieh', 'order': 1});
  await hazmieh.collection('courts').doc('court-1').set(
      {'name': 'Court 1', 'type': 'indoor', 'order': 0, 'prices': prices});

  await db.collection('users').doc('u1').set({
    'name': 'Test Customer',
    'phone': '+9613123456',
    'email': 'test@x.com',
    'role': 'customer',
    'skillLevel': 'C',
    'marketingConsent': true,
    'notifyOpenMatches': true,
  });
  await db.collection('bookings').add({
    'branchId': 'airport-road',
    'courtId': 'court-1',
    'branchName': 'Airport Road',
    'courtName': 'Court 1',
    'date': '2026-07-13',
    'startMinutes': 18 * 60,
    'durationMinutes': 90,
    'endMinutes': 19 * 60 + 30,
    'userId': 'u1',
    'userName': 'Test Customer',
    'userPhone': '+9613123456',
    'price': 42.0,
    'status': 'confirmed',
    'isBlock': false,
    'xpAwarded': false,
    'isOpenMatch': false,
    'isLesson': false,
  });
  return db;
}

Widget wrap(FakeFirebaseFirestore db, Widget child) => MultiProvider(
      providers: [
        Provider<FirestoreService>(create: (_) => FirestoreService(db)),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: child,
      ),
    );

void main() {
  testWidgets('Pricing screen renders courts and prices', (tester) async {
    final db = await seededDb();
    await tester.pumpWidget(wrap(db, const Scaffold(body: PricingScreen())));
    await tester.pumpAndSettle();
    expect(find.textContaining('Airport Road'), findsWidgets);
    expect(find.textContaining('Court 1'), findsWidgets);
    expect(find.textContaining('Happy hour rules'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Customers screen renders stats without crashing',
      (tester) async {
    final db = await seededDb();
    await tester.pumpWidget(wrap(db, CustomersScreen(firestore: db)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Test Customer'), findsOneWidget);
    expect(find.textContaining('1 bookings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Revenue screen renders totals without crashing',
      (tester) async {
    final db = await seededDb();
    await tester
        .pumpWidget(wrap(db, const Scaffold(body: RevenueScreen())));
    await tester.pumpAndSettle();
    expect(find.textContaining('Today'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
