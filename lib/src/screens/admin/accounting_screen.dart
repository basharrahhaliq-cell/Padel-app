import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/booking.dart';
import '../../models/branch.dart';
import '../../models/expense.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../utils/time_utils.dart';

/// The club's books for any period: money in (booking cash + package
/// payments), money out (recorded expenses), and the profit line.
class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  late DateTimeRange _range = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
  );
  String? _branchId; // null = whole club

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _range,
      helpText: 'Accounting period',
    );
    if (picked != null) setState(() => _range = picked);
  }

  bool _inRange(String date) =>
      date.compareTo(dateKey(_range.start)) >= 0 &&
      date.compareTo(dateKey(_range.end)) <= 0;

  /// Old top-up entries have no 'date' key — fall back to createdAt.
  String _topUpDate(Map<String, dynamic> t) {
    final date = t['date'] as String?;
    if (date != null && date.isNotEmpty) return date;
    final created = t['createdAt'];
    if (created is Timestamp) return dateKey(created.toDate());
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    final money = NumberFormat.currency(symbol: '\$');
    final from = dateKey(_range.start);
    final to = dateKey(_range.end);
    return Scaffold(
      appBar: AppBar(title: const Text('Accounting')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.remove_circle_outline),
        label: const Text('Add expense'),
        onPressed: () => _addExpense(context),
      ),
      body: StreamBuilder<List<Booking>>(
        key: ValueKey('$from-$to'),
        stream: db.bookingsBetweenStream(from, to),
        builder: (context, bookingSnap) =>
            StreamBuilder<List<Expense>>(
          stream: db.expensesBetween(from, to),
          builder: (context, expenseSnap) =>
              StreamBuilder<List<Map<String, dynamic>>>(
            stream: db.allWalletTopUps(),
            builder: (context, topUpSnap) {
              if (!bookingSnap.hasData ||
                  !expenseSnap.hasData ||
                  !topUpSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final bookings = bookingSnap.data!
                  .where((b) =>
                      !b.isBlock &&
                      (_branchId == null || b.branchId == _branchId))
                  .toList();
              final expenses = expenseSnap.data!
                  .where((e) =>
                      _branchId == null ||
                      e.branchId == _branchId ||
                      e.branchId.isEmpty)
                  .toList()
                ..sort((a, b) => b.date.compareTo(a.date));
              // Package money is club-wide (not tied to one branch),
              // so it only counts when viewing the whole club.
              final topUps = _branchId != null
                  ? const <Map<String, dynamic>>[]
                  : topUpSnap.data!
                      .where((t) => _inRange(_topUpDate(t)))
                      .toList();

              final bookingCash = bookings.fold<double>(
                  0, (a, b) => a + (b.paidAmount ?? 0));
              final packageCash = topUps.fold<double>(
                  0, (a, t) => a + ((t['paid'] as num?) ?? 0).toDouble());
              final income = bookingCash + packageCash;
              final spent =
                  expenses.fold<double>(0, (a, e) => a + e.amount);
              final profit = income - spent;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StreamBuilder<List<Branch>>(
                          stream: db.branches(),
                          builder: (context, branchSnap) =>
                              DropdownButtonFormField<String?>(
                            isExpanded: true,
                            initialValue: _branchId,
                            isDense: true,
                            decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8)),
                            items: [
                              const DropdownMenuItem(
                                  value: null,
                                  child: Text('Whole club')),
                              for (final b
                                  in branchSnap.data ?? <Branch>[])
                                DropdownMenuItem(
                                    value: b.id, child: Text(b.name)),
                            ],
                            onChanged: (v) =>
                                setState(() => _branchId = v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 18),
                        label: Text(
                            '${DateFormat.MMMd().format(_range.start)} – ${DateFormat.MMMd().format(_range.end)}'),
                        onPressed: _pickRange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Money in',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium),
                          const SizedBox(height: 10),
                          _line(
                              'Court & lesson cash (${bookings.where((b) => b.paidAmount != null).length} payments)',
                              bookingCash,
                              money),
                          if (_branchId == null)
                            _line(
                                'Package payments (${topUps.length})',
                                packageCash,
                                money),
                          const Divider(height: 20),
                          _line('Total in', income, money,
                              bold: true, color: Colors.green),
                          const SizedBox(height: 16),
                          Text('Money out',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium),
                          const SizedBox(height: 10),
                          _line('Expenses (${expenses.length})', spent,
                              money,
                              color: Colors.red),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Profit',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              Text(money.format(profit),
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: profit >= 0
                                          ? Colors.green
                                          : Colors.red)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.table_view),
                    label: const Text('Export this report (Excel/CSV)'),
                    onPressed: () =>
                        _exportCsv(bookings, topUps, expenses),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      'Money in counts cash you recorded in the cash box '
                      'plus package payments. Book prices not yet '
                      'collected are not counted until you record them.',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 20),
                  Text('Expenses',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (expenses.isEmpty)
                    Text('No expenses recorded in this period.',
                        style: TextStyle(color: Colors.grey.shade600)),
                  for (final e in expenses)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.receipt_long,
                            color: AppTheme.courtBlue),
                        title: Text(e.description),
                        subtitle: Text(
                            '${e.date} · ${e.branchName.isEmpty ? 'Whole club' : e.branchName}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('− ${money.format(e.amount)}',
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 20),
                              onPressed: () => db.deleteExpense(e.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _line(String label, double value, NumberFormat money,
      {bool bold = false, Color? color}) {
    final style = TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.w500,
        fontSize: bold ? 16 : 14,
        color: color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: style)),
          Text(money.format(value), style: style),
        ],
      ),
    );
  }

  /// The whole report as CSV: every money-in and money-out line in
  /// date order, then TOTAL IN / TOTAL OUT / PROFIT rows.
  Future<void> _exportCsv(
      List<Booking> bookings,
      List<Map<String, dynamic>> topUps,
      List<Expense> expenses) async {
    String esc(String v) =>
        v.contains(RegExp(r'[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
    final rows = <(String date, List<String> cells)>[];
    double totalIn = 0, totalOut = 0;
    for (final b in bookings.where((b) => b.paidAmount != null)) {
      totalIn += b.paidAmount!;
      rows.add((
        b.date,
        [
          'income',
          b.date,
          '${b.isLesson ? 'Lesson' : 'Booking'} cash — ${b.userName} '
              '(${b.courtName} ${formatMinutes(b.startMinutes)})',
          b.branchName,
          b.paidAmount!.toStringAsFixed(2),
          '',
        ]
      ));
    }
    for (final t in topUps) {
      final paid = ((t['paid'] as num?) ?? 0).toDouble();
      totalIn += paid;
      rows.add((
        _topUpDate(t),
        [
          'income',
          _topUpDate(t),
          'Package ${t['packageName'] ?? ''} — ${t['customerName'] ?? ''}',
          '',
          paid.toStringAsFixed(2),
          '',
        ]
      ));
    }
    for (final e in expenses) {
      totalOut += e.amount;
      rows.add((
        e.date,
        [
          'expense',
          e.date,
          e.description,
          e.branchName.isEmpty ? 'Whole club' : e.branchName,
          '',
          e.amount.toStringAsFixed(2),
        ]
      ));
    }
    rows.sort((a, b) => a.$1.compareTo(b.$1));

    final buf =
        StringBuffer('Type,Date,Description,Branch,In USD,Out USD\n');
    for (final (_, cells) in rows) {
      buf.writeln(cells.map(esc).join(','));
    }
    buf.writeln('TOTAL IN,,,,${totalIn.toStringAsFixed(2)},');
    buf.writeln('TOTAL OUT,,,,,${totalOut.toStringAsFixed(2)}');
    buf.writeln(
        'PROFIT,,,,${(totalIn - totalOut).toStringAsFixed(2)},');

    final period = '${dateKey(_range.start)}_${dateKey(_range.end)}';
    final branch = _branchId ?? 'whole-club';
    final dir = await getTemporaryDirectory();
    final file =
        File('${dir.path}/lets-padel-accounting-$period-$branch.csv');
    await file.writeAsString(buf.toString());
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Let\'s Padel accounting $period ($branch)',
    ));
  }

  Future<void> _addExpense(BuildContext context) async {
    final db = context.read<FirestoreService>();
    final description = TextEditingController();
    final amount = TextEditingController();
    var date = DateTime.now();
    String branchId = '';
    String branchName = '';
    final branches = await db.branches().first;
    if (!context.mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState) => AlertDialog(
          title: const Text('Add expense'),
          // Scrollable: when the keyboard opens the dialog gets
          // squeezed, and a fixed column would overflow.
          content: SingleChildScrollView(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: description,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'What was it for?',
                    hintText: 'balls, water…'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Amount', prefixText: '\$ '),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: branchId,
                decoration:
                    const InputDecoration(labelText: 'Branch'),
                items: [
                  const DropdownMenuItem(
                      value: '', child: Text('Whole club')),
                  for (final b in branches)
                    DropdownMenuItem(
                        value: b.id, child: Text(b.name)),
                ],
                onChanged: (v) => setState(() {
                  branchId = v ?? '';
                  branchName = branches
                          .where((b) => b.id == branchId)
                          .firstOrNull
                          ?.name ??
                      '';
                }),
              ),
              const SizedBox(height: 12),
              // Full-width with a shrinking label so a long date at a
              // large font size can never overflow the dialog.
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(DateFormat.yMMMd().format(date))),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx2,
                      initialDate: date,
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => date = picked);
                  },
                ),
              ),
            ],
          )),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx2, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx2, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final value = double.tryParse(amount.text);
    if (description.text.trim().isEmpty || value == null || value <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Expense needs a description and an amount.')));
      }
      return;
    }
    // Fire and forget — the live stream shows it instantly.
    db
        .addExpense(Expense(
          id: '',
          date: dateKey(date),
          branchId: branchId,
          branchName: branchName,
          description: description.text.trim(),
          amount: value,
        ))
        .catchError((_) {});
  }
}
