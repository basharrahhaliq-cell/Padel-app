import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../models/booking.dart';
import '../../models/branch.dart';
import '../../models/court.dart';
import '../../services/firestore_service.dart';
import '../../utils/time_utils.dart';

/// Bottom sheet for blocking a time range (maintenance, private events).
/// A block is stored as a special booking, so it occupies the day sheet
/// and customers simply never see those start times.
Future<void> showBlockTimeSheet(
    BuildContext context, List<Branch> branches, DateTime date) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _BlockTimeForm(branches: branches, date: date),
    ),
  );
}

class _BlockTimeForm extends StatefulWidget {
  final List<Branch> branches;
  final DateTime date;

  const _BlockTimeForm({required this.branches, required this.date});

  @override
  State<_BlockTimeForm> createState() => _BlockTimeFormState();
}

class _BlockTimeFormState extends State<_BlockTimeForm> {
  final _reason = TextEditingController();
  late String _branchId = widget.branches.first.id;
  String? _courtId;
  late final DateTime _date = widget.date;
  int _start = ClubHours.openMinutes;
  int _end = ClubHours.openMinutes + 60;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  List<int> get _timeOptions => [
        for (int t = ClubHours.openMinutes;
            t <= ClubHours.closeMinutes;
            t += ClubHours.slotStepMinutes)
          t
      ];

  Future<void> _save(Court court) async {
    final l10n = context.l10n;
    final db = context.read<FirestoreService>();
    if (_end <= _start) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.invalidTimeRange)));
      return;
    }
    setState(() => _busy = true);
    final branch =
        widget.branches.firstWhere((b) => b.id == _branchId);
    final block = Booking(
      id: '',
      branchId: _branchId,
      courtId: court.id,
      branchName: branch.name,
      courtName: court.name,
      date: dateKey(_date),
      startMinutes: _start,
      durationMinutes: _end - _start,
      userId: 'admin',
      userName: 'BLOCK',
      userPhone: '',
      price: 0,
      status: BookingStatus.confirmed,
      isBlock: true,
      note: _reason.text.trim(),
    );
    try {
      await db.createBooking(block);
      if (!mounted) return;
      Navigator.pop(context);
    } on SlotTakenException {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.blockOverlap)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.genericError(e.toString()))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final db = context.read<FirestoreService>();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: StreamBuilder<List<Court>>(
        stream: db.courts(_branchId),
        builder: (context, courtSnap) {
          final courts = courtSnap.data ?? [];
          final court = courts.isEmpty
              ? null
              : courts.firstWhere((c) => c.id == _courtId,
                  orElse: () => courts.first);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.blockTime,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _branchId,
                items: [
                  for (final b in widget.branches)
                    DropdownMenuItem(value: b.id, child: Text(b.name)),
                ],
                onChanged: (v) => setState(() {
                  _branchId = v!;
                  _courtId = null;
                }),
              ),
              const SizedBox(height: 12),
              if (court != null)
                DropdownButtonFormField<String>(
                  initialValue: court.id,
                  items: [
                    for (final c in courts)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _courtId = v),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _start,
                      decoration:
                          InputDecoration(labelText: l10n.startTime),
                      items: [
                        for (final t in _timeOptions)
                          DropdownMenuItem(
                              value: t, child: Text(formatMinutes(t))),
                      ],
                      onChanged: (v) => setState(() => _start = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _end,
                      decoration: InputDecoration(labelText: l10n.endTime),
                      items: [
                        for (final t in _timeOptions)
                          DropdownMenuItem(
                              value: t, child: Text(formatMinutes(t))),
                      ],
                      onChanged: (v) => setState(() => _end = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                decoration:
                    InputDecoration(labelText: l10n.blockReasonLabel),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed:
                    _busy || court == null ? null : () => _save(court),
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.blockButton),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}
