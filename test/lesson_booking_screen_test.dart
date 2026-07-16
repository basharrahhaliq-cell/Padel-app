import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padel_app/l10n/app_localizations.dart';
import 'package:padel_app/src/models/app_user.dart';
import 'package:padel_app/src/models/coach.dart';
import 'package:padel_app/src/screens/customer/academy_screen.dart';
import 'package:padel_app/src/services/firestore_service.dart';
import 'package:padel_app/src/theme.dart';
import 'package:provider/provider.dart';

/// The customer's lesson-times section must resolve (times or a clear
/// message) — it used to restart loading on every rebuild and appear
/// as an endless spinner.
void main() {
  testWidgets('lesson booking shows the coach\'s free times',
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
      'prices': {'60': 30.0},
    });
    // Works 9:00-13:00 every day, so "today" always has windows.
    final coach = Coach(
      id: 'c1',
      name: 'Rami',
      branchIds: const ['airport-road'],
      prices: const {'private': 40, 'semi': 30, 'group': 25},
      availability: {
        for (int d = 1; d <= 7; d++) d: const [CoachWindow(9 * 60, 13 * 60)],
      },
      active: true,
    );
    const profile = AppUser(
        uid: 'u1',
        name: 'Test',
        phone: '+9613123456',
        email: 't@x.com',
        role: 'customer',
        skillLevel: 'C');

    await tester.pumpWidget(Provider(
      create: (_) => FirestoreService(db),
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: LessonBookingScreen(coach: coach, profile: profile),
      ),
    ));
    await tester.pumpAndSettle();

    // Resolved: either time chips (day not over) or the no-times
    // message (test running after 12:00) — never a stuck spinner.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final hasTimes = find.text('9:00 AM').evaluate().isNotEmpty ||
        find.textContaining('No free times').evaluate().isNotEmpty;
    expect(hasTimes, isTrue);
    expect(tester.takeException(), isNull);
  });
}
