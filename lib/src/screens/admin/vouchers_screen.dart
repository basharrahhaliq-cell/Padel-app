import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/branch.dart';
import '../../models/voucher.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../utils/time_utils.dart';

/// Owner voucher management: create/edit/toggle codes and see usage stats.
class VouchersScreen extends StatelessWidget {
  const VouchersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    final money = NumberFormat.currency(symbol: '\$');
    return Scaffold(
      appBar: AppBar(title: const Text('Vouchers')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New code'),
        onPressed: () => _edit(context, null),
      ),
      body: StreamBuilder<List<Voucher>>(
        stream: db.vouchers(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final vouchers = snap.data!;
          if (vouchers.isEmpty) {
            return const Center(
                child: Text('No voucher codes yet — create one!'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              for (final v in vouchers)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Icon(Icons.confirmation_number,
                        color: v.active
                            ? AppTheme.courtBlue
                            : Colors.grey.shade400),
                    title: Text(v.code,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${v.discountType == 'percent' ? '${v.value.toStringAsFixed(0)}% off' : '${money.format(v.value)} off'}'
                      ' · expires ${v.expiry.isEmpty ? 'never' : v.expiry}\n'
                      'Used ${v.uses}${v.maxUses > 0 ? '/${v.maxUses}' : ''} times · '
                      '${money.format(v.totalDiscount)} total discount given',
                    ),
                    isThreeLine: true,
                    trailing: Switch(
                      value: v.active,
                      onChanged: (on) => db.setVoucherActive(v.code, on),
                    ),
                    onTap: () => _edit(context, v),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, Voucher? existing) async {
    final db = context.read<FirestoreService>();
    final branches = await db.branches().first;
    if (!context.mounted) return;

    final code = TextEditingController(text: existing?.code);
    final value = TextEditingController(
        text: existing == null ? '20' : existing.value.toStringAsFixed(0));
    final maxUses = TextEditingController(
        text: (existing?.maxUses ?? 100).toString());
    final maxPer = TextEditingController(
        text: (existing?.maxUsesPerCustomer ?? 1).toString());
    String type = existing?.discountType ?? 'percent';
    DateTime expiry = existing != null && existing.expiry.isNotEmpty
        ? parseDateKey(existing.expiry)
        : DateTime.now().add(const Duration(days: 30));
    Set<String> branchIds = {...existing?.branchIds ?? const []};

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState) => AlertDialog(
          title: Text(existing == null ? 'New voucher' : existing.code),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (existing == null)
                  TextField(
                    controller: code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                        labelText: 'Code (e.g. RAMADAN20)'),
                  ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'percent', label: Text('% off')),
                    ButtonSegment(value: 'fixed', label: Text('\$ off')),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) =>
                      setState(() => type = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: value,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: type == 'percent'
                          ? 'Percent off'
                          : 'Amount off (USD)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: maxUses,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Max total uses'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: maxPer,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Max per customer'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(
                      'Expires ${DateFormat.yMMMd().format(expiry)}'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx2,
                      initialDate: expiry,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) setState(() => expiry = picked);
                  },
                ),
                const SizedBox(height: 12),
                const Text('Branches'),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      selected: branchIds.isEmpty,
                      label: const Text('All'),
                      onSelected: (_) => setState(() => branchIds = {}),
                    ),
                    for (final Branch b in branches)
                      FilterChip(
                        selected: branchIds.contains(b.id),
                        label: Text(b.name),
                        onSelected: (on) => setState(() {
                          on ? branchIds.add(b.id) : branchIds.remove(b.id);
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  await db.deleteVoucher(existing.code);
                  if (ctx2.mounted) Navigator.pop(ctx2);
                },
                child: const Text('Delete',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(
                onPressed: () => Navigator.pop(ctx2),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final codeText =
                    (existing?.code ?? code.text).trim().toUpperCase();
                if (codeText.isEmpty) return;
                await db.saveVoucher(Voucher(
                  code: codeText,
                  discountType: type,
                  value: double.tryParse(value.text) ?? 0,
                  expiry: dateKey(expiry),
                  maxUses: int.tryParse(maxUses.text) ?? 0,
                  maxUsesPerCustomer: int.tryParse(maxPer.text) ?? 1,
                  branchIds: branchIds.toList(),
                  active: existing?.active ?? true,
                ));
                if (ctx2.mounted) Navigator.pop(ctx2);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
