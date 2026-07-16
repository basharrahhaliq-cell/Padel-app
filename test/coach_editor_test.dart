import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padel_app/src/models/coach.dart';
import 'package:padel_app/src/screens/admin/coaches_screen.dart';
import 'package:padel_app/src/services/firestore_service.dart';
import 'package:padel_app/src/theme.dart';
import 'package:padel_app/src/widgets/coach_avatar.dart';
import 'package:provider/provider.dart';

Widget wrap(FakeFirebaseFirestore db, Widget child) => Provider(
      create: (_) => FirestoreService(db),
      child: MaterialApp(
        theme: AppTheme.light(),
        // Large font scale like on real phones — catches overflows.
        builder: (context, w) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: w!),
        home: child,
      ),
    );

void main() {
  testWidgets('working-hours dialog fits at a big font scale',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await tester.pumpWidget(wrap(db, const CoachEditorScreen()));
    await tester.pumpAndSettle();

    // Open Monday's "add working hours" dialog (scroll down to it).
    await tester.scrollUntilVisible(find.text('Monday'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Monday — working hours'), findsOneWidget);
    expect(find.text('From'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
    // The old side-by-side layout overflowed by 24px here.
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.textContaining('9:00'), findsOneWidget); // window chip
    expect(tester.takeException(), isNull);
  });

  testWidgets('coach photo stored in the database is shown',
      (tester) async {
    // A real 1×1 transparent PNG, base64-encoded — like a saved photo.
    const tinyPng =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
        'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
    final coach = Coach(
      id: 'c1',
      name: 'Rami',
      photoData: tinyPng,
      branchIds: const [],
      prices: const {},
      availability: const {},
      active: true,
    );
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CoachAvatar(coach: coach))));
    await tester.pumpAndSettle();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    final image = avatar.backgroundImage;
    expect(image, isA<MemoryImage>());
    expect((image as MemoryImage).bytes,
        Uint8List.fromList(base64Decode(tinyPng)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('corrupt photo data falls back to the initial letter',
      (tester) async {
    final coach = Coach(
      id: 'c1',
      name: 'Rami',
      photoData: '!!!not-base64!!!',
      branchIds: const [],
      prices: const {},
      availability: const {},
      active: true,
    );
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CoachAvatar(coach: coach))));
    await tester.pumpAndSettle();

    expect(find.text('R'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
