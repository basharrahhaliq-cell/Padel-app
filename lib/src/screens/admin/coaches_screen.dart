import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/branch.dart';
import '../../models/coach.dart';
import '../../models/court.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../utils/time_utils.dart';

/// Owner academy management: coaches, their prices and weekly schedule,
/// plus which court each branch uses for lessons.
class CoachesScreen extends StatelessWidget {
  const CoachesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Academy — coaches')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New coach'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const CoachEditorScreen())),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          const _LessonCourtSettings(),
          const SizedBox(height: 16),
          Text('Coaches', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          StreamBuilder<List<Coach>>(
            stream: db.coaches(),
            builder: (context, snap) {
              final coaches = snap.data ?? [];
              if (coaches.isEmpty) {
                return Text('No coaches yet.',
                    style: TextStyle(color: Colors.grey.shade600));
              }
              return Column(
                children: [
                  for (final c in coaches)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: c.active
                              ? AppTheme.courtBlue
                              : Colors.grey.shade400,
                          child: Text(
                              c.name.isEmpty
                                  ? '?'
                                  : c.name[0].toUpperCase(),
                              style:
                                  const TextStyle(color: Colors.white)),
                        ),
                        title: Text(c.name),
                        subtitle: Text(
                            '${c.availability.entries.where((e) => e.value.isNotEmpty).length} working days/week'
                            '${c.active ? '' : ' · inactive'}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    CoachEditorScreen(existing: c))),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Per-branch: which court is used for lessons (or any free court).
class _LessonCourtSettings extends StatelessWidget {
  const _LessonCourtSettings();

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    return StreamBuilder<List<Branch>>(
      stream: db.branches(),
      builder: (context, snap) {
        final branches = snap.data ?? [];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lesson court per branch',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                    'Lessons reserve this court automatically. '
                    '"Any free court" picks whichever court is available.',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 8),
                for (final branch in branches)
                  StreamBuilder<List<Court>>(
                    stream: db.courts(branch.id),
                    builder: (context, courtSnap) {
                      final courts = courtSnap.data ?? [];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(child: Text(branch.name)),
                            DropdownButton<String>(
                              value: courts.any(
                                      (c) => c.id == branch.lessonCourtId)
                                  ? branch.lessonCourtId
                                  : '',
                              items: [
                                const DropdownMenuItem(
                                    value: '',
                                    child: Text('Any free court')),
                                for (final c in courts)
                                  DropdownMenuItem(
                                      value: c.id, child: Text(c.name)),
                              ],
                              onChanged: (v) =>
                                  db.setLessonCourt(branch.id, v ?? ''),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Create / edit one coach: profile, prices, branches, weekly windows.
class CoachEditorScreen extends StatefulWidget {
  final Coach? existing;

  const CoachEditorScreen({super.key, this.existing});

  @override
  State<CoachEditorScreen> createState() => _CoachEditorScreenState();
}

class _CoachEditorScreenState extends State<CoachEditorScreen> {
  static const _dayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday'
  ];

  late final _name = TextEditingController(text: widget.existing?.name);
  late final _photo = TextEditingController(text: widget.existing?.photoUrl);
  late final _bio = TextEditingController(text: widget.existing?.bio);
  late final Map<String, TextEditingController> _prices = {
    for (final type in kSessionTypes.keys)
      type: TextEditingController(
          text: (widget.existing?.priceFor(type) ?? 0) == 0
              ? ''
              : widget.existing!.priceFor(type).toStringAsFixed(0)),
  };
  late Set<String> _branchIds = {...widget.existing?.branchIds ?? const []};
  late final Map<int, List<CoachWindow>> _availability = {
    for (int d = 1; d <= 7; d++)
      d: [...widget.existing?.availability[d] ?? const []],
  };
  late bool _active = widget.existing?.active ?? true;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _photo.dispose();
    _bio.dispose();
    for (final c in _prices.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addWindow(int weekday) async {
    int start = 9 * 60;
    int end = 13 * 60;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState) => AlertDialog(
          title: Text('${_dayNames[weekday - 1]} window'),
          content: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: start,
                  decoration: const InputDecoration(labelText: 'From'),
                  items: [
                    for (int t = ClubHours.openMinutes;
                        t < ClubHours.closeMinutes;
                        t += ClubHours.slotStepMinutes)
                      DropdownMenuItem(
                          value: t, child: Text(formatMinutes(t))),
                  ],
                  onChanged: (v) => setState(() => start = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: end,
                  decoration: const InputDecoration(labelText: 'To'),
                  items: [
                    for (int t = ClubHours.openMinutes +
                            ClubHours.slotStepMinutes;
                        t <= ClubHours.closeMinutes;
                        t += ClubHours.slotStepMinutes)
                      DropdownMenuItem(
                          value: t, child: Text(formatMinutes(t))),
                  ],
                  onChanged: (v) => setState(() => end = v!),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx2, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx2, true),
                child: const Text('Add')),
          ],
        ),
      ),
    );
    if (saved == true && end > start) {
      setState(() => _availability[weekday]!.add(CoachWindow(start, end)));
    }
  }

  Future<void> _save() async {
    final db = context.read<FirestoreService>();
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Coach name is required.')));
      return;
    }
    setState(() => _busy = true);
    await db.saveCoach(Coach(
      id: widget.existing?.id ?? '',
      name: _name.text.trim(),
      photoUrl: _photo.text.trim(),
      bio: _bio.text.trim(),
      branchIds: _branchIds.toList(),
      prices: {
        for (final e in _prices.entries)
          e.key: double.tryParse(e.value.text) ?? 0,
      },
      availability: _availability,
      active: _active,
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.existing == null ? 'New coach' : 'Edit coach'),
        actions: [
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await db.deleteCoach(widget.existing!.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(
              controller: _photo,
              decoration: const InputDecoration(
                  labelText: 'Photo URL (optional)')),
          const SizedBox(height: 12),
          TextField(
              controller: _bio,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Short bio (optional)')),
          const SizedBox(height: 16),
          Text('Branches', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          StreamBuilder<List<Branch>>(
            stream: db.branches(),
            builder: (context, snap) => Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  selected: _branchIds.isEmpty,
                  label: const Text('All branches'),
                  onSelected: (_) => setState(() => _branchIds = {}),
                ),
                for (final b in snap.data ?? <Branch>[])
                  FilterChip(
                    selected: _branchIds.contains(b.id),
                    label: Text(b.name),
                    onSelected: (on) => setState(() {
                      on ? _branchIds.add(b.id) : _branchIds.remove(b.id);
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Prices per session (USD)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final entry in kSessionTypes.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _prices[entry.key],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: entry.value, prefixText: '\$ '),
              ),
            ),
          const SizedBox(height: 8),
          Text('Weekly availability',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (int d = 1; d <= 7; d++)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    SizedBox(width: 88, child: Text(_dayNames[d - 1])),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final w in _availability[d]!)
                            InputChip(
                              label: Text(
                                  '${formatMinutes(w.start)}–${formatMinutes(w.end)}',
                                  style: const TextStyle(fontSize: 12)),
                              onDeleted: () => setState(
                                  () => _availability[d]!.remove(w)),
                            ),
                          if (_availability[d]!.isEmpty)
                            Text('Off',
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      onPressed: () => _addWindow(d),
                    ),
                  ],
                ),
              ),
            ),
          SwitchListTile(
            title: const Text('Active (visible to customers)'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Save coach'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
