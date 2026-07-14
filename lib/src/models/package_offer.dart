import 'package:cloud_firestore/cloud_firestore.dart';

/// A prepaid credit package: pay [price] at the club, receive [credit]
/// of wallet balance valid for [validityDays] days.
/// Example: pay $300 -> play with $400, valid 1 month.
class PackageOffer {
  final String id;
  final String name;
  final double price; // what the customer pays (cash at the club)
  final double credit; // what lands in their wallet
  final int validityDays;
  final bool active;
  final int order;

  const PackageOffer({
    required this.id,
    required this.name,
    required this.price,
    required this.credit,
    required this.validityDays,
    required this.active,
    this.order = 0,
  });

  factory PackageOffer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PackageOffer(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      credit: (data['credit'] as num?)?.toDouble() ?? 0,
      validityDays: (data['validityDays'] as num?)?.toInt() ?? 30,
      active: (data['active'] as bool?) ?? true,
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'price': price,
        'credit': credit,
        'validityDays': validityDays,
        'active': active,
        'order': order,
      };
}
