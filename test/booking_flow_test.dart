import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padel_app/l10n/app_localizations.dart';
import 'package:padel_app/src/models/app_user.dart';
import 'package:padel_app/src/models/branch.dart';
import 'package:padel_app/src/screens/customer/booking_flow_screen.dart';
import 'package:padel_app/src/services/firestore_service.dart';
import 'package:padel_app/src/theme.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('slot grid shows compact time boxes with prices',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('branches').doc('airport-road').set(
        {'name': 'Airport Road', 'order': 0});
    await db
        .collection('branches')
        .doc('airport-road')
        .collection('courts')
        .doc('court-1')
        .set({
      'name': 'Court 1',
      'type': 'outdoor',
      'order': 0,
      'prices': {'60': 30.0, '90': 42.0, '120': 55.0},
    });
    const profile = AppUser(
        uid: 'u1',
        name: 'Test',
        phone: '+9613123456',
        email: 't@x.com',
        role: 'customer',
        skillLevel: 'C');
    const branch =
        Branch(id: 'airport-road', name: 'Airport Road', order: 0);

    await tester.pumpWidget(Provider(
      create: (_) => FirestoreService(db),
      child: MaterialApp(
        theme: AppTheme.light(),
        // Large font scale like real phones — catches overflows.
        builder: (context, w) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: w!),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: const BookingFlowScreen(branch: branch, profile: profile),
      ),
    ));
    await tester.pumpAndSettle();

    // Default duration is 90 min -> $42 boxes, three per row.
    expect(find.text('\$42'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
