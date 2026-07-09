import 'package:cloud_firestore/cloud_firestore.dart';

enum DiscountType { percent, fixedPrice }

/// An owner-managed discount rule, e.g.
/// "Mon-Fri, 8:00-16:00, Airport Road, all courts -> 20% off".
///
/// The rule matches a booking when:
///  - the booking's branch matches [branchId]
///  - [courtIds] is empty (= all courts) or contains the booking's court
///  - the booking's weekday is in [daysOfWeek] (Mon=1 ... Sun=7)
///  - the booking's START time falls inside [startMinutes, endMinutes)
///  - [active] is true
class HappyHourRule {
  final String id;
  final String label;
  final String branchId;
  final List<String> courtIds; // empty = all courts of the branch
  final List<int> daysOfWeek; // ISO: Mon=1 ... Sun=7
  final int startMinutes;
  final int endMinutes;
  final DiscountType discountType;

  /// Percent off (e.g. 20) when [discountType] is percent,
  /// or the fixed USD price when fixedPrice. For fixed price the same
  /// price applies to every duration unless per-duration prices are set
  /// in [fixedPrices].
  final double value;

  /// Optional per-duration fixed prices, e.g. {60: 20, 90: 28, 120: 35}.
  /// Only used when [discountType] is fixedPrice and the entry exists.
  final Map<int, double> fixedPrices;

  final bool active;

  const HappyHourRule({
    required this.id,
    required this.label,
    required this.branchId,
    required this.courtIds,
    required this.daysOfWeek,
    required this.startMinutes,
    required this.endMinutes,
    required this.discountType,
    required this.value,
    this.fixedPrices = const {},
    required this.active,
  });

  factory HappyHourRule.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawFixed = (data['fixedPrices'] as Map<String, dynamic>?) ?? {};
    return HappyHourRule(
      id: doc.id,
      label: (data['label'] as String?) ?? 'Happy Hour',
      branchId: (data['branchId'] as String?) ?? '',
      courtIds: List<String>.from(data['courtIds'] ?? const []),
      daysOfWeek:
          List<int>.from((data['daysOfWeek'] ?? const []).map((d) => d as int)),
      startMinutes: (data['startMinutes'] as num?)?.toInt() ?? 0,
      endMinutes: (data['endMinutes'] as num?)?.toInt() ?? 0,
      discountType: data['discountType'] == 'fixedPrice'
          ? DiscountType.fixedPrice
          : DiscountType.percent,
      value: (data['value'] as num?)?.toDouble() ?? 0,
      fixedPrices: rawFixed.map(
        (k, v) => MapEntry(int.parse(k), (v as num).toDouble()),
      ),
      active: (data['active'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'branchId': branchId,
        'courtIds': courtIds,
        'daysOfWeek': daysOfWeek,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'discountType':
            discountType == DiscountType.fixedPrice ? 'fixedPrice' : 'percent',
        'value': value,
        'fixedPrices': fixedPrices.map((k, v) => MapEntry(k.toString(), v)),
        'active': active,
      };

  /// Whether this rule applies to a game starting at [startMin] on [weekday]
  /// (Mon=1..Sun=7) on court [courtId] of branch [branchId].
  bool matches({
    required String branchId,
    required String courtId,
    required int weekday,
    required int startMin,
  }) {
    if (!active) return false;
    if (this.branchId != branchId) return false;
    if (courtIds.isNotEmpty && !courtIds.contains(courtId)) return false;
    if (!daysOfWeek.contains(weekday)) return false;
    // Rule applies based on the START time only (overlap keeps start price).
    return startMin >= startMinutes && startMin < endMinutes;
  }
}
