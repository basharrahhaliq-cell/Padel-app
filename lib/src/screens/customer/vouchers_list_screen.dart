import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/voucher.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../utils/time_utils.dart';

/// Active voucher codes customers can use at checkout.
class VouchersListScreen extends StatelessWidget {
  const VouchersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    final money = NumberFormat.currency(symbol: '\$');
    final today = dateKey(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Vouchers')),
      body: StreamBuilder<List<Voucher>>(
        stream: db.vouchers(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final usable = snap.data!
              .where((v) =>
                  v.active &&
                  (v.expiry.isEmpty || v.expiry.compareTo(today) >= 0) &&
                  (v.maxUses == 0 || v.uses < v.maxUses))
              .toList();
          if (usable.isEmpty) {
            return const Center(
                child: Text('No active vouchers right now — check back '
                    'soon!'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Enter a code at checkout to get the discount:'),
              const SizedBox(height: 12),
              for (final v in usable)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.confirmation_number,
                        color: AppTheme.courtBlue),
                    title: Text(v.code,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '${v.discountType == 'percent' ? '${v.value.toStringAsFixed(0)}% off' : '${money.format(v.value)} off'} '
                        '· valid until ${v.expiry.isEmpty ? 'further notice' : v.expiry}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
