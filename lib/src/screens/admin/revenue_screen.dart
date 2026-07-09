import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
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
    for (final b in real) {
      weekTotals[b.branchName] = (weekTotals[b.branchName] ?? 0) + b.price;
      if (b.isLesson) weekLessons += b.price;
      if (b.date == dateKey(_date)) {
        dayTotals[b.branchName] = (dayTotals[b.branchName] ?? 0) + b.price;
        if (b.isLesson) dayLessons += b.price;
      }
    }
    return _RevenueData(
      dayTotals: dayTotals,
      weekTotals: weekTotals,
      dayCount: real.where((b) => b.date == dateKey(_date)).length,
      weekCount: real.length,
      dayLessons: dayLessons,
      weekLessons: weekLessons,
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
                money: money,
              ),
              const SizedBox(height: 12),
              Text(l10n.revenueNote,
                  style:
                      TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          );
        },
      ),
    );
  }

  Widget _totalsCard(BuildContext context,
      {required String title,
      required Map<String, double> totals,
      required int count,
      required double lessons,
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
  final DateTime monday;
  final DateTime sunday;

  const _RevenueData({
    required this.dayTotals,
    required this.weekTotals,
    required this.dayCount,
    required this.weekCount,
    required this.dayLessons,
    required this.weekLessons,
    required this.monday,
    required this.sunday,
  });
}
