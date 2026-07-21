import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padel_app/l10n/app_localizations.dart';
import 'package:padel_app/src/models/app_user.dart';
import 'package:padel_app/src/screens/customer/home_screen.dart';
import 'package:padel_app/src/services/firestore_service.dart';
import 'package:padel_app/src/services/tournament_service.dart';
import 'package:padel_app/src/theme.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Home screen shows greeting, next game, and shortcuts',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('bookings').add({
      'branchId': 'airport-road',
      'branchName': 'Airport Road',
      'courtId': 'court-1',
      'courtName': 'Court 1',
      'date': '2100-01-01', // far future -> always "next game"
      'startMinutes': 18 * 60,
      'durationMinutes': 90,
      'userId': 'u1',
      'userName': 'Bashar R',
      'userPhone': '+9613123456',
      'price': 30.0,
      'voucherDiscount': 5.0,
      'status': 'confirmed',
      'isBlock': false,
    });
    const profile = AppUser(
        uid: 'u1',
        name: 'Bashar R',
        phone: '+9613123456',
        email: 'b@x.com',
        role: 'customer',
        skillLevel: 'C');

    int? navigatedTab;
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<FirestoreService>(create: (_) => FirestoreService(db)),
        Provider<TournamentService>(create: (_) => TournamentService(db)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: HomeScreen(
              profile: profile, onGoToTab: (t) => navigatedTab = t),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Ahla Bashar'), findsOneWidget);
    // XP bar shows live numbers (profile has 0 XP -> level 2 at 200).
    expect(find.textContaining('0 XP'), findsWidgets);
    expect(find.textContaining('200 XP to level 2'), findsOneWidget);
    // Paid/Saved moved to the Profile; Home shows packages instead.
    expect(find.text('Paid'), findsNothing);
    expect(find.text('Saved'), findsNothing);
    // The four court-zone shortcuts.
    expect(find.text('Book a Court'), findsOneWidget);
    expect(find.text('Open Matches'), findsOneWidget);
    expect(find.text('Tournaments'), findsWidgets);
    expect(find.text('Academy'), findsOneWidget);
    expect(find.textContaining('Your next game'), findsOneWidget);

    await tester.ensureVisible(find.text('Academy'));
    await tester.pump();
    await tester.tap(find.text('Academy'));
    expect(navigatedTab, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home screen lists every upcoming game, not just one',
      (tester) async {
    final db = FakeFirebaseFirestore();
    for (final date in ['2100-01-01', '2100-01-03', '2100-01-05']) {
      await db.collection('bookings').add({
        'branchId': 'airport-road',
        'branchName': 'Airport Road',
        'courtId': 'court-1',
        'courtName': 'Court 1',
        'date': date,
        'startMinutes': 18 * 60,
        'durationMinutes': 90,
        'userId': 'u1',
        'userName': 'Bashar R',
        'userPhone': '+9613123456',
        'price': 30.0,
        'status': 'confirmed',
        'isBlock': false,
      });
    }
    const profile = AppUser(
        uid: 'u1',
        name: 'Bashar R',
        phone: '+9613123456',
        email: 'b@x.com',
        role: 'customer',
        skillLevel: 'C');

    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<FirestoreService>(create: (_) => FirestoreService(db)),
        Provider<TournamentService>(create: (_) => TournamentService(db)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: HomeScreen(profile: profile, onGoToTab: (_) {}),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Your upcoming games (3)'), findsOneWidget);
    // One compact row per game, all three dates visible.
    expect(find.textContaining('Jan 1'), findsOneWidget);
    expect(find.textContaining('Jan 3'), findsOneWidget);
    expect(find.textContaining('Jan 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
