import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/package_offer.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../utils/time_utils.dart';

/// Customer view of prepaid packages: current wallet + the offers shown
/// as pricing boxes (paid at the club; the owner credits the wallet).
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
              const SizedBox(height: 20),
              Text('Packages',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                  'Pay at the club and the credit lands in your wallet '
                  'instantly — book courts and lessons with it.',
                  style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              if (packages.isEmpty)
                Text('No packages available right now.',
                    style: TextStyle(color: Colors.grey.shade600))
              else if (packages.length <= 3)
                // Pricing-table style: boxes side by side, middle
                // highlighted when there are exactly three tiers.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, p) in packages.indexed) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: _PackageBox(
                          package: p,
                          money: money,
                          highlighted:
                              packages.length == 3 ? i == 1 : i == 0,
                        ),
                      ),
                    ],
                  ],
                )
              else
                SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: packages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) => SizedBox(
                      width: 150,
                      child: _PackageBox(
                          package: packages[i],
                          money: money,
                          highlighted: false),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One pricing box: name, big credit value, price paid, bonus, validity.
class _PackageBox extends StatelessWidget {
  final PackageOffer package;
  final NumberFormat money;
  final bool highlighted;

  const _PackageBox(
      {required this.package,
      required this.money,
      required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final bonus = package.credit - package.price;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
      decoration: BoxDecoration(
        color: AppTheme.courtBlueDark,
        borderRadius: BorderRadius.circular(16),
        border: highlighted
            ? Border.all(color: AppTheme.ballLime, width: 2.5)
            : null,
      ),
      child: Column(
        children: [
          if (highlighted)
            Container(
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
                style: const TextStyle(
                    color: Colors.white, fontSize: 14)),
          ),
          const SizedBox(height: 8),
          if (bonus > 0)
            FittedBox(
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
          const SizedBox(height: 8),
          Text('${package.validityDays} days',
              style:
                  const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}
