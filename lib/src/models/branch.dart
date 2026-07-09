import 'package:cloud_firestore/cloud_firestore.dart';

/// A club branch (e.g. Airport Road, Hazmieh).
class Branch {
  final String id;
  final String name;
  final int order;

  /// Court the owner reserves for academy lessons at this branch.
  /// Empty = lessons may use any court that is free.
  final String lessonCourtId;

  const Branch(
      {required this.id,
      required this.name,
      required this.order,
      this.lessonCourtId = ''});

  factory Branch.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Branch(
      id: doc.id,
      name: (data['name'] as String?) ?? doc.id,
      order: (data['order'] as num?)?.toInt() ?? 0,
      lessonCourtId: (data['lessonCourtId'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() =>
      {'name': name, 'order': order, 'lessonCourtId': lessonCourtId};
}
