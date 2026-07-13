import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/open_match.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../utils/time_utils.dart';

/// Browse open matches (filter by branch/level/date), join with one tap,
/// or create one from an upcoming booking.
class OpenMatchesScreen extends StatefulWidget {
  final AppUser profile;

  const OpenMatchesScreen({super.key, required this.profile});

  @override
  State<OpenMatchesScreen> createState() => _OpenMatchesScreenState();
}

class _OpenMatchesScreenState extends State<OpenMatchesScreen> {
  String? _branchId;
  String? _level;
  DateTime? _date;

  Future<void> _join(OpenMatch match) async {
    final db = context.read<FirestoreService>();
    try {
      await db.joinOpenMatch(match.id, widget.profile.uid,
          widget.profile.name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("You're in! See you on the court. 🎾")));
    } on SlotTakenException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This match just filled up or you already joined.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
    }
  }

  Future<void> _cancel(OpenMatch match) async {
    final db = context.read<FirestoreService>();
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this open match?'),
        content: const Text('Joined players will be notified. '
            'Your court booking stays.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep it')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, cancel')),
        ],
      ),
    );
    if (sure == true) await db.cancelOpenMatch(match);
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Create'),
        onPressed: () => showCreateOpenMatchSheet(context, widget.profile),
      ),
      body: Column(
        children: [
          _filters(db),
          Expanded(
            child: StreamBuilder<List<OpenMatch>>(
              stream: db.openMatches(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var matches = snap.data!;
                if (_branchId != null) {
                  matches = matches
                      .where((m) => m.branchId == _branchId)
                      .toList();
                }
                if (_level != null) {
                  matches =
                      matches.where((m) => m.level == _level).toList();
                }
                if (_date != null) {
                  matches = matches
                      .where((m) => m.date == dateKey(_date!))
                      .toList();
                }
                if (matches.isEmpty) {
                  return const Center(
                      child: Text('No open matches right now.\n'
                          'Create one from your next booking!',
                          textAlign: TextAlign.center));
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  children: [
                    for (final m in matches)
                      _MatchCard(
                        match: m,
                        profile: widget.profile,
                        onJoin: () => _join(m),
                        onCancel: () => _cancel(m),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(FirestoreService db) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: StreamBuilder(
                stream: db.branches(),
                builder: (context, snap) {
                  final branches = snap.data ?? [];
                  return DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: _branchId,
                    isDense: true,
                    decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8)),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All branches')),
                      for (final b in branches)
                        DropdownMenuItem(value: b.id, child: Text(b.name)),
                    ],
                    onChanged: (v) => setState(() => _branchId = v),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: _level,
                isDense: true,
                decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Any')),
                  for (final level in kSkillLevels)
                    DropdownMenuItem(value: level, child: Text(level)),
                ],
                onChanged: (v) => setState(() => _level = v),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              icon: Icon(
                  _date == null ? Icons.calendar_today : Icons.event_busy,
                  size: 20),
              tooltip: _date == null ? 'Filter by date' : 'Clear date',
              onPressed: () async {
                if (_date != null) {
                  setState(() => _date = null);
                  return;
                }
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final OpenMatch match;
  final AppUser profile;
  final VoidCallback onJoin;
  final VoidCallback onCancel;

  const _MatchCard({
    required this.match,
    required this.profile,
    required this.onJoin,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final date = parseDateKey(match.date);
    final mine = match.creatorId == profile.uid;
    final joined = match.hasJoined(profile.uid);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.courtBlue,
                  child: Text(match.level,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${match.branchName} · ${match.courtName}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      Text(
                        '${DateFormat.MMMEd().format(date)} · '
                        '${formatMinutes(match.startMinutes)} · '
                        '${match.durationMinutes} min',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Chip(
                  backgroundColor: AppTheme.ballLime.withValues(alpha: 0.4),
                  label: Text(
                      '${match.spotsLeft} spot${match.spotsLeft == 1 ? '' : 's'} left',
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Players: ${match.allPlayerNames.join(', ')}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: mine
                  ? TextButton(
                      onPressed: onCancel,
                      child: const Text('Cancel match',
                          style: TextStyle(color: Colors.redAccent)))
                  : joined
                      ? const Chip(label: Text('Joined ✓'))
                      : FilledButton(
                          onPressed: onJoin, child: const Text('Join')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet: turn one of my upcoming bookings into an open match.
Future<void> showCreateOpenMatchSheet(
    BuildContext context, AppUser profile) async {
  final db = context.read<FirestoreService>();
  final bookings = await db.myBookings(profile.uid).first;
  final now = DateTime.now();
  final eligible = bookings
      .where((b) =>
          !b.isOpenMatch &&
          !b.isBlock &&
          b.startDateTime.isAfter(now))
      .toList();

  if (!context.mounted) return;
  if (eligible.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Book a court first, then turn the booking '
            'into an open match.')));
    return;
  }

  String bookingId = eligible.first.id;
  String level = profile.skillLevel.isEmpty ? 'D' : profile.skillLevel;
  int needed = 3;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: StatefulBuilder(
        builder: (ctx2, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Create open match',
                style: Theme.of(ctx2).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: bookingId,
              decoration: const InputDecoration(labelText: 'My booking'),
              items: [
                for (final b in eligible)
                  DropdownMenuItem(
                    value: b.id,
                    child: Text(
                        '${b.branchName} ${b.courtName} · ${b.date} '
                        '${formatMinutes(b.startMinutes)}',
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => bookingId = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: level,
              decoration: const InputDecoration(labelText: 'Match level'),
              items: [
                for (final lvl in kSkillLevels)
                  DropdownMenuItem(value: lvl, child: Text('Level $lvl')),
              ],
              onChanged: (v) => setState(() => level = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: needed,
              decoration:
                  const InputDecoration(labelText: 'Players needed'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 player')),
                DropdownMenuItem(value: 2, child: Text('2 players')),
                DropdownMenuItem(value: 3, child: Text('3 players')),
              ],
              onChanged: (v) => setState(() => needed = v!),
            ),
            const SizedBox(height: 20),
            FilledButton(
              child: const Text('Publish match'),
              onPressed: () async {
                final booking =
                    eligible.firstWhere((b) => b.id == bookingId);
                final match = OpenMatch(
                  id: '',
                  creatorId: profile.uid,
                  creatorName: profile.name,
                  bookingId: booking.id,
                  branchId: booking.branchId,
                  branchName: booking.branchName,
                  courtName: booking.courtName,
                  date: booking.date,
                  startMinutes: booking.startMinutes,
                  durationMinutes: booking.durationMinutes,
                  level: level,
                  playersNeeded: needed,
                  players: const [],
                  status: 'open',
                );
                await db.createOpenMatch(match);
                if (ctx2.mounted) Navigator.pop(ctx2);
              },
            ),
          ],
        ),
      ),
    ),
  );
}
