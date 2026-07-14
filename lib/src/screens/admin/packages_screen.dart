import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/package_offer.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';

/// Owner prepaid packages: define offers (pay X -> play with Y, valid N
/// days) and grant them to customers after they pay at the club.
class PackagesScreen extends StatelessWidget {
  const PackagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return Scaffold(
      appBar: AppBar(title: const Text('Packages & Wallet')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New package'),
        onPressed: () => _edit(context, null),
      ),
      body: StreamBuilder<List<PackageOffer>>(
        stream: db.packages(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final packages = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              Card(
                color: AppTheme.courtBlueDark,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'How it works: the customer pays at the club, then you '
                    'tap "Grant" and pick their name — the credit lands in '
                    'their app wallet instantly and they book with it.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (packages.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No packages yet — create the first one, '
                      'e.g. "Pay \$300 → Play \$400, 30 days".'),
                ),
              for (final p in packages)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: p.active
                          ? AppTheme.ballLime
                          : Colors.grey.shade300,
                      child: const Icon(Icons.account_balance_wallet,
                          color: AppTheme.courtBlueDark, size: 20),
                    ),
                    title: Text(p.name,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        'Pay ${money.format(p.price)} → play with '
                        '${money.format(p.credit)} · ${p.validityDays} days'),
                    trailing: FilledButton.tonal(
                      onPressed: () => _grant(context, p),
                      child: const Text('Grant'),
                    ),
                    onTap: () => _edit(context, p),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, PackageOffer? existing) async {
    final db = context.read<FirestoreService>();
    final name = TextEditingController(text: existing?.name);
    final price = TextEditingController(
        text: existing == null ? '300' : existing.price.toStringAsFixed(0));
    final credit = TextEditingController(
        text:
            existing == null ? '400' : existing.credit.toStringAsFixed(0));
    final days = TextEditingController(
        text: (existing?.validityDays ?? 30).toString());

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'New package' : 'Edit package'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(
                    labelText: 'Name (e.g. Gold Pack)')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Customer pays', prefixText: '\$ ')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                    controller: credit,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Wallet credit', prefixText: '\$ ')),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
                controller: days,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Valid for (days)')),
          ],
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () async {
                await db.deletePackage(existing.id);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent)),
            ),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final priceV = double.tryParse(price.text);
              final creditV = double.tryParse(credit.text);
              final daysV = int.tryParse(days.text);
              String? problem;
              if (name.text.trim().isEmpty) {
                problem = 'Give the package a name.';
              } else if (priceV == null || priceV <= 0) {
                problem = '"Customer pays" must be a number above 0.';
              } else if (creditV == null || creditV < priceV) {
                problem =
                    '"Wallet credit" must be at least what the customer pays.';
              } else if (daysV == null || daysV <= 0) {
                problem = '"Valid for" must be a number of days above 0.';
              }
              if (problem != null) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(problem)));
                return;
              }
              try {
                await db.savePackage(PackageOffer(
                  id: existing?.id ?? '',
                  name: name.text.trim(),
                  price: priceV!,
                  credit: creditV!,
                  validityDays: daysV!,
                  active: existing?.active ?? true,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString().contains('permission')
                        ? 'The database refused this — your security rules '
                            'are outdated. Run the rules deploy command '
                            'from SETUP.md Part 2b.'
                        : 'Could not save: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Pick the customer who just paid, confirm, credit their wallet.
  Future<void> _grant(BuildContext context, PackageOffer package) async {
    final db = context.read<FirestoreService>();
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final usersSnap =
        await FirebaseFirestore.instance.collection('users').get();
    if (!context.mounted) return;
    final customers = usersSnap.docs
        .map(AppUser.fromDoc)
        .where((u) => !u.isAdmin)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final search = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState) {
          final q = search.text.trim().toLowerCase();
          final filtered = q.isEmpty
              ? customers
              : customers
                  .where((u) =>
                      u.name.toLowerCase().contains(q) ||
                      u.phone.contains(q))
                  .toList();
          return AlertDialog(
            title: Text('Grant "${package.name}"'),
            content: SizedBox(
              width: double.maxFinite,
              height: 360,
              child: Column(
                children: [
                  TextField(
                    controller: search,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search name or phone'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final u in filtered)
                          ListTile(
                            dense: true,
                            title: Text(
                                u.name.isEmpty ? '(no name)' : u.name),
                            subtitle: Text(u.phone),
                            onTap: () async {
                              final sure = await showDialog<bool>(
                                context: ctx2,
                                builder: (ctx3) => AlertDialog(
                                  title: const Text('Confirm'),
                                  content: Text(
                                      '${u.name} paid ${money.format(package.price)} '
                                      'and receives ${money.format(package.credit)} '
                                      'wallet credit valid ${package.validityDays} days?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx3, false),
                                        child: const Text('Cancel')),
                                    FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx3, true),
                                        child: const Text('Grant')),
                                  ],
                                ),
                              );
                              if (sure == true) {
                                await db.grantPackage(u, package);
                                if (ctx2.mounted) Navigator.pop(ctx2);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                          content: Text(
                                              '${money.format(package.credit)} '
                                              'credited to ${u.name} ✅')));
                                }
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx2),
                  child: const Text('Close')),
            ],
          );
        },
      ),
    );
  }
}
