import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/tournament.dart';
import '../../services/firestore_service.dart' show SlotTakenException;
import '../../services/tournament_service.dart';
import '../../theme.dart';
import '../../utils/time_utils.dart';
import '../../utils/tournament_engine.dart';

/// Customer tournaments: upcoming (register / waitlist) + past results.
class TournamentsScreen extends StatelessWidget {
  final AppUser profile;

  const TournamentsScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final service = context.read<TournamentService>();
    return StreamBuilder<List<Tournament>>(
      stream: service.tournaments(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final upcoming = snap.data!.where((t) => !t.isPast).toList();
        final past = snap.data!.where((t) => t.isPast).toList();
        if (upcoming.isEmpty && past.isEmpty) {
          return const Center(
              child: Text('No tournaments yet — stay tuned!'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (upcoming.isNotEmpty) ...[
              Text('Upcoming',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final t in upcoming)
                _TournamentCard(tournament: t, profile: profile),
            ],
            if (past.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Past tournaments',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final t in past)
                _TournamentCard(tournament: t, profile: profile),
            ],
          ],
        );
      },
    );
  }
}

class _TournamentCard extends StatelessWidget {
  final Tournament tournament;
  final AppUser profile;

  const _TournamentCard({required this.tournament, required this.profile});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final money = NumberFormat.currency(symbol: '\$');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor:
              t.isPast ? Colors.grey.shade300 : AppTheme.ballLime,
          child: const Icon(Icons.emoji_events,
              color: AppTheme.courtBlueDark),
        ),
        title: Text(t.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${t.branchName} · ${t.dates.isEmpty ? '?' : DateFormat.MMMEd().format(parseDateKey(t.dates.first))} '
          '${formatMinutes(t.startMinutes)}\n'
          '${t.format == TournamentFormat.knockout ? 'Knockout (teams of 2)' : 'Americano (solo)'} · '
          'Level ${t.level} · ${money.format(t.entryFee)} entry'
          '${t.isPast && t.winners.isNotEmpty ? '\n🏆 ${t.winners.join(", ")}' : ''}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                TournamentDetailScreen(tournamentId: t.id, profile: profile))),
      ),
    );
  }
}

/// Live detail: info, register, my status, schedule, standings/bracket.
class TournamentDetailScreen extends StatelessWidget {
  final String tournamentId;
  final AppUser profile;

  const TournamentDetailScreen(
      {super.key, required this.tournamentId, required this.profile});

