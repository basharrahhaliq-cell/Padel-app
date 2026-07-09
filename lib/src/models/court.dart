import 'package:cloud_firestore/cloud_firestore.dart';

enum CourtType { indoor, outdoor }

/// A court inside a branch. Base prices are stored per duration in minutes,
/// e.g. {60: 30.0, 90: 42.0, 120: 55.0} — in USD, editable by the owner.
class Court {
  final String id;
  final String branchId;
  final String name;
  final CourtType type;
  final int order;
  final Map<int, double> prices;

  const Court({
    required this.id,
    required this.branchId,
    required this.name,
    required this.type,
    required this.order,
    required this.prices,
  });

  factory Court.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc, String branchId) {
    final data = doc.data() ?? {};
    final rawPrices = (data['prices'] as Map<String, dynamic>?) ?? {};
    return Court(
      id: doc.id,
      branchId: branchId,
      name: (data['name'] as String?) ?? doc.id,
      type: data['type'] == 'outdoor' ? CourtType.outdoor : CourtType.indoor,
      order: (data['order'] as num?)?.toInt() ?? 0,
      prices: rawPrices.map(
        (k, v) => MapEntry(int.parse(k), (v as num).toDouble()),
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type == CourtType.outdoor ? 'outdoor' : 'indoor',
        'order': order,
        'prices': prices.map((k, v) => MapEntry(k.toString(), v)),
      };

  double? priceFor(int durationMinutes) => prices[durationMinutes];
}
