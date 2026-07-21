import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tournament.dart';
import '../utils/tournament_engine.dart';
import 'firestore_service.dart' show SlotTakenException;

/// All tournament reads/writes. Notifications (published, registered,
/// waitlist promoted, results out, day-before reminders) are sent by the
/// Cloud Functions in functions/index.js reacting to these writes.
class TournamentService {
  final FirebaseFirestore _db;

  TournamentService([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('tournaments');

  Stream<List<Tournament>> tournaments() => _col.snapshots().map((s) {
        final list = s.docs.map(Tournament.fromDoc).toList();
        list.sort((a, b) {
          final aDate = a.dates.isEmpty ? '' : a.dates.first;
          final bDate = b.dates.isEmpty ? '' : b.dates.first;
          return bDate.compareTo(aDate); // newest first
        });
        return list;
      });

  Future<String> save(Tournament t) async {
    final doc = t.id.isEmpty ? _col.doc() : _col.doc(t.id);
    if (t.id.isEmpty) {
      await doc.set({...t.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    } else {
      // Never clobber live counters when editing details.
      final map = t.toMap()
        ..remove('entriesCount')
        ..remove('waitlistCount');
      await doc.update(map);
    }
    return doc.id;
  }

  Future<void> setStatus(String id, String status) =>
      _col.doc(id).update({'status': status});

  Future<void> finish(String id, List<String> winners) =>
      _col.doc(id).update({'status': 'finished', 'winners': winners});

  // ---------- Entries ----------

  Stream<List<TournamentEntry>> entries(String tournamentId) => _col
          .doc(tournamentId)
          .collection('entries')
          .orderBy('createdAt')
          .snapshots()
          .map((s) {
        return s.docs.map(TournamentEntry.fromDoc).toList();
      });

  /// Registers a player/team. When the tournament is full the entry goes
  /// to the waitlist. Runs in a transaction so the last spot can't be
  /// taken twice. Returns the resulting status.
  Future<String> register(Tournament t,
      {required List<String> uids, required List<String> names}) async {
    final tRef = _col.doc(t.id);
    final entryRef = tRef.collection('entries').doc();
    return _db.runTransaction((tx) async {
      final snap = await tx.get(tRef);
      final current = Tournament.fromDoc(snap);
      if (!current.registrationOpen) throw SlotTakenException();
      final waitlisted = current.entriesCount >= current.maxEntries;
      final status = waitlisted ? 'waitlist' : 'registered';
      tx.set(entryRef, {
        'uids': uids,
        'names': names,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(tRef, {
        waitlisted ? 'waitlistCount' : 'entriesCount':
            FieldValue.increment(1),
      });
      return status;
    });
  }

  /// Admin removes an entry; the oldest waitlisted entry (if any) is
  /// promoted automatically — the Cloud Function notifies them.
  Future<void> removeEntry(Tournament t, TournamentEntry entry) async {
    final tRef = _col.doc(t.id);
    await tRef.collection('entries').doc(entry.id).delete();
    if (entry.status == 'waitlist') {
      await tRef.update({'waitlistCount': FieldValue.increment(-1)});
      return;
    }
    await tRef.update({'entriesCount': FieldValue.increment(-1)});
    final waitlist = await tRef
        .collection('entries')
        .where('status', isEqualTo: 'waitlist')
        .orderBy('createdAt')
        .limit(1)
        .get();
    if (waitlist.docs.isNotEmpty) {
      await waitlist.docs.first.reference.update({'status': 'registered'});
      await tRef.update({
        'entriesCount': FieldValue.increment(1),
        'waitlistCount': FieldValue.increment(-1),
      });
    }
  }

  // ---------- Matches / schedule ----------

  Stream<List<TournamentMatch>> matches(String tournamentId) => _col
          .doc(tournamentId)
          .collection('matches')
          .snapshots()
          .map((s) {
        final list = s.docs.map(TournamentMatch.fromDoc).toList();
        list.sort((a, b) => a.round != b.round
            ? a.round.compareTo(b.round)
            : a.order.compareTo(b.order));
        return list;
      });

  Future<void> _writeMatches(
      String tournamentId, List<TournamentMatch> matches) async {
    final batch = _db.batch();
    final col = _col.doc(tournamentId).collection('matches');
    for (final m in matches) {
      batch.set(col.doc(m.id), m.toMap());
    }
    await batch.commit();
  }

  /// Americano: generates the next round of matches with rotated partners.
  Future<void> generateAmericanoRound(
      Tournament t, List<TournamentEntry> registered, int round) async {
    final players = [for (final e in registered) e.names.first];
    await _writeMatches(
        t.id, TournamentEngine.americanoRound(players, round));
    await setStatus(t.id, 'inProgress');
  }

  /// Knockout: generates the full bracket from registered teams.
  Future<void> generateKnockoutBracket(
      Tournament t, List<TournamentEntry> registered) async {
    final teams = [for (final e in registered) e.names];
    await _writeMatches(t.id, TournamentEngine.knockoutBracket(teams));
    await setStatus(t.id, 'inProgress');
  }

  /// Saves a score; in knockout the winner advances to the next round.
  Future<void> enterScore(Tournament t, TournamentMatch match,
      List<TournamentMatch> allMatches, int scoreA, int scoreB) async {
    final col = _col.doc(t.id).collection('matches');
    await col.doc(match.id).update({'scoreA': scoreA, 'scoreB': scoreB});
    if (t.format == TournamentFormat.knockout) {
      final updated = TournamentMatch(
          id: match.id,
          round: match.round,
          order: match.order,
          aNames: match.aNames,
          bNames: match.bNames,
          scoreA: scoreA,
          scoreB: scoreB);
      final next = TournamentEngine.nextSlot(
          updated, TournamentEngine.totalRounds(allMatches));
      if (next != null) {
        final (nextId, isSideA) = next;
        await col.doc(nextId).update({
          isSideA ? 'aNames' : 'bNames': updated.winnerNames,
        });
      }
    }
  }
}