  Future<void> _register(BuildContext context, Tournament t) async {
    final service = context.read<TournamentService>();
    final partner = TextEditingController();

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Register for ${t.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.isTeamFormat
                ? 'Knockout is played in teams of 2 — enter your '
                    'partner\'s name.'
                : 'Americano is individual — partners rotate every round.'),
            if (t.isTeamFormat) ...[
              const SizedBox(height: 12),
              TextField(
                controller: partner,
                decoration:
                    const InputDecoration(labelText: 'Partner name'),
              ),
            ],
            if (t.isFull)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('This tournament is full — you will join the '
                    'waitlist and be notified if a spot opens.',
                    style: TextStyle(color: Colors.orange)),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.isFull ? 'Join waitlist' : 'Register')),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    if (t.isTeamFormat && partner.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your partner\'s name.')));
      return;
    }
    try {
      final status = await service.register(t,
          uids: [profile.uid],
          names: [
            profile.name,
            if (t.isTeamFormat) partner.text.trim(),
          ]);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'waitlist'
              ? 'Added to the waitlist — we\'ll notify you!'
              : 'Registered! See you on court. 🏆')));
    } on SlotTakenException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Registration is closed for this tournament.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<TournamentService>();
    final money = NumberFormat.currency(symbol: '\$');

    return StreamBuilder<List<Tournament>>(
      stream: service.tournaments(),
      builder: (context, listSnap) {
        final t = (listSnap.data ?? [])
            .where((x) => x.id == tournamentId)
            .firstOrNull;
        if (t == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(title: Text(t.name)),
          body: StreamBuilder<List<TournamentEntry>>(
            stream: service.entries(t.id),
            builder: (context, entrySnap) {
              final entries = entrySnap.data ?? [];
              final mine = entries
                  .where((e) => e.uids.contains(profile.uid))
                  .firstOrNull;
              return StreamBuilder<List<TournamentMatch>>(
                stream: service.matches(t.id),
                builder: (context, matchSnap) {
                  final matches = matchSnap.data ?? [];
                  final myMatches = matches
                      .where((m) =>
                          m.aNames.contains(profile.name) ||
                          m.bNames.contains(profile.name))
                      .toList();
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${t.branchName} · '
                                  '${t.dates.map((d) => DateFormat.MMMEd().format(parseDateKey(d))).join(', ')} · '
                                  '${formatMinutes(t.startMinutes)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text(
                                  '${t.format == TournamentFormat.knockout ? 'Knockout — teams of 2' : 'Americano — individual, rotating partners'}\n'
                                  'Level ${t.level} · Entry ${money.format(t.entryFee)} (paid at the club)\n'
                                  'Registration deadline: ${t.deadline}\n'
                                  '${t.entriesCount}/${t.maxEntries} ${t.isTeamFormat ? 'teams' : 'players'} registered'
                                  '${t.waitlistCount > 0 ? ' · ${t.waitlistCount} waitlisted' : ''}'),
                              if (t.description.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(t.description),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (t.winners.isNotEmpty)
                        Card(
                          color: AppTheme.ballLime.withValues(alpha: 0.3),
                          child: ListTile(
                            leading: const Icon(Icons.emoji_events,
                                color: AppTheme.courtBlueDark),
                            title: Text('Winners: ${t.winners.join(', ')}'),
                          ),
                        ),
                      if (mine != null)
                        Card(
                          child: ListTile(
                            leading: Icon(
                                mine.status == 'waitlist'
                                    ? Icons.hourglass_top
                                    : Icons.check_circle,
                                color: mine.status == 'waitlist'
                                    ? Colors.orange
                                    : Colors.green),
                            title: Text(mine.status == 'waitlist'
                                ? 'You are on the waitlist'
                                : 'You are registered'
                                  ' (${mine.displayName})'),
                          ),
                        )
                      else if (t.registrationOpen)
                        FilledButton.icon(
                          icon: const Icon(Icons.app_registration),
                          label: Text(t.isFull
                              ? 'Join waitlist'
                              : 'Register — ${money.format(t.entryFee)}'),
                          onPressed: () => _register(context, t),
                        ),
                      if (myMatches.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('My matches',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        for (final m in myMatches) MatchTile(match: m),
                      ],
                      if (matches.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                            t.format == TournamentFormat.knockout
                                ? 'Bracket'
                                : 'Standings',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        TournamentResultsView(
                            tournament: t,
                            entries: entries,
                            matches: matches),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// One match row (shared by customer + admin).
class MatchTile extends StatelessWidget {
  final TournamentMatch match;
  final VoidCallback? onTap;

  const MatchTile({super.key, required this.match, this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = match.aNames.isEmpty ? 'TBD' : match.aNames.join(' & ');
    final b = match.bNames.isEmpty ? 'TBD' : match.bNames.join(' & ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text('$a  vs  $b'),
        subtitle: Text('Round ${match.round}'),
        trailing: match.done
            ? Text('${match.scoreA} – ${match.scoreB}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.courtBlue))
            : onTap != null
                ? const Icon(Icons.edit, size: 18)
                : null,
        onTap: onTap,
      ),
    );
  }
}

/// Standings (americano) or bracket rounds (knockout) — shared widget.
class TournamentResultsView extends StatelessWidget {
  final Tournament tournament;
  final List<TournamentEntry> entries;
  final List<TournamentMatch> matches;
  final void Function(TournamentMatch)? onMatchTap;

  const TournamentResultsView({
    super.key,
    required this.tournament,
    required this.entries,
    required this.matches,
    this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    if (tournament.format == TournamentFormat.americano) {
      final players = [
        for (final e in entries.where((e) => e.status == 'registered'))
          e.names.first
      ];
      final standings =
          TournamentEngine.americanoStandings(players, matches);
      final rounds = matches.map((m) => m.round).toSet().toList()..sort();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Column(
              children: [
                for (final (i, s) in standings.indexed)
                  ListTile(
                    dense: true,
                    leading: Text('${i + 1}.',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    title: Text(s.player),
                    trailing: Text('${s.points} pts',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
              ],
            ),
          ),
          for (final r in rounds) ...[
            const SizedBox(height: 12),
            Text('Round $r',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            for (final m in matches.where((m) => m.round == r))
              MatchTile(
                  match: m,
                  onTap: onMatchTap == null ? null : () => onMatchTap!(m)),
          ],
        ],
      );
    }
    // Knockout bracket, round by round.
    final total = TournamentEngine.totalRounds(matches);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int r = 1; r <= total; r++) ...[
          Text(
              r == total
                  ? 'Final'
                  : r == total - 1
                      ? 'Semi-finals'
                      : 'Round $r',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (final m in matches.where((m) => m.round == r))
            MatchTile(
                match: m,
                onTap: onMatchTap == null ? null : () => onMatchTap!(m)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
