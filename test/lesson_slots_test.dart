import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padel_app/src/models/branch.dart';
import 'package:padel_app/src/models/coach.dart';
import 'package:padel_app/src/models/court.dart';
import 'package:padel_app/src/services/firestore_service.dart';
import 'package:padel_app/src/utils/time_utils.dart';

/// The coach's bookable times must respect the COURTS' occupancy, not
/// just the coach's own schedule: a coach who works 9–13 at Airport
/// has nothing to offer if Airport's courts are full then.
void main() {
  const branch = Branch(id: 'airport-road', name: 'Airport Road', order: 0);
  const court = Court(
      id: 'court-1',
      branchId: 'airport-road',
      name: 'Court 1',
      type: CourtType.outdoor,
      order: 0,
      prices: {60: 30});
  final tomorrow = dateKey(DateTime.now().add(const Duration(days: 1)));
  Coach coach() => Coach(
        id: 'c1',
        name: 'Rami',
        branchIds: const ['airport-road'],
        prices: const {'private': 40},
        availability: {
          DateTime.now().add(const Duration(days: 1)).weekday:
              const [CoachWindow(9 * 60, 13 * 60)],
        },
        active: true,
      );

  test('no lesson slots when the courts are fully booked', () async {
    final db = FakeFirebaseFirestore();
    // The whole 9–13 window is taken on the branch's only court.
    await db
        .collection('courtDays')
        .doc('airport-road_court-1_$tomorrow')
        .set({
      'intervals': [
        {'start': 9 * 60, 'end': 13 * 60, 'bookingId': 'x'},
      ],
    });
    final service = FirestoreService(db);

    final slots = await service.lessonSlots(
        coach: coach(),
        branch: branch,
        courts: const [court],
        date: tomorrow);

    expect(slots, isEmpty);
  });

  test('slots skip busy court hours but offer the free ones', () async {
    final db = FakeFirebaseFirestore();
    // Court busy 9–11; the coach can still teach 11–13.
    await db
        .collection('courtDays')
        .doc('airport-road_court-1_$tomorrow')
        .set({
      'intervals': [
        {'start': 9 * 60, 'end': 11 * 60, 'bookingId': 'x'},
      ],
    });
    final service = FirestoreService(db);

    final slots = await service.lessonSlots(
        coach: coach(),
        branch: branch,
        courts: const [court],
        date: tomorrow);

    final starts = slots.map((s) => s.$1).toList();
    expect(starts, isNot(contains(9 * 60)));
    expect(starts, isNot(contains(10 * 60)));
    expect(starts, contains(11 * 60));
    expect(starts, contains(12 * 60)); // 12–13 still inside the window
  });

  test('slots skip hours where the coach already teaches', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('coachDays').doc('c1_$tomorrow').set({
      'intervals': [
        {'start': 11 * 60, 'end': 12 * 60, 'bookingId': 'x'},
      ],
    });
    final service = FirestoreService(db);

    final slots = await service.lessonSlots(
        coach: coach(),
        branch: branch,
        courts: const [court],
        date: tomorrow);

    final starts = slots.map((s) => s.$1).toList();
    expect(starts, contains(9 * 60));
    expect(starts, isNot(contains(11 * 60)));
    expect(starts, contains(12 * 60));
  });
}
