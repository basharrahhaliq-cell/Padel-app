import '../models/tournament.dart';

/// Pure tournament math — no Firebase, unit-testable.
class TournamentEngine {
  TournamentEngine._();

  /// Americano round [round] (1-based) for individual [players] using the
  /// circle method: player 0 stays fixed, the rest rotate each round, and
  /// pairs are taken from opposite ends — so partners change every round.
  /// Players are grouped 4 per match; leftovers sit the round out.
  static List<TournamentMatch> americanoRound(
      List<String> players, int round) {
    if (players.length < 4) return const [];
    final fixed = players.first;
    final rest = [...players.skip(1)];
    final rot = (round - 1) % rest.length;
    final rotated = [...rest.skip(rot), ...rest.take(rot)];
    final arranged = [fixed, ...rotated];

    // Opposite-end pairing: (0, n-1), (1, n-2), ...
    final pairs = <List<String>>[];
    for (int i = 0; i < arranged.length ~/ 2; i++) {
      pairs.add([arranged[i], arranged[arranged.length - 1 - i]]);
    }
    final matches = <TournamentMatch>[];
    for (int m = 0; m + 1 < pairs.length; m += 2) {
      matches.add(TournamentMatch(
        id: 'r${round}m${m ~/ 2}',
        round: round,
        order: m ~/ 2,
        aNames: pairs[m],
        bNames: pairs[m + 1],
      ));
    }
    return matches;
  }

  /// Americano leaderboard: every player on a side earns that side's
  /// points from each finished match. Returns entries sorted best-first.
  static List<({String player, int points})> americanoStandings(
      List<String> players, List<TournamentMatch> matches) {
    final points = {for (final p in players) p: 0};
    for (final m in matches.where((m) => m.done)) {
      for (final p in m.aNames) {
        points[p] = (points[p] ?? 0) + m.scoreA!;
      }
      for (final p in m.bNames) {
        points[p] = (points[p] ?? 0) + m.scoreB!;
      }
    }
    final list = [
      for (final e in points.entries) (player: e.key, points: e.value)
    ];
    list.sort((a, b) => b.points.compareTo(a.points));
    return list;
  }

  /// Full knockout bracket for [teams] (each a list of 1-2 names), seeded
  /// in registration order, padded with byes to the next power of two.
  /// Bye winners are advanced into round 2 immediately.
  static List<TournamentMatch> knockoutBracket(List<List<String>> teams) {
    if (teams.length < 2) return const [];
    int size = 2;
    while (size < teams.length) {
      size *= 2;
    }
    final rounds = _log2(size);

    // Empty bracket skeleton.
    final matches = <String, TournamentMatch>{};
    for (int r = 1; r <= rounds; r++) {
      final count = size >> r; // matches in round r
      for (int i = 0; i < count; i++) {
        matches['r${r}m$i'] = TournamentMatch(
            id: 'r${r}m$i', round: r, order: i, aNames: [], bNames: []);
      }
    }

    // Seed round 1; empty slots are byes.
    for (int i = 0; i < size; i++) {
      final team = i < teams.length ? teams[i] : <String>[];
      final match = matches['r1m${i ~/ 2}']!;
      matches['r1m${i ~/ 2}'] = _withSide(match, i % 2 == 0, team);
    }

    // Auto-advance byes out of round 1.
    if (rounds >= 2) {
      final count1 = size >> 1;
      for (int i = 0; i < count1; i++) {
        final m = matches['r1m$i']!;
        List<String>? walkover;
        if (m.aNames.isNotEmpty && m.bNames.isEmpty) walkover = m.aNames;
        if (m.aNames.isEmpty && m.bNames.isNotEmpty) walkover = m.bNames;
        if (walkover != null) {
          final next = matches['r2m${i ~/ 2}']!;
          matches['r2m${i ~/ 2}'] = _withSide(next, i % 2 == 0, walkover);
        }
      }
    }
    return matches.values.toList()
      ..sort((a, b) => a.round != b.round
          ? a.round.compareTo(b.round)
          : a.order.compareTo(b.order));
  }

  /// Where the winner of [match] goes: (nextMatchId, isSideA), or null
  /// after the final.
  static (String, bool)? nextSlot(TournamentMatch match, int totalRounds) {
    if (match.round >= totalRounds) return null;
    return ('r${match.round + 1}m${match.order ~/ 2}', match.order % 2 == 0);
  }

  static int totalRounds(List<TournamentMatch> matches) => matches.isEmpty
      ? 0
      : matches.map((m) => m.round).reduce((a, b) => a > b ? a : b);

  static TournamentMatch _withSide(
          TournamentMatch m, bool sideA, List<String> names) =>
      TournamentMatch(
        id: m.id,
        round: m.round,
        order: m.order,
        aNames: sideA ? names : m.aNames,
        bNames: sideA ? m.bNames : names,
        scoreA: m.scoreA,
        scoreB: m.scoreB,
      );

  static int _log2(int v) {
    int r = 0;
    while (1 << r < v) {
      r++;
    }
    return r;
  }
}
