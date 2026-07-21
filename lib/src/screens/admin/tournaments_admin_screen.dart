import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/branch.dart';
import '../../models/tournament.dart';
import '../../services/firestore_service.dart';
import '../../services/tournament_service.dart';
import '../../theme.dart';
import '../../utils/time_utils.dart';
import '../../utils/tournament_engine.dart';
import '../customer/tournaments_screen.dart' show TournamentResultsView;
import 'block_time_sheet.dart';

/// Owner tournament management: create, entries, courts, scores, finish.
class TournamentsAdminScreen extends StatelessWidget {
  const TournamentsAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<TournamentService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Tournaments')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const TournamentEditorScreen())),
      ),
      body: StreamBuilder<List<Tournament>>(
        stream: service.tournaments(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return const Center(
                child: Text('No tournaments yet — create the first one!'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              for (final t in list)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: t.isPast
                          ? Colors.grey.shade300
                          : AppTheme.ballLime,
                      child: const Icon(Icons.emoji_events,
                          color: AppTheme.courtBlueDark),
                    ),
                    title: Text(t.name),
                    subtitle: Text(
                        '${t.branchName} · ${t.dates.isEmpty ? '?' : t.dates.first} · '
                        '${t.status} · ${t.entriesCount}/${t.maxEntries}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                TournamentManageScreen(tournamentId: t.id))),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Create / edit the tournament details.
class TournamentEditorScreen extends StatefulWidget {
  final Tournament? existing;

  const TournamentEditorScreen({super.key, this.existing});

  @override
  State<TournamentEditorScreen> createState() =>
      _TournamentEditorScreenState();
}

class _TournamentEditorScreenState extends State<TournamentEditorScreen> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _description =
      TextEditingController(text: widget.existing?.description);
  late final _maxEntries = TextEditingController(
      text: (widget.existing?.maxEntries ?? 16).toString());
  late final _fee = TextEditingController(
      text: (widget.existing?.entryFee ?? 20).toStringAsFixed(0));

  String? _branchId;
  late final List<DateTime> _dates = [
    for (final d in widget.existing?.dates ?? const <String>[])
      parseDateKey(d)
  ];
  late int _start = widget.existing?.startMinutes ?? 9 * 60;
  late String _level = widget.existing?.level ?? 'Open';
  late TournamentFormat _format =
      widget.existing?.format ?? TournamentFormat.americano;
  late DateTime _deadline = widget.existing == null
      ? DateTime.now().add(const Duration(days: 7))
      : parseDateKey(widget.existing!.deadline);
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _description, _maxEntries, _fee]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(List<Branch> branches) async {
    final service = context.read<TournamentService>();
    if (_name.text.trim().isEmpty || _dates.isEmpty || _branchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Name, branch, and at least one date are '
              'required.')));
      return;
    }
    setState(() => _busy = true);
    final branch = branches.firstWhere((b) => b.id == _branchId);
    final dateKeys = (_dates.map(dateKey).toList()..sort());
    final t = Tournament(
      id: widget.existing?.id ?? '',
      name: _name.text.trim(),
      description: _description.text.trim(),
      branchId: branch.id,
      branchName: branch.name,
      dates: dateKeys,
      startMinutes: _start,
      level: _level,
      format: _format,
      maxEntries: int.tryParse(_maxEntries.text) ?? 16,
      entryFee: double.tryParse(_fee.text) ?? 0,
      deadline: dateKey(_deadline),
      status: widget.existing?.status ?? 'published',
    );
    await service.save(t);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.existing == null
              ? 'New tournament'
              : 'Edit tournament')),
      body: StreamBuilder<List<Branch>>(
        stream: db.branches(),
        builder: (context, snap) {
          final branches = snap.data ?? [];
          if (branches.isNotEmpty && _branchId == null) {
            _branchId = widget.existing?.branchId ?? branches.first.id;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                  controller: _name,
                  decoration:
                      const InputDecoration(labelText: 'Tournament name')),
              const SizedBox(height: 12),
              TextField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Short description (optional)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _branchId,
                decoration: const InputDecoration(labelText: 'Branch'),
                items: [
                  for (final b in branches)
                    DropdownMenuItem(value: b.id, child: Text(b.name)),
                ],
                onChanged: (v) => setState(() => _branchId = v),
              ),
              const SizedBox(height: 12),
              // Dates (one or more days)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final d in _dates)
                    InputChip(
                      label: Text(DateFormat.MMMEd().format(d)),
                      onDeleted: () => setState(() => _dates.remove(d)),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text(_dates.isEmpty ? 'Add date' : 'Add day'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null &&
                          !_dates.any((d) => dateKey(d) == dateKey(picked))) {
                        setState(() => _dates.add(picked));
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _start,
                decoration: const InputDecoration(labelText: 'Start time'),
                items: [
                  for (int t = ClubHours.openMinutes;
                      t <= ClubHours.closeMinutes - 60;
                      t += ClubHours.slotStepMinutes)
                    DropdownMenuItem(value: t, child: Text(formatMinutes(t))),
                ],
                onChanged: (v) => setState(() => _start = v!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _level,
                      decoration:
                          const InputDecoration(labelText: 'Level'),
                      items: const [
                        DropdownMenuItem(
                            value: 'Open', child: Text('Open (all)')),
                        DropdownMenuItem(value: 'A', child: Text('A')),
                        DropdownMenuItem(value: 'B', child: Text('B')),
                        DropdownMenuItem(value: 'C', child: Text('C')),
                        DropdownMenuItem(value: 'D', child: Text('D')),
                      ],
                      onChanged: (v) => setState(() => _level = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<TournamentFormat>(
                      initialValue: _format,
                      decoration:
                          const InputDecoration(labelText: 'Format'),
                      items: const [
                        DropdownMenuItem(
                            value: TournamentFormat.americano,
                            child: Text('Americano')),
                        DropdownMenuItem(
                            value: TournamentFormat.knockout,
                            child: Text('Knockout')),
                      ],
                      onChanged: (v) => setState(() => _format = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _maxEntries,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: _format == TournamentFormat.knockout
                              ? 'Max teams'
                              : 'Max players'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _fee,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Entry fee', prefixText: '\$ '),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event, size: 18),
                label: Text(
                    'Registration deadline: ${DateFormat.MMMEd().format(_deadline)}'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _deadline,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _deadline = picked);
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : () => _save(branches),
                child: Text(widget.existing == null
                    ? 'Publish tournament'
                    : 'Save changes'),
              ),
              const SizedBox(height: 8),
              Text(
                'Publishing sends a push notification to all users of the '
                'matching level.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Run one tournament: entries, courts, rounds, scores, finish.
class TournamentManageScreen extends StatelessWidget {
  final String tournamentId;

  const TournamentManageScreen({super.key, required this.tournamentId});

  Future<void> _enterScore(BuildContext context, Tournament t,
      TournamentMatch m, List<TournamentMatch> all) async {
    final service = context.read<TournamentService>();
    final a = TextEditingController(text: m.scoreA?.toString());
    final b = TextEditingController(text: m.scoreB?.toString());
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            '${m.aNames.join(" & ")} vs ${m.bNames.join(" & ")}'),
        content: Row(
          children: [
            Expanded(
                child: TextField(
                    controller: a,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Score A'))),
            const SizedBox(width: 12),
            Expanded(
                child: TextField(
                    controller: b,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Score B'))),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    final scoreA = int.tryParse(a.text);
    final scoreB = int.tryParse(b.text);
    if (scoreA == null || scoreB == null) return;
    await service.enterScore(t, m, all, scoreA, scoreB);
  }

  Future<void> _finish(BuildContext context, Tournament t,
      List<TournamentEntry> entries, List<TournamentMatch> matches) async {
    final service = context.read<TournamentService>();
    List<String> winners;
    if (t.format == TournamentFormat.americano) {
      final players = [
        for (final e in entries.where((e) => e.status == 'registered'))
          e.names.first
      ];
      final standings =
          TournamentEngine.americanoStandings(players, matches);
      winners = standings.isEmpty ? [] : [standings.first.player];
    } else {
      final total = TournamentEngine.totalRounds(matches);
      final finals =
          matches.where((m) => m.round == total && m.done).toList();
      winners = finals.isEmpty ? [] : finals.first.winnerNames;
    }
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finish tournament?'),
        content: Text(winners.isEmpty
            ? 'No completed matches yet — winners will be empty.'
            : 'Winners: ${winners.join(', ')}\n\nParticipants get a '
                '"Results are out" notification and 100 XP.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not yet')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Finish')),
        ],
      ),
    );
    if (sure == true) await service.finish(t.id, winners);
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<TournamentService>();
    final db = context.read<FirestoreService>();
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
          appBar: AppBar(
            title: Text(t.name),
            actions: [
              IconButton(
                tooltip: 'Edit details',
                icon: const Icon(Icons.edit),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            TournamentEditorScreen(existing: t))),
              ),
            ],
          ),
          body: StreamBuilder<List<TournamentEntry>>(
            stream: service.entries(t.id),
            builder: (context, entrySnap) {
              final entries = entrySnap.data ?? [];
              final registered = entries
                  .where((e) => e.status == 'registered')
                  .toList();
              return StreamBuilder<List<TournamentMatch>>(
                stream: service.matches(t.id),
                builder: (context, matchSnap) {
                  final matches = matchSnap.data ?? [];
                  final rounds = matches.isEmpty
                      ? 0
                      : matches
                          .map((m) => m.round)
                          .reduce((a, b) => a > b ? a : b);
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
                                  'Status: ${t.status} · Level ${t.level} · '
                                  '${t.format == TournamentFormat.knockout ? 'Knockout' : 'Americano'}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                  '${registered.length}/${t.maxEntries} registered · '
                                  '${t.waitlistCount} waitlisted\n'
                                  'Expected entry revenue: '
                                  '${money.format(t.entryFee * registered.length)}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (t.status == 'published')
                            OutlinedButton.icon(
                              icon: const Icon(Icons.lock, size: 18),
                              label: const Text('Close registration'),
                              onPressed: () =>
                                  service.setStatus(t.id, 'closed'),
                            ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.block, size: 18),
                            label: const Text('Block courts'),
                            onPressed: () async {
                              final branches = await db.branches().first;
                              if (!context.mounted) return;
                              await showBlockTimeSheet(
                                  context,
                                  branches,
                                  t.dates.isEmpty
                                      ? DateTime.now()
                                      : parseDateKey(t.dates.first));
                            },
                          ),
                          if (t.status != 'finished' &&
                              registered.length >= 4)
                            FilledButton.tonalIcon(
                              icon: const Icon(Icons.play_arrow, size: 18),
                              label: Text(t.format ==
                                      TournamentFormat.knockout
                                  ? (matches.isEmpty
                                      ? 'Generate bracket'
                                      : 'Bracket generated')
                                  : 'Generate round ${rounds + 1}'),
                              onPressed: t.format ==
                                          TournamentFormat.knockout &&
                                      matches.isNotEmpty
                                  ? null
                                  : () => t.format ==
                                          TournamentFormat.knockout
                                      ? service.generateKnockoutBracket(
                                          t, registered)
                                      : service.generateAmericanoRound(
                                          t, registered, rounds + 1),
                            ),
                          if (t.status == 'inProgress')
                            FilledButton.icon(
                              icon: const Icon(Icons.emoji_events,
                                  size: 18),
                              label: const Text('Finish & announce'),
                              onPressed: () =>
                                  _finish(context, t, entries, matches),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Entries',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (entries.isEmpty)
                        Text('No registrations yet.',
                            style: TextStyle(color: Colors.grey.shade600)),
                      for (final e in entries)
                        Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                                e.status == 'waitlist'
                                    ? Icons.hourglass_top
                                    : Icons.check_circle,
                                size: 20,
                                color: e.status == 'waitlist'
                                    ? Colors.orange
                                    : Colors.green),
                            title: Text(e.displayName),
                            subtitle: e.status == 'waitlist'
                                ? const Text('Waitlist')
                                : null,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 20, color: Colors.redAccent),
                              onPressed: () => service.removeEntry(t, e),
                            ),
                          ),
                        ),
                      if (matches.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('Matches & standings — tap a match to enter '
                            'the score'),
                        const SizedBox(height: 8),
                        TournamentResultsView(
                          tournament: t,
                          entries: entries,
                          matches: matches,
                          onMatchTap: (m) => m.ready
                              ? _enterScore(context, t, m, matches)
                              : null,
                        ),
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
