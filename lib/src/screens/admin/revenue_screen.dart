import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../models/booking.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../utils/time_utils.dart';

/// Expected revenue per branch, today and this week (Mon–Sun),
/// summed from confirmed bookings' stored prices (blocks excluded).
class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  DateTime _date = DateTime.now();
  late Future<_RevenueData> _future = _load();

  Future<_RevenueData> _load() async {
    final db = context.read<FirestoreService>();
    final monday = _date.subtract(Duration(days: _date.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final weekBookings =
        await db.bookingsBetween(dateKey(monday), dateKey(sunday));
    final real = weekBookings.where((b) => !b.isBlock).toList();

    final dayTotals = <String, double>{};
    final weekTotals = <String, double>{};
    double dayLessons = 0;
    double weekLessons = 0;
    double dayReceived = 0;
    double weekReceived = 0;
    for (final b in real) {
      weekTotals[b.branchName] = (weekTotals[b.branchName] ?? 0) + b.price;
      if (b.isLesson) weekLessons += b.price;
      // Received = wallet credit already collected + cash recorded.
      final received = b.walletUsed + (b.paidAmount ?? 0);
      weekReceived += received;
      if (b.date == dateKey(_date)) {
        dayTotals[b.branchName] = (dayTotals[b.branchName] ?? 0) + b.price;
        if (b.isLesson) dayLessons += b.price;
        dayReceived += received;
      }
    }
    final dayBookings =
        real.where((b) => b.date == dateKey(_date)).toList()
          ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return _RevenueData(
      dayTotals: dayTotals,
      weekTotals: weekTotals,
      dayCount: dayBookings.length,
      weekCount: real.length,
      dayLessons: dayLessons,
      weekLessons: weekLessons,
      dayReceived: dayReceived,
      weekReceived: weekReceived,
      dayBookings: dayBookings,
      monday: monday,
      sunday: sunday,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _future = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final money = NumberFormat.currency(symbol: '\$');

    return RefreshIndicator(
      onRefresh: () async => setState(() => _future = _load()),
      child: FutureBuilder<_RevenueData>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load revenue:\n${snap.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(DateFormat.yMMMEd().format(_date)),
                onPressed: _pickDate,
              ),
              const SizedBox(height: 16),
              _totalsCard(
                context,
                title: '${l10n.todayLabel} — '
                    '${DateFormat.MMMEd().format(_date)}',
                totals: data.dayTotals,
                count: data.dayCount,
                lessons: data.dayLessons,
                received: data.dayReceived,
                money: money,
              ),
              const SizedBox(height: 12),
              _totalsCard(
                context,
                title: '${l10n.thisWeekLabel} · '
                    '${DateFormat.MMMd().format(data.monday)} – ${DateFormat.MMMd().format(data.sunday)}',
                totals: data.weekTotals,
                count: data.weekCount,
                lessons: data.weekLessons,
                received: data.weekReceived,
                money: money,
              ),
              const SizedBox(height: 12),
              Text(l10n.revenueNote,
                  style:
                      TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              if (data.dayBookings.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Record payments',
                    style: Theme.of(context).textTheme.titleLarge),
                Text('Tap a booking when the customer pays at the club.',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 8),
                for (final b in data.dayBookings)
                  _paymentRow(context, b, money),
              ],
            ],
          );
        },
      ),
    );
  }

  /// One row per booking of the day: paid ✓ or "tap to record".
  Widget _paymentRow(
      BuildContext context, Booking b, NumberFormat money) {
    final paid = b.paidAmount != null;
    final expectedCash = b.price - b.walletUsed;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(
          paid ? Icons.check_circle : Icons.hourglass_empty,
          color: paid ? Colors.green : Colors.grey,
        ),
        title: Text(
            '${b.userName}${b.isLesson ? ' · lesson' : ''} — '
            '${b.courtName} ${formatMinutes(b.startMinutes)}'),
        subtitle: Text(paid
            ? 'Received ${money.format(b.paidAmount)}'
                '${b.walletUsed > 0 ? ' + ${money.format(b.walletUsed)} wallet' : ''}'
            : 'Expected ${money.format(expectedCash)}'
                '${b.walletUsed > 0 ? ' (after ${money.format(b.walletUsed)} wallet)' : ''}'),
        trailing: paid
            ? Text(money.format(b.paidAmount),
                style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 15))
            : const Text('Tap to record',
                style: TextStyle(color: AppTheme.courtBlue, fontSize: 12)),
        onTap: () => _recordPayment(b),
      ),
    );
  }

  /// Records (or corrects) the cash actually received for a booking.
  Future<void> _recordPayment(Booking b) async {
    final money = NumberFormat.currency(symbol: '\$');
    final expectedCash = b.price - b.walletUsed;
    final controller = TextEditingController(
        text: (b.paidAmount ?? expectedCash).toStringAsFixed(2));
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Payment — ${b.userName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Booking price ${money.format(b.price)}'
                '${b.walletUsed > 0 ? ' · wallet already covered ${money.format(b.walletUsed)}' : ''}',
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Amount received', prefixText: '\$ '),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    final amount = double.tryParse(controller.text);
    if (amount == null || amount < 0) return;
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(b.id)
        .update({'paidAmount': amount, 'paymentStatus': 'paid'});
    if (!mounted) return;
    setState(() => _future = _load());
  }

  Widget _totalsCard(BuildContext context,
      {required String title,
      required Map<String, double> totals,
      required int count,
      required double lessons,
      required double received,
      required NumberFormat money}) {
    final l10n = context.l10n;
    final grand = totals.values.fold<double>(0, (a, b) => a + b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final entry in totals.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key),
                    Text(money.format(entry.value),
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            if (lessons > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('of which academy lessons',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                    Text(money.format(lessons),
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 13)),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Received so far',
                      style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  Text(money.format(received),
                      style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.bookingsCount(count)),
                Text(money.format(grand),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                            color: AppTheme.courtBlue,
                            fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueData {
  final Map<String, double> dayTotals;
  final Map<String, double> weekTotals;
  final int dayCount;
  final int weekCount;
  final double dayLessons;
  final double weekLessons;
  final double dayReceived;
  final double weekReceived;
  final List<Booking> dayBookings;
  final DateTime monday;
  final DateTime sunday;

  const _RevenueData({
    required this.dayTotals,
    required this.weekTotals,
    required this.dayCount,
    required this.weekCount,
    required this.dayLessons,
    required this.weekLessons,
    required this.dayReceived,
    required this.weekReceived,
    required this.dayBookings,
    required this.monday,
    required this.sunday,
  });
}
