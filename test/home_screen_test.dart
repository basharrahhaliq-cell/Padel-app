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
    await tester.pumpAndSettle();

    expect(find.textContaining('Ahla Bashar'), findsOneWidget);
    expect(find.textContaining('Play more to increase your level'),
        findsOneWidget);
    expect(find.text('Book a Court'), findsOneWidget);
    expect(find.text('Open Matches'), findsOneWidget);
    expect(find.text('Tournaments'), findsOneWidget);
    expect(find.text('Academy'), findsOneWidget);
    expect(find.textContaining('Your next game'), findsOneWidget);
    expect(find.textContaining('Airport Road'), findsWidgets);

    await tester.ensureVisible(find.text('Academy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Academy'));
    expect(navigatedTab, 3);
    expect(tester.takeException(), isNull);
  });
}
