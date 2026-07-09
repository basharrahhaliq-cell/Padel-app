import 'package:flutter_test/flutter_test.dart';
import 'package:padel_app/src/models/court.dart';
import 'package:padel_app/src/models/happy_hour_rule.dart';
import 'package:padel_app/src/utils/slot_engine.dart';
import 'package:padel_app/src/utils/time_utils.dart';

Court court({Map<int, double>? prices}) => Court(
      id: 'court-1',
      branchId: 'airport-road',
      name: 'Court 1',
      type: CourtType.outdoor,
      order: 0,
      prices: prices ?? {60: 30, 90: 42, 120: 55},
    );

HappyHourRule rule({
  DiscountType type = DiscountType.percent,
  double value = 20,
  List<int> days = const [1, 2, 3, 4, 5],
  int start = 8 * 60,
  int end = 16 * 60,
  List<String> courtIds = const [],
  bool active = true,
}) =>
    HappyHourRule(
      id: 'r1',
      label: 'Morning deal',
      branchId: 'airport-road',
      courtIds: courtIds,
      daysOfWeek: days,
      startMinutes: start,
      endMinutes: end,
      discountType: type,
      value: value,
      active: active,
    );

void main() {
  // 2026-07-13 is a Monday.
  const monday = '2026-07-13';
  const sunday = '2026-07-12';

  group('availability', () {
    test('first slot is 8:00 and every step is 30 minutes', () {
      final slots = SlotEngine.availableSlots(
        court: court(),
        durationMinutes: 60,
        date: monday,
        busy: [],
        rules: [],
      );
      expect(slots.first.startMinutes, 8 * 60);
      expect(slots[1].startMinutes - slots[0].startMinutes, 30);
    });

    test('last offered start lets the game end exactly at 11 PM', () {
      for (final duration in ClubHours.gameDurations) {
        final slots = SlotEngine.availableSlots(
          court: court(),
          durationMinutes: duration,
          date: monday,
          busy: [],
          rules: [],
        );
        expect(slots.last.startMinutes + duration, 23 * 60,
            reason: 'duration $duration must end at 23:00');
      }
    });

    test('a 120-min booking at 6 PM blocks 6:00-8:00', () {
      final busy = [const BusyInterval(18 * 60, 20 * 60)];
      final slots = SlotEngine.availableSlots(
        court: court(),
        durationMinutes: 60,
        date: monday,
        busy: busy,
        rules: [],
      );
      final starts = slots.map((s) => s.startMinutes).toSet();
      // 5:30 + 60min would overlap 6:00 -> excluded.
      expect(starts.contains(17 * 60 + 30), isFalse);
      expect(starts.contains(18 * 60), isFalse);
      expect(starts.contains(19 * 60 + 30), isFalse);
      // 5:00 ends exactly at 6:00 -> allowed. 8:00 starts at block end -> allowed.
      expect(starts.contains(17 * 60), isTrue);
      expect(starts.contains(20 * 60), isTrue);
    });

    test('longer duration must fully fit in a gap', () {
      // Busy 10:00-11:00 and 12:00-13:00 leaves a 60-min gap at 11:00.
      final busy = [
        const BusyInterval(10 * 60, 11 * 60),
        const BusyInterval(12 * 60, 13 * 60),
      ];
      final slots90 = SlotEngine.availableSlots(
        court: court(),
        durationMinutes: 90,
        date: monday,
        busy: busy,
        rules: [],
      );
      expect(slots90.map((s) => s.startMinutes).contains(11 * 60), isFalse);

      final slots60 = SlotEngine.availableSlots(
        court: court(),
        durationMinutes: 60,
        date: monday,
        busy: busy,
        rules: [],
      );
      expect(slots60.map((s) => s.startMinutes).contains(11 * 60), isTrue);
    });

    test('notBefore hides past slots for today', () {
      final slots = SlotEngine.availableSlots(
        court: court(),
        durationMinutes: 60,
        date: monday,
        busy: [],
        rules: [],
        notBefore: 14 * 60,
      );
      expect(slots.first.startMinutes, 14 * 60);
    });
  });

  group('pricing', () {
    test('base price without rules', () {
      final priced = SlotEngine.priceFor(
        court: court(),
        durationMinutes: 90,
        date: monday,
        startMinutes: 18 * 60,
        rules: [rule()],
      );
      expect(priced.price, 42);
      expect(priced.rule, isNull);
    });

    test('percentage discount applies inside the window', () {
      final priced = SlotEngine.priceFor(
        court: court(),
        durationMinutes: 60,
        date: monday,
        startMinutes: 10 * 60,
        rules: [rule(value: 20)],
      );
      expect(priced.price, 24); // 30 - 20%
      expect(priced.rule, isNotNull);
    });

    test('fixed price discount replaces the base price', () {
      final priced = SlotEngine.priceFor(
        court: court(),
        durationMinutes: 120,
        date: monday,
        startMinutes: 9 * 60,
        rules: [rule(type: DiscountType.fixedPrice, value: 40)],
      );
      expect(priced.price, 40);
    });

    test('rule does not apply on excluded weekdays', () {
      final priced = SlotEngine.priceFor(
        court: court(),
        durationMinutes: 60,
        date: sunday, // rule is Mon-Fri
        startMinutes: 10 * 60,
        rules: [rule()],
      );
      expect(priced.price, 30);
      expect(priced.rule, isNull);
    });

    test('overlapping a boundary keeps the START time price', () {
      // Happy hour ends 16:00; a 120-min game starting 15:30 stays discounted.
      final inWindow = SlotEngine.priceFor(
        court: court(),
        durationMinutes: 120,
        date: monday,
        startMinutes: 15 * 60 + 30,
        rules: [rule(value: 20)],
      );
      expect(inWindow.price, 44); // 55 - 20%

      // Starting exactly at 16:00 (window end, exclusive) -> full price.
      final atEnd = SlotEngine.priceFor(
        court: court(),
        durationMinutes: 120,
        date: monday,
        startMinutes: 16 * 60,
        rules: [rule(value: 20)],
      );
      expect(atEnd.price, 55);
    });

    test('inactive rules are ignored', () {
      final priced = SlotEngine.priceFor(
        court: court(),
        durationMinutes: 60,
        date: monday,
        startMinutes: 10 * 60,
        rules: [rule(active: false)],
      );
      expect(priced.price, 30);
    });

    test('court-specific rule skips other courts', () {
      final priced = SlotEngine.priceFor(
        court: court(),
        durationMinutes: 60,
        date: monday,
        startMinutes: 10 * 60,
        rules: [rule(courtIds: ['court-2'])],
      );
      expect(priced.price, 30);
    });

    test('slot options carry the happy hour tag', () {
      final slots = SlotEngine.availableSlots(
        court: court(),
        durationMinutes: 60,
        date: monday,
        busy: [],
        rules: [rule()],
      );
      final at10 =
          slots.firstWhere((s) => s.startMinutes == 10 * 60);
      final at18 =
          slots.firstWhere((s) => s.startMinutes == 18 * 60);
      expect(at10.happyHour, isNotNull);
      expect(at18.happyHour, isNull);
    });
  });
}
