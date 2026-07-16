import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: description,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'What was it for?',
                    hintText: 'e.g. balls, water, electricity'),
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
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(DateFormat.yMMMd().format(date)),
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
            ],
          ),
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
