import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/time_utils.dart';

/// A "find players" match attached to a court booking.
/// Cloud Functions send the push notifications (created / full / cancelled).
class OpenMatch {
  final String id;
  final String creatorId;
  final String creatorName;
  final String bookingId;
  final String branchId;
  final String branchName;
  final String courtName;
  final String date; // yyyy-MM-dd
  final int startMinutes;
  final int durationMinutes;
  final String level; // A/B/C/D
  final int playersNeeded; // 1-3
  final List<({String uid, String name})> players;
  final String status; // open | full | cancelled

  const OpenMatch({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.bookingId,
    required this.branchId,
    required this.branchName,
    required this.courtName,
    required this.date,
    required this.startMinutes,
    required this.durationMinutes,
    required this.level,
    required this.playersNeeded,
    required this.players,
    required this.status,
  });

  int get spotsLeft => playersNeeded - players.length;

  DateTime get startDateTime => dateTimeOf(parseDateKey(date), startMinutes);

  bool hasJoined(String uid) =>
      creatorId == uid || players.any((p) => p.uid == uid);

  /// Creator + everyone who joined, for display.
  List<String> get allPlayerNames =>
      [creatorName, ...players.map((p) => p.name)];

  factory OpenMatch.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawPlayers = (data['players'] as List?) ?? const [];
    return OpenMatch(
      id: doc.id,
      creatorId: (data['creatorId'] as String?) ?? '',
      creatorName: (data['creatorName'] as String?) ?? '',
      bookingId: (data['bookingId'] as String?) ?? '',
      branchId: (data['branchId'] as String?) ?? '',
      branchName: (data['branchName'] as String?) ?? '',
      courtName: (data['courtName'] as String?) ?? '',
      date: (data['date'] as String?) ?? '',
      startMinutes: (data['startMinutes'] as num?)?.toInt() ?? 0,
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 90,
      level: (data['level'] as String?) ?? 'D',
      playersNeeded: (data['playersNeeded'] as num?)?.toInt() ?? 3,
      players: [
        for (final p in rawPlayers)
          (uid: (p['uid'] as String?) ?? '', name: (p['name'] as String?) ?? '')
      ],
      status: (data['status'] as String?) ?? 'open',
    );
  }

  Map<String, dynamic> toMap() => {
        'creatorId': creatorId,
        'creatorName': creatorName,
        'bookingId': bookingId,
        'branchId': branchId,
        'branchName': branchName,
        'courtName': courtName,
        'date': date,
        'startMinutes': startMinutes,
        'durationMinutes': durationMinutes,
        'level': level,
        'playersNeeded': playersNeeded,
        'players': [
          for (final p in players) {'uid': p.uid, 'name': p.name}
        ],
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
