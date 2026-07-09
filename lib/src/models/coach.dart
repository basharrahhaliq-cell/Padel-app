import 'package:cloud_firestore/cloud_firestore.dart';

/// Lesson session types and their headcount.
const Map<String, String> kSessionTypes = {
  'private': 'Private (1 person)',
  'semi': 'Semi-private (2 people)',
  'group': 'Group (up to 4)',
};

/// A weekly availability window, e.g. Monday 9:00–13:00.
class CoachWindow {
  final int start; // minutes since midnight
  final int end;

  const CoachWindow(this.start, this.end);
}

/// An academy coach: profile, per-session-type prices, weekly schedule.
class Coach {
  final String id;
  final String name;
  final String photoUrl;
  final String bio;
  final List<String> branchIds;
  final Map<String, double> prices; // sessionType -> USD per session
  final Map<int, List<CoachWindow>> availability; // ISO weekday -> windows
  final bool active;

  const Coach({
    required this.id,
    required this.name,
    this.photoUrl = '',
    this.bio = '',
    required this.branchIds,
    required this.prices,
    required this.availability,
    required this.active,
  });

  double priceFor(String sessionType) => prices[sessionType] ?? 0;

  factory Coach.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawPrices = (data['prices'] as Map<String, dynamic>?) ?? {};
    final rawAvail = (data['availability'] as Map<String, dynamic>?) ?? {};
    return Coach(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      photoUrl: (data['photoUrl'] as String?) ?? '',
      bio: (data['bio'] as String?) ?? '',
      branchIds: List<String>.from(data['branchIds'] ?? const []),
      prices: rawPrices.map((k, v) => MapEntry(k, (v as num).toDouble())),
      availability: rawAvail.map((k, v) => MapEntry(
          int.parse(k),
          [
            for (final w in (v as List))
              CoachWindow(
                  (w['start'] as num).toInt(), (w['end'] as num).toInt())
          ])),
      active: (data['active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'photoUrl': photoUrl,
        'bio': bio,
        'branchIds': branchIds,
        'prices': prices,
        'availability': availability.map((k, v) => MapEntry(k.toString(), [
              for (final w in v) {'start': w.start, 'end': w.end}
            ])),
        'active': active,
      };
}
