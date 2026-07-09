import 'package:flutter_test/flutter_test.dart';
import 'package:padel_app/src/models/tournament.dart';
import 'package:padel_app/src/utils/tournament_engine.dart';

void main() {
  group('americano', () {
    final players = ['P1', 'P2', 'P3', 'P4', 'P5', 'P6', 'P7', 'P8'];

    test('8 players -> 2 matches per round, everyone plays once', () {
      final round = TournamentEngine.americanoRound(players, 1);
      expect(round.length, 2);
      final all = round.expand((m) => [...m.aNames, ...m.bNames]).toList();
      expect(all.toSet(), players.toSet());
    });

    test('partners rotate between rounds', () {
      final r1 = TournamentEngine.americanoRound(players, 1);
      final r2 = TournamentEngine.americanoRound(players, 2);
      String partnerOf(List<TournamentMatch> ms, String p) {
        for (final m in ms) {
          if (m.aNames.contains(p)) {
            return m.aNames.firstWhere((x) => x != p);
          }
          if (m.bNames.contains(p)) {
            return m.bNames.firstWhere((x) => x != p);
          }
        }
        return '';
      }

      expect(partnerOf(r1, 'P1'), isNot(partnerOf(r2, 'P1')));
    });

    test('fewer than 4 players -> no matches', () {
      expect(TournamentEngine.americanoRound(['a', 'b', 'c'], 1), isEmpty);
    });

    test('6 players -> 1 match, 2 sit out', () {
      final round =
          TournamentEngine.americanoRound(players.sublist(0, 6), 1);
      expect(round.length, 1);
    });

    test('standings add team points to each player individually', () {
      final matches = [
        const TournamentMatch(
            id: 'r1m0',
            round: 1,
            order: 0,
            aNames: ['P1', 'P2'],
            bNames: ['P3', 'P4'],
            scoreA: 21,
            scoreB: 11),
        const TournamentMatch(
            id: 'r2m0',
            round: 2,
            order: 0,
            aNames: ['P1', 'P3'],
            bNames: ['P2', 'P4'],
            scoreA: 15,
            scoreB: 17),
      ];
      final standings = TournamentEngine.americanoStandings(
          ['P1', 'P2', 'P3', 'P4'], matches);
      final byName = {for (final s in standings) s.player: s.points};
      expect(byName['P1'], 36); // 21 + 15
      expect(byName['P2'], 38); // 21 + 17
      expect(byName['P3'], 26); // 11 + 15
      expect(byName['P4'], 28); // 11 + 17
      expect(standings.first.player, 'P2');
    });
  });

  group('knockout', () {
    test('4 teams -> 2 semis + 1 final', () {
      final b = TournamentEngine.knockoutBracket([
        ['A1', 'A2'],
        ['B1', 'B2'],
        ['C1', 'C2'],
        ['D1', 'D2'],
      ]);
      expect(b.length, 3);
      expect(b.where((m) => m.round == 1).length, 2);
      expect(b.where((m) => m.round == 2).length, 1);
    });

    test('non power of two gets byes that auto-advance', () {
      final b = TournamentEngine.knockoutBracket([
        ['T1'],
        ['T2'],
        ['T3'],
      ]); // pads to 4: T1 vs T2, T3 vs bye
      final r1 = b.where((m) => m.round == 1).toList();
      final finalMatch = b.firstWhere((m) => m.round == 2);
      expect(r1.length, 2);
      // T3 had a bye and is already in the final.
      expect(finalMatch.aNames.isEmpty && finalMatch.bNames.isEmpty, false);
      expect(
          finalMatch.aNames.contains('T3') ||
              finalMatch.bNames.contains('T3'),
          true);
    });

    test('winner slot points to the right next match', () {
      const m = TournamentMatch(
          id: 'r1m1', round: 1, order: 1, aNames: ['x'], bNames: ['y']);
      expect(TournamentEngine.nextSlot(m, 2), ('r2m0', false));
      const f = TournamentMatch(
          id: 'r2m0', round: 2, order: 0, aNames: ['x'], bNames: ['y']);
      expect(TournamentEngine.nextSlot(f, 2), isNull);
    });

    test('winnerNames picks the higher score', () {
      const m = TournamentMatch(
          id: 'r1m0',
          round: 1,
          order: 0,
          aNames: ['A'],
          bNames: ['B'],
          scoreA: 3,
          scoreB: 6);
      expect(m.winnerNames, ['B']);
    });
  });
}
