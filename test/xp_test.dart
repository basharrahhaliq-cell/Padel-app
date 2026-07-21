import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padel_app/src/services/firestore_service.dart';
import 'package:padel_app/src/utils/time_utils.dart';
import 'package:padel_app/src/utils/xp.dart';

Map<String, Object> playedBooking(
        {bool isOpenMatch = false, bool played = true}) =>
    {
      'branchId': 'airport-road',
      'branchName': 'Airport Road',
      'courtId': 'court-1',
      'courtName': 'Court 1',
      'date': dateKey(played
          ? DateTime.now().subtract(const Duration(days: 1))
          : DateTime.now().add(const Duration(days: 1))),
      'startMinutes': 18 * 60,
      'durationMinutes': 60,
      'userId': 'u1',
      'userName': 'Test',
      'userPhone': '+9613123456',
      'price': 30.0,
      'status': 'confirmed',
      'isBlock': false,
      'isOpenMatch': isOpenMatch,
      'xpAwarded': false,
    };

void main() {
  test('levels follow the club thresholds', () {
    expect(XpSystem.levelFor(0), 1);
    expect(XpSystem.levelFor(199), 1);
    expect(XpSystem.levelFor(200), 2);
    expect(XpSystem.levelFor(499), 2);
    expect(XpSystem.levelFor(500), 3);
    expect(XpSystem.levelFor(999), 3);
    expect(XpSystem.levelFor(1000), 4);
    expect(XpSystem.levelFor(1749), 4);
    expect(XpSystem.levelFor(1750), 5); // +750
    expect(XpSystem.levelFor(2500), 6);
  });

  test('thresholds are consistent with levelFor', () {
    for (int level = 1; level <= 10; level++) {
      final xp = XpSystem.thresholdFor(level);
      expect(XpSystem.levelFor(xp), level);
      if (xp > 0) expect(XpSystem.levelFor(xp - 1), level - 1);
    }
  });

  test('progress runs 0..1 inside a level', () {
    expect(XpSystem.progress(0), 0);
    expect(XpSystem.progress(100), 0.5); // halfway to 200
    expect(XpSystem.progress(199), closeTo(0.995, 0.001));
    expect(XpSystem.progress(200), 0); // fresh level 2
  });

  test('xpToNext counts down to the next threshold', () {
    expect(XpSystem.xpToNext(0), 200);
    expect(XpSystem.xpToNext(450), 50);
    expect(XpSystem.xpToNext(1000), 750);
  });

  test('awardPendingXp settles finished games only, exactly once',
      () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({'name': 'Test', 'xp': 0});
    await db.collection('bookings').add(playedBooking()); // yesterday
    await db
        .collection('bookings')
        .add(playedBooking(isOpenMatch: true)); // yesterday, open match
    await db
        .collection('bookings')
        .add(playedBooking(played: false)); // tomorrow — no XP yet
    final service = FirestoreService(db);

    await service.awardPendingXp('u1');

    final user = await db.collection('users').doc('u1').get();
    // 50 for the normal game + 50 + 20 for the open match = 120.
    expect(user.get('xp'), 120);
    expect(user.get('matchesPlayed'), 2);

    // Running it again (every app launch does) must not double-count.
    await service.awardPendingXp('u1');
    final again = await db.collection('users').doc('u1').get();
    expect(again.get('xp'), 120);
  });
}
