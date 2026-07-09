import 'package:cloud_firestore/cloud_firestore.dart';

/// A promo banner shown as a swipeable card on the customer home screen.
/// Announcements only — pricing is handled by happy hours and vouchers.
class BannerItem {
  final String id;
  final String title;
  final String text;
  final String imageUrl; // optional; a pasted image link
  final String tournamentId; // optional; tapping opens that tournament
  final bool active;
  final int order;

  const BannerItem({
    required this.id,
    required this.title,
    required this.text,
    this.imageUrl = '',
    this.tournamentId = '',
    required this.active,
    required this.order,
  });

  factory BannerItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return BannerItem(
      id: doc.id,
      title: (data['title'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      imageUrl: (data['imageUrl'] as String?) ?? '',
      tournamentId: (data['tournamentId'] as String?) ?? '',
      active: (data['active'] as bool?) ?? false,
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'text': text,
        'imageUrl': imageUrl,
        'tournamentId': tournamentId,
        'active': active,
        'order': order,
      };
}
