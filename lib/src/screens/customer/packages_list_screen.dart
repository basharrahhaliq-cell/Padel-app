import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/package_offer.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../utils/time_utils.dart';

/// Customer view of prepaid packages: current wallet + available offers
/// (paid at the club; the owner credits the wallet on the spot).
class PackagesListScreen extends StatelessWidget {
  final AppUser profile;

  const PackagesListScreen({super.key, required this.profile});

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
              const SizedBox(height: 16),
              Text('Available packages',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                  'Pay at the club and the credit lands in your wallet '
                  'instantly — then book courts and lessons with it.',
                  style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              if (packages.isEmpty)
                Text('No packages available right now.',
                    style: TextStyle(color: Colors.grey.shade600)),
              for (final p in packages)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.ballLime,
                      child: Icon(Icons.account_balance_wallet,
                          color: AppTheme.courtBlueDark),
                    ),
                    title: Text(
                        'Pay ${money.format(p.price)} → play with ${money.format(p.credit)}',
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${p.name} · valid ${p.validityDays} days · '
                        'you gain ${money.format(p.credit - p.price)} free'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
