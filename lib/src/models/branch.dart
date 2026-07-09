import 'package:cloud_firestore/cloud_firestore.dart';

/// A club branch (e.g. Airport Road, Hazmieh).
class Branch {
  final String id;
  final String name;
  final int order;

  const Branch({required this.id, required this.name, required this.order});

  factory Branch.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Branch(
      id: doc.id,
      name: (data['name'] as String?) ?? doc.id,
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'order': order};
}
