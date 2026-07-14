import '../models/court.dart';
import '../models/happy_hour_rule.dart';
import 'time_utils.dart';

/// A busy time range on a court (from a booking or an owner block).
class BusyInterval {
  final int start;
  final int end;

  const BusyInterval(this.start, this.end);

  bool overlaps(int otherStart, int otherEnd) =>
      otherStart < end && otherEnd > start;
}

/// One bookable start time offered to the customer.
class SlotOption {
  final int startMinutes;
  final int durationMinutes;
  final double price;
  final HappyHourRule? happyHour; // non-null when a discount applies

  const SlotOption({
    required this.startMinutes,
    required this.durationMinutes,
    required this.price,
    this.happyHour,
  });

  int get endMinutes => startMinutes + durationMinutes;
}

/// Pure booking/pricing logic — no Firebase, fully unit-testable.
class SlotEngine {
  SlotEngine._();

  /// Returns the price for a game and the happy-hour rule applied (if any).
  /// Pricing uses the START time of the game only, per club policy.
  static ({double price, HappyHourRule? rule}) priceFor({
    required Court court,
    required int durationMinutes,
    required String date,
    required int startMinutes,
    required List<HappyHourRule> rules,
  }) {
    final base = court.priceFor(durationMinutes) ?? 0;
    final weekday = weekdayOf(date);
    for (final rule in rules) {
      if (rule.matches(
        branchId: court.branchId,
        courtId: court.id,
        weekday: weekday,
        startMin: startMinutes,
      )) {
        if (rule.discountType == DiscountType.percent) {
          final discounted = base * (1 - rule.value / 100);
          return (price: _round2(discounted), rule: rule);
        }
        // Fixed price is PER HOUR: $20/h -> $30 for 90min, $40 for 120min.
        // An explicit per-duration override in fixedPrices still wins.
        final fixed = rule.fixedPrices[durationMinutes] ??
            rule.value * (durationMinutes / 60);
        return (price: _round2(fixed), rule: rule);
      }
    }
    return (price: _round2(base), rule: null);
  }

  /// All available start times for a court on a date, given existing
  /// busy intervals. A start time is offered only when the FULL duration
  /// fits inside opening hours (ends by 11:00 PM) with no overlap.
  ///
  /// [notBefore] hides slots in the past when the date is today
  /// (pass minutes-since-midnight of "now", or null for future dates).
  static List<SlotOption> availableSlots({
    required Court court,
    required int durationMinutes,
    required String date,
    required List<BusyInterval> busy,
    required List<HappyHourRule> rules,
    int? notBefore,
  }) {
    final slots = <SlotOption>[];
    for (int start = ClubHours.openMinutes;
        start + durationMinutes <= ClubHours.closeMinutes;
        start += ClubHours.slotStepMinutes) {
      if (notBefore != null && start < notBefore) continue;
      final end = start + durationMinutes;
      final conflict = busy.any((b) => b.overlaps(start, end));
      if (conflict) continue;
      final priced = priceFor(
        court: court,
        durationMinutes: durationMinutes,
        date: date,
        startMinutes: start,
        rules: rules,
      );
      slots.add(SlotOption(
        startMinutes: start,
        durationMinutes: durationMinutes,
        price: priced.price,
        happyHour: priced.rule,
      ));
    }
    return slots;
  }

  static double _round2(double v) => (v * 100).roundToDouble() / 100;
}
