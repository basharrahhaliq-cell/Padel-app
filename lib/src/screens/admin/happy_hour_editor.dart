import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../models/branch.dart';
import '../../models/court.dart';
import '../../models/happy_hour_rule.dart';
import '../../services/firestore_service.dart';
import '../../utils/time_utils.dart';

/// Create or edit one happy hour rule.
class HappyHourEditor extends StatefulWidget {
  final List<Branch> branches;
  final HappyHourRule? rule; // null = creating a new rule

  const HappyHourEditor({super.key, required this.branches, this.rule});

  @override
  State<HappyHourEditor> createState() => _HappyHourEditorState();
}

class _HappyHourEditorState extends State<HappyHourEditor> {
  late final TextEditingController _label =
      TextEditingController(text: widget.rule?.label ?? 'Happy Hour');
  late final TextEditingController _value = TextEditingController(
      text: widget.rule == null ? '20' : widget.rule!.value.toString());

  late String _branchId = widget.rule?.branchId ?? widget.branches.first.id;
  late final Set<int> _days =
      {...(widget.rule?.daysOfWeek ?? [1, 2, 3, 4, 5])};
  late Set<String> _courtIds = {...(widget.rule?.courtIds ?? const [])};
  late int _start = widget.rule?.startMinutes ?? ClubHours.openMinutes;
  late int _end = widget.rule?.endMinutes ?? 16 * 60;
  late DiscountType _type = widget.rule?.discountType ?? DiscountType.percent;
  late bool _active = widget.rule?.active ?? true;
  bool _busy = false;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void dispose() {
    _label.dispose();
    _value.dispose();
    super.dispose();
  }

  List<int> get _timeOptions => [
        for (int t = ClubHours.openMinutes;
            t <= ClubHours.closeMinutes;
            t += ClubHours.slotStepMinutes)
          t
      ];

  Future<void> _save() async {
    final l10n = context.l10n;
    final db = context.read<FirestoreService>();
    if (_end <= _start) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.invalidTimeRange)));
      return;
    }
    setState(() => _busy = true);
    final rule = HappyHourRule(
      id: widget.rule?.id ?? '',
      label: _label.text.trim().isEmpty ? 'Happy Hour' : _label.text.trim(),
      branchId: _branchId,
      courtIds: _courtIds.toList(),
      daysOfWeek: (_days.toList()..sort()),
      startMinutes: _start,
      endMinutes: _end,
      discountType: _type,
      value: double.tryParse(_value.text) ?? 0,
      active: _active,
    );
    try {
      await db.saveHappyHourRule(rule);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.genericError(e.toString()))));
    }
  }

  Future<void> _delete() async {
    final db = context.read<FirestoreService>();
    if (widget.rule == null) return;
    await db.deleteHappyHourRule(widget.rule!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final db = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rule == null ? l10n.newRule : l10n.editRule),
        actions: [
          if (widget.rule != null)
            IconButton(
              tooltip: l10n.deleteRule,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _label,
            decoration: InputDecoration(labelText: l10n.ruleLabelField),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _branchId,
            decoration: InputDecoration(labelText: l10n.chooseBranch),
            items: [
              for (final b in widget.branches)
                DropdownMenuItem(value: b.id, child: Text(b.name)),
            ],
            onChanged: (v) => setState(() {
              _branchId = v!;
              _courtIds = {};
            }),
          ),
          const SizedBox(height: 16),
          Text(l10n.courtsLabel),
          const SizedBox(height: 8),
          StreamBuilder<List<Court>>(
            stream: db.courts(_branchId),
            builder: (context, snap) {
              final courts = snap.data ?? [];
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    selected: _courtIds.isEmpty,
                    label: Text(l10n.allCourtsOption),
                    onSelected: (_) => setState(() => _courtIds = {}),
                  ),
                  for (final c in courts)
                    FilterChip(
                      selected: _courtIds.contains(c.id),
                      label: Text(c.name),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _courtIds.add(c.id);
                        } else {
                          _courtIds.remove(c.id);
                        }
                      }),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(l10n.daysLabel),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int d = 1; d <= 7; d++)
                FilterChip(
                  selected: _days.contains(d),
                  label: Text(_dayNames[d - 1]),
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      _days.add(d);
                    } else {
                      _days.remove(d);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _start,
                  decoration: InputDecoration(labelText: l10n.fromLabel),
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
                  decoration: InputDecoration(labelText: l10n.toLabel),
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
          const SizedBox(height: 16),
          SegmentedButton<DiscountType>(
            segments: [
              ButtonSegment(
                  value: DiscountType.percent,
                  label: Text(l10n.percentOff)),
              ButtonSegment(
                  value: DiscountType.fixedPrice,
                  label: Text(l10n.fixedPriceLabel)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _value,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _type == DiscountType.percent
                  ? l10n.percentValueLabel
                  : l10n.fixedValueLabel,
              prefixText: _type == DiscountType.fixedPrice ? '\$ ' : null,
              suffixText: _type == DiscountType.percent ? '%' : null,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: Text(l10n.activeLabel),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.save),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
