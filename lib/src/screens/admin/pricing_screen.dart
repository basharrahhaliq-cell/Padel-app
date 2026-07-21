import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../models/branch.dart';
import '../../models/court.dart';
import '../../models/happy_hour_rule.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../utils/time_utils.dart';
import 'happy_hour_editor.dart';

/// Owner pricing controls: base prices per court/duration, and happy hour
/// rules (create / edit / toggle / delete). Includes the one-time
/// "Initialize club data" button for the very first run.
class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final db = context.read<FirestoreService>();

    return StreamBuilder<List<Branch>>(
      stream: db.branches(),
      builder: (context, branchSnap) {
        final branches = branchSnap.data;
        if (branches == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (branches.isEmpty) {
          return Center(
            child: FilledButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: Text(l10n.seedButton),
              onPressed: () async {
                final created = await db.seedClubIfEmpty();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content:
                        Text(created ? l10n.seedDone : l10n.seedSkipped)));
              },
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.basePrices,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final branch in branches) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(branch.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16)),
              ),
              _CourtPriceList(branch: branch),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                // Shrinks the title instead of overflowing when the
                // phone's font size is large.
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(l10n.happyHourRules,
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.newRule),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            HappyHourEditor(branches: branches)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _RuleList(branches: branches),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

class _CourtPriceList extends StatelessWidget {
  final Branch branch;

  const _CourtPriceList({required this.branch});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final db = context.read<FirestoreService>();
    final money = NumberFormat.currency(symbol: '\$');

    return StreamBuilder<List<Court>>(
      stream: db.courts(branch.id),
      builder: (context, snap) {
        final courts = snap.data ?? [];
        return Column(
          children: [
            for (final court in courts)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                      '${court.name} · ${court.type == CourtType.outdoor ? l10n.outdoor : l10n.indoor}'),
                  subtitle: Text(ClubHours.gameDurations
                      .map((d) =>
                          '${d}m ${money.format(court.priceFor(d) ?? 0)}')
                      .join('   ')),
                  trailing: const Icon(Icons.edit, size: 20),
                  onTap: () => _editPrices(context, court),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _editPrices(BuildContext context, Court court) async {
    final l10n = context.l10n;
    final db = context.read<FirestoreService>();
    final controllers = {
      for (final d in ClubHours.gameDurations)
        d: TextEditingController(
            text: (court.priceFor(d) ?? 0).toStringAsFixed(2)),
    };

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editPricesFor(court.name)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final d in ClubHours.gameDurations)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: controllers[d],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.durationLabel(d),
                    prefixText: '\$ ',
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.save)),
        ],
      ),
    );

    if (saved == true) {
      final prices = <int, double>{};
      for (final d in ClubHours.gameDurations) {
        prices[d] =
            double.tryParse(controllers[d]!.text) ?? court.priceFor(d) ?? 0;
      }
      await db.updateCourtPrices(branch.id, court.id, prices);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.saved)));
      }
    }
    for (final c in controllers.values) {
      c.dispose();
    }
  }
}

class _RuleList extends StatelessWidget {
  final List<Branch> branches;

  const _RuleList({required this.branches});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();

    return StreamBuilder<List<HappyHourRule>>(
      stream: db.happyHourRules(),
      builder: (context, snap) {
        final rules = snap.data ?? [];
        if (rules.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Text('—', style: TextStyle(color: Colors.grey.shade500)),
          );
        }
        return Column(
          children: [
            for (final rule in rules)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(Icons.celebration,
                      color: rule.active
                          ? AppTheme.courtBlue
                          : Colors.grey.shade400),
                  title: Text(rule.label),
                  subtitle: Text(_describe(rule)),
                  trailing: Switch(
                    value: rule.active,
                    onChanged: (v) => db.setRuleActive(rule.id, v),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          HappyHourEditor(branches: branches, rule: rule),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _describe(HappyHourRule rule) {
    final branch = branches
        .where((b) => b.id == rule.branchId)
        .map((b) => b.name)
        .firstOrNull ??
        rule.branchId;
    final days = rule.daysOfWeek.map(_dayShort).join(', ');
    final discount = rule.discountType == DiscountType.percent
        ? '-${rule.value.toStringAsFixed(0)}%'
        : '\$${rule.value.toStringAsFixed(0)} fixed';
    return '$branch · $days · '
        '${formatMinutes(rule.startMinutes)}–${formatMinutes(rule.endMinutes)} · $discount';
  }

  String _dayShort(int weekday) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];
}
