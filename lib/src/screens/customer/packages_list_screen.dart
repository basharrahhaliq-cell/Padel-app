import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../models/package_offer.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../utils/time_utils.dart';

/// Customer view of prepaid packages: current wallet, the offers as
/// pricing boxes (tap to request one — the club gets notified), and the
/// wallet activity history (top-ups, deductions, refunds).
class PackagesListScreen extends StatelessWidget {
  final AppUser profile;

  const PackagesListScreen({super.key, required this.profile});

  Future<void> _requestPackage(
      BuildContext context, PackageOffer p, NumberFormat money) async {
    final db = context.read<FirestoreService>();
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Request the ${p.name} package?'),
        content: Text(
            'You pay ${money.format(p.price)} at the club (or by transfer '
            'after the club confirms) and get ${money.format(p.credit)} '
            'of playing credit, valid ${p.validityDays} days.\n\n'
            'The club will be notified and contact you on '
            '${profile.phone}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Request')),
        ],
      ),
    );
    if (sure != true || !context.mounted) return;
    try {
      await db.requestPackage(profile, p);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Request sent! The club will contact you '
              'to arrange payment. 💳')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not send: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final wallet = profile.usableWallet(dateKey(DateTime.now()));
    return Scaffold(
      appBar: AppBar(title: const Text('Packages & Wallet')),
      body: StreamBuilder<List<PackageOffer>>(
        stream: db.packages(),
        builder: (context, snap) {
          final packages =
              (snap.data ?? []).where((p) => p.active).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: AppTheme.courtBlueDark,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('Wallet balance',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 14)),
                      Text(money.format(wallet),
                          style: const TextStyle(
                              color: AppTheme.ballLime,
                              fontSize: 34,
                              fontWeight: FontWeight.bold)),
                      if (wallet > 0)
                        Text('Valid until ${profile.walletExpiry}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Packages',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Tap a package to request it — the club will contact '
                  'you to arrange payment.',
                  style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              if (packages.isEmpty)
                Text('No packages available right now.',
                    style: TextStyle(color: Colors.grey.shade600))
              else if (packages.length <= 3)
                // Equal-height pricing boxes; middle highlighted for 3.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, p) in packages.indexed) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () =>
                                _requestPackage(context, p, money),
                            child: PackageBox(
                              package: p,
                              money: money,
                              highlighted:
                                  packages.length == 3 ? i == 1 : i == 0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: packages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) => SizedBox(
                      width: 150,
                      child: InkWell(
                        onTap: () => _requestPackage(
                            context, packages[i], money),
                        child: PackageBox(
                            package: packages[i],
                            money: money,
                            highlighted: false),
                      ),
                    ),
                  ),
                ),
              _WalletActivity(profile: profile),
            ],
          );
        },
      ),
    );
  }
}

/// Wallet movements: package top-ups (+), booking deductions (−),
/// and refunds of cancelled bookings (+).
class _WalletActivity extends StatelessWidget {
  final AppUser profile;

  const _WalletActivity({required this.profile});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    final money = NumberFormat.currency(symbol: '\$');
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: db.walletTopUps(profile.uid),
      builder: (context, topUpSnap) {
        return StreamBuilder<List<Booking>>(
          stream: db.allMyBookings(profile.uid),
          builder: (context, bookingSnap) {
            final entries = <({DateTime when, String label, double amount})>[];
            for (final t in topUpSnap.data ?? const []) {
              entries.add((
                when: (t['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                label: '${t['packageName']} package',
                amount: (t['credit'] as num?)?.toDouble() ?? 0,
              ));
            }
            for (final b in bookingSnap.data ?? const <Booking>[]) {
              if (b.walletUsed <= 0) continue;
              final when = b.createdAt ?? b.startDateTime;
              entries.add((
                when: when,
                label: '${b.isLesson ? 'Lesson' : 'Booking'} — '
                    '${b.branchName} ${b.courtName}, ${b.date} '
                    '${formatMinutes(b.startMinutes)}',
                amount: -b.walletUsed,
              ));
              if (b.status == BookingStatus.cancelled) {
                entries.add((
                  when: when.add(const Duration(seconds: 1)),
                  label: 'Refund — cancelled booking (${b.date})',
                  amount: b.walletUsed,
                ));
              }
            }
            if (entries.isEmpty) return const SizedBox.shrink();
            entries.sort((a, b) => b.when.compareTo(a.when));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text('Wallet activity',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (final e in entries)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            e.amount >= 0
                                ? Icons.add_circle
                                : Icons.remove_circle,
                            color: e.amount >= 0
                                ? Colors.green
                                : Colors.redAccent,
                            size: 20,
                          ),
                          title: Text(e.label,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                              DateFormat.yMMMd().add_jm().format(e.when),
                              style: const TextStyle(fontSize: 11)),
                          trailing: Text(
                            '${e.amount >= 0 ? '+' : '−'}${money.format(e.amount.abs())}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: e.amount >= 0
                                    ? Colors.green
                                    : Colors.redAccent),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// One pricing box: name, big credit value, price paid, bonus, validity.
/// Always reserves the badge row so boxes stay the same height.
class PackageBox extends StatelessWidget {
  final PackageOffer package;
  final NumberFormat money;
  final bool highlighted;

  const PackageBox(
      {super.key,
      required this.package,
      required this.money,
      required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final bonus = package.credit - package.price;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 14),
      decoration: BoxDecoration(
        color: AppTheme.courtBlueDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              highlighted ? AppTheme.ballLime : Colors.transparent,
          width: 2.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Badge row exists in every box (invisible when not
          // highlighted) so all boxes have identical heights.
          Opacity(
            opacity: highlighted ? 1 : 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.ballLime,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('POPULAR',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.courtBlueDark)),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(package.name.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2)),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('Play ${money.format(package.credit)}',
                style: const TextStyle(
                    color: AppTheme.ballLime,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('Pay ${money.format(package.price)}',
                style:
                    const TextStyle(color: Colors.white, fontSize: 14)),
          ),
          const SizedBox(height: 8),
          Opacity(
            opacity: bonus > 0 ? 1 : 0,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('+${money.format(bonus)} FREE',
                    style: const TextStyle(
                        color: AppTheme.ballLime,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('${package.validityDays} days',
              style:
                  const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}
