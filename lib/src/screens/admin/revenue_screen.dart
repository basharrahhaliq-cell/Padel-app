import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../main.dart';
import '../../models/booking.dart';
import '../../models/branch.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../utils/time_utils.dart';

/// Expected revenue per branch, today and this week (Mon–Sun),
/// summed from confirmed bookings' stored prices (blocks excluded).
/// Fed by a live stream so recorded payments show instantly, even
/// before the write reaches the server (important on slow connections).
class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  DateTime _date = DateTime.now();
  String? _branchId; // null = all branches

  _RevenueData _compute(
      List<Booking> rangeBookings, DateTime monday, DateTime sunday) {
    final all = rangeBookings
        .where((b) =>
            !b.isBlock && (_branchId == null || b.branchId == _branchId))
        .toList();
    final weekFrom = dateKey(monday);
    final weekTo = dateKey(sunday);
    final monthFrom = dateKey(DateTime(_date.year, _date.month, 1));
    final monthTo = dateKey(DateTime(_date.year, _date.month + 1, 0));

    final dayTotals = <String, double>{};
    final weekTotals = <String, double>{};
    final monthTotals = <String, double>{};
    int weekCount = 0;
    double dayLessons = 0;
    double weekLessons = 0;
    double monthLessons = 0;
    double dayReceived = 0;
    double weekReceived = 0;
    double monthReceived = 0;
    final monthBookings = <Booking>[];
    for (final b in all) {
      // The stream covers the week AND the calendar month of the
      // picked date; each booking lands in whichever buckets apply.
      final received = b.walletUsed + (b.paidAmount ?? 0);
      if (b.date.compareTo(monthFrom) >= 0 &&
          b.date.compareTo(monthTo) <= 0) {
        monthBookings.add(b);
        monthTotals[b.branchName] =
            (monthTotals[b.branchName] ?? 0) + b.price;
        if (b.isLesson) monthLessons += b.price;
        // Received = wallet credit already collected + cash recorded.
        monthReceived += received;
      }
      if (b.date.compareTo(weekFrom) >= 0 && b.date.compareTo(weekTo) <= 0) {
        weekCount++;
        weekTotals[b.branchName] = (weekTotals[b.branchName] ?? 0) + b.price;
        if (b.isLesson) weekLessons += b.price;
        weekReceived += received;
      }
      if (b.date == dateKey(_date)) {
        dayTotals[b.branchName] = (dayTotals[b.branchName] ?? 0) + b.price;
        if (b.isLesson) dayLessons += b.price;
        dayReceived += received;
      }
    }
    final dayBookings =
        all.where((b) => b.date == dateKey(_date)).toList()
          ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    monthBookings.sort((a, b) => a.date == b.date
        ? a.startMinutes.compareTo(b.startMinutes)
        : a.date.compareTo(b.date));
    return _RevenueData(
      dayTotals: dayTotals,
      weekTotals: weekTotals,
      monthTotals: monthTotals,
      dayCount: dayBookings.length,
      weekCount: weekCount,
      monthCount: monthBookings.length,
      dayLessons: dayLessons,
      weekLessons: weekLessons,
      monthLessons: monthLessons,
      dayReceived: dayReceived,
      weekReceived: weekReceived,
      monthReceived: monthReceived,
      dayBookings: dayBookings,
      monthBookings: monthBookings,
      monday: monday,
      sunday: sunday,
    );
  }

  /// Accounting export: pick any date range (defaults to the picked
  /// month), then share one CSV row per booking — openable in Excel.
  Future<void> _exportCsv() async {
    final db = context.read<FirestoreService>();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: DateTime(_date.year, _date.month, 1),
        end: DateTime(_date.year, _date.month + 1, 0),
      ),
      helpText: 'Export bookings from — to',
    );
    if (range == null) return;
    final bookings =
        (await db.bookingsBetween(dateKey(range.start), dateKey(range.end)))
            .where((b) =>
                !b.isBlock &&
                (_branchId == null || b.branchId == _branchId))
            .toList()
          ..sort((a, b) => a.date == b.date
              ? a.startMinutes.compareTo(b.startMinutes)
              : a.date.compareTo(b.date));
    if (bookings.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No bookings in that period.')));
      }
      return;
    }
    String esc(String v) =>
        v.contains(RegExp(r'[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
    final buf = StringBuffer(
        'Date,Time,Customer,Phone,Branch,Court,Minutes,Type,'
        'Price USD,Wallet used,Cash received,Payment\n');
    for (final b in bookings) {
      buf.writeln([
        b.date,
        formatMinutes(b.startMinutes),
        b.userName,
        b.userPhone,
        b.branchName,
        b.courtName,
        '${b.durationMinutes}',
        b.isLesson ? 'lesson' : 'court',
        b.price.toStringAsFixed(2),
        b.walletUsed.toStringAsFixed(2),
        b.paidAmount?.toStringAsFixed(2) ?? '',
        b.paidAmount != null ? 'paid' : 'pending',
      ].map(esc).join(','));
    }
    final period = '${dateKey(range.start)}_${dateKey(range.end)}';
    final branch = _branchId ?? 'all-branches';
    final dir = await getTemporaryDirectory();
    final file =
        File('${dir.path}/lets-padel-revenue-$period-$branch.csv');
    await file.writeAsString(buf.toString());
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Let\'s Padel revenue $period ($branch)',
    ));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final money = NumberFormat.currency(symbol: '\$');
    final db = context.read<FirestoreService>();
    final monday = _date.subtract(Duration(days: _date.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    // The stream covers the picked week AND its calendar month, so the
    // day, week and month cards all come from the same live data.
    final monthFirst = DateTime(_date.year, _date.month, 1);
    final monthLast = DateTime(_date.year, _date.month + 1, 0);
    final rangeFrom = monday.isBefore(monthFirst) ? monday : monthFirst;
    final rangeTo = sunday.isAfter(monthLast) ? sunday : monthLast;

    return StreamBuilder<List<Booking>>(
      // Keyed by the range so picking another date swaps the stream.
      key: ValueKey(dateKey(rangeFrom)),
      stream: db.bookingsBetweenStream(dateKey(rangeFrom), dateKey(rangeTo)),
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
        final data = _compute(snap.data!, monday, sunday);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<List<Branch>>(
                    stream:
                        context.read<FirestoreService>().branches(),
                    builder: (context, branchSnap) {
                      final branches = branchSnap.data ?? [];
                      return DropdownButtonFormField<String?>(
                        isExpanded: true,
                        initialValue: _branchId,
                        isDense: true,
                        decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8)),
                        items: [
                          const DropdownMenuItem(
                              value: null,
                              child: Text('All branches')),
                          for (final b in branches)
                            DropdownMenuItem(
                                value: b.id, child: Text(b.name)),
                        ],
                        onChanged: (v) => setState(() => _branchId = v),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(DateFormat.MMMd().format(_date)),
                  onPressed: _pickDate,
                ),
              ],
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
            _totalsCard(
              context,
              title:
                  'This month · ${DateFormat.yMMMM().format(_date)}',
              totals: data.monthTotals,
              count: data.monthCount,
              lessons: data.monthLessons,
              received: data.monthReceived,
              money: money,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.table_view),
              label: const Text('Export report (Excel/CSV) — pick dates'),
              onPressed: _exportCsv,
            ),
            const SizedBox(height: 12),
            Text(l10n.revenueNote,
                style:
                    TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            if (data.dayBookings.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Cash box — record payments',
                  style: Theme.of(context).textTheme.titleLarge),
              Text(
                  'Tap a booking when the customer pays and enter the '
                  'amount you actually received (friend rates welcome).',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 8),
              for (final b in data.dayBookings)
                _paymentRow(context, b, money),
            ],
          ],
        );
      },
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
  /// The write is NOT awaited: the stream above repaints instantly from
  /// the phone's local copy while Firestore syncs in the background, so
  /// the row turns green immediately even on a slow connection.
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
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    // Fire and forget — see the doc comment above.
    context
        .read<FirestoreService>()
        .recordPayment(b.id, amount)
        .catchError((Object e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Payment did not save: $e')));
    });
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
  final Map<String, double> monthTotals;
  final int dayCount;
  final int weekCount;
  final int monthCount;
  final double dayLessons;
  final double weekLessons;
  final double monthLessons;
  final double dayReceived;
  final double weekReceived;
  final double monthReceived;
  final List<Booking> dayBookings;
  final List<Booking> monthBookings;
  final DateTime monday;
  final DateTime sunday;

  const _RevenueData({
    required this.dayTotals,
    required this.weekTotals,
    required this.monthTotals,
    required this.dayCount,
    required this.weekCount,
    required this.monthCount,
    required this.dayLessons,
    required this.weekLessons,
    required this.monthLessons,
    required this.dayReceived,
    required this.weekReceived,
    required this.monthReceived,
    required this.dayBookings,
    required this.monthBookings,
    required this.monday,
    required this.sunday,
  });
}
