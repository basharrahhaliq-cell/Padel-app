import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/time_utils.dart';

/// Tournament formats supported by the club.
enum TournamentFormat { americano, knockout }

/// A club tournament. Entries and matches live in subcollections.
class Tournament {
  final String id;
  final String name;
  final String description;
  final String branchId;
  final String branchName;
  final List<String> dates; // yyyy-MM-dd, first = main day
  final int startMinutes;
  final String level; // A/B/C/D or "Open"
  final TournamentFormat format;
  final int maxEntries; // players (americano) or teams (knockout)
  final double entryFee; // display only — paid at the club
  final String deadline; // registration deadline, yyyy-MM-dd
  final String status; // published | closed | inProgress | finished
  final int entriesCount;
  final int waitlistCount;
  final List<String> winners;

  const Tournament({
    required this.id,
    required this.name,
    required this.description,
    required this.branchId,
    required this.branchName,
    required this.dates,
    required this.startMinutes,
    required this.level,
    required this.format,
    required this.maxEntries,
    required this.entryFee,
    required this.deadline,
    required this.status,
    this.entriesCount = 0,
    this.waitlistCount = 0,
    this.winners = const [],
  });

  bool get isTeamFormat => format == TournamentFormat.knockout;

  bool get registrationOpen =>
      status == 'published' &&
      deadline.compareTo(dateKey(DateTime.now())) >= 0;

  bool get isFull => entriesCount >= maxEntries;

  bool get isPast => status == 'finished';

  factory Tournament.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Tournament(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      branchId: (data['branchId'] as String?) ?? '',
      branchName: (data['branchName'] as String?) ?? '',
      dates: List<String>.from(data['dates'] ?? const []),
      startMinutes: (data['startMinutes'] as num?)?.toInt() ?? 540,
      level: (data['level'] as String?) ?? 'Open',
      format: data['format'] == 'knockout'
          ? TournamentFormat.knockout
          : TournamentFormat.americano,
      maxEntries: (data['maxEntries'] as num?)?.toInt() ?? 16,
      entryFee: (data['entryFee'] as num?)?.toDouble() ?? 0,
      deadline: (data['deadline'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'published',
      entriesCount: (data['entriesCount'] as num?)?.toInt() ?? 0,
      waitlistCount: (data['waitlistCount'] as num?)?.toInt() ?? 0,
      winners: List<String>.from(data['winners'] ?? const []),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'branchId': branchId,
        'branchName': branchName,
        'dates': dates,
        'startMinutes': startMinutes,
        'level': level,
        'format':
            format == TournamentFormat.knockout ? 'knockout' : 'americano',
        'maxEntries': maxEntries,
        'entryFee': entryFee,
        'deadline': deadline,
        'status': status,
        'entriesCount': entriesCount,
        'waitlistCount': waitlistCount,
        'winners': winners,
      };
}

/// One registration: a single player (americano) or a team of two
/// (knockout — the partner may not have an account, so only names are
/// guaranteed).
class TournamentEntry {
  final String id;
  final List<String> uids; // app accounts involved (>= 1)
  final List<String> names; // display names (1 or 2)
  final String status; // registered | waitlist
  final DateTime? createdAt;

  const TournamentEntry({
    required this.id,
    required this.uids,
    required this.names,
    required this.status,
    this.createdAt,
  });

  String get displayName => names.join(' & ');

  factory TournamentEntry.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TournamentEntry(
      id: doc.id,
      uids: List<String>.from(data['uids'] ?? const []),
      names: List<String>.from(data['names'] ?? const []),
      status: (data['status'] as String?) ?? 'registered',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uids': uids,
        'names': names,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

/// One match inside a tournament. For knockout, ids follow "r{round}m{i}"
/// so the winner of r1m0/r1m1 feeds side A/B of r2m0, and so on.
class TournamentMatch {
  final String id;
  final int round;
  final int order;
  final List<String> aNames;
  final List<String> bNames;
  final int? scoreA;
  final int? scoreB;

  const TournamentMatch({
    required this.id,
    required this.round,
    required this.order,
    required this.aNames,
    required this.bNames,
    this.scoreA,
    this.scoreB,
  });

  bool get done => scoreA != null && scoreB != null;

  bool get ready => aNames.isNotEmpty && bNames.isNotEmpty;

  List<String> get winnerNames => !done
      ? const []
      : (scoreA! >= scoreB! ? aNames : bNames);

  factory TournamentMatch.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TournamentMatch(
      id: doc.id,
      round: (data['round'] as num?)?.toInt() ?? 1,
      order: (data['order'] as num?)?.toInt() ?? 0,
      aNames: List<String>.from(data['aNames'] ?? const []),
      bNames: List<String>.from(data['bNames'] ?? const []),
      scoreA: (data['scoreA'] as num?)?.toInt(),
      scoreB: (data['scoreB'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'round': round,
        'order': order,
        'aNames': aNames,
        'bNames': bNames,
        'scoreA': scoreA,
        'scoreB': scoreB,
      };
}
