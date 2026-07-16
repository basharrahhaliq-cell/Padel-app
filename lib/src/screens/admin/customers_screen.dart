import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../theme.dart';
import '../../utils/csv_export.dart';

/// Owner view of all registered customers with booking stats,
/// sortable by activity, exportable as CSV.
class CustomersScreen extends StatefulWidget {
  /// Injectable for tests; defaults to the live database.
  final FirebaseFirestore? firestore;

  const CustomersScreen({super.key, this.firestore});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

enum _Sort { mostActive, name, lastBooking }

class _CustomerRow {
  final AppUser user;
  int totalBookings = 0;
  String lastBookingDate = '';
  final Map<String, int> branchCounts = {};

  _CustomerRow(this.user);

  String get preferredBranch {
    if (branchCounts.isEmpty) return '—';
    final sorted = branchCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }
}

class _CustomersScreenState extends State<CustomersScreen> {
  _Sort _sort = _Sort.mostActive;
  late Future<List<_CustomerRow>> _future = _load();

  Future<List<_CustomerRow>> _load() async {
    final db = widget.firestore ?? FirebaseFirestore.instance;
    final usersSnap = await db.collection('users').get();
    final bookingsSnap = await db
        .collection('bookings')
        .where('status', isEqualTo: 'confirmed')
        .get();

    final rows = <String, _CustomerRow>{
      for (final doc in usersSnap.docs)
        doc.id: _CustomerRow(AppUser.fromDoc(doc)),
    };
    for (final doc in bookingsSnap.docs) {
      final b = Booking.fromDoc(doc);
      if (b.isBlock) continue;
      final row = rows[b.userId];
      if (row == null) continue;
      row.totalBookings++;
      if (b.date.compareTo(row.lastBookingDate) > 0) {
        row.lastBookingDate = b.date;
      }
      row.branchCounts[b.branchName] =
          (row.branchCounts[b.branchName] ?? 0) + 1;
    }
    return rows.values.toList();
  }

  List<_CustomerRow> _sorted(List<_CustomerRow> rows) {
    final list = [...rows];
    switch (_sort) {
      case _Sort.mostActive:
        list.sort((a, b) => b.totalBookings.compareTo(a.totalBookings));
      case _Sort.name:
        list.sort((a, b) =>
            a.user.name.toLowerCase().compareTo(b.user.name.toLowerCase()));
      case _Sort.lastBooking:
        list.sort((a, b) => b.lastBookingDate.compareTo(a.lastBookingDate));
    }
    return list;
  }

  /// Promote a customer to admin or demote an admin back to customer.
  Future<void> _toggleAdmin(AppUser user) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (user.uid == myUid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("You can't remove your own admin access.")));
      return;
    }
    final promote = !user.isAdmin;
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(promote ? 'Make admin?' : 'Remove admin access?'),
        content: Text(promote
            ? '${user.name} will get the FULL owner dashboard: bookings, '
                'prices, vouchers, wallets, revenue — everything.'
            : '${user.name} will become a normal customer again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(promote ? 'Make admin' : 'Remove')),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await (widget.firestore ?? FirebaseFirestore.instance)
        .collection('users')
        .doc(user.uid)
        .update({'role': promote ? 'admin' : 'customer'});
    if (!mounted) return;
    setState(() => _future = _load());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(promote
            ? '${user.name} is now an admin ✅ (they must restart the app)'
            : '${user.name} is a customer again.')));
  }

  String _csvEscape(String v) =>
      v.contains(RegExp(r'[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;

  Future<void> _exportCsv(List<_CustomerRow> rows) async {
    final buf = StringBuffer(
        'Name,Phone,Email,Level,Marketing consent,Total bookings,'
        'Last booking,Preferred branch\n');
    for (final r in _sorted(rows).where((r) => !r.user.isAdmin)) {
      buf.writeln([
        r.user.name,
        r.user.phone,
        r.user.email,
        r.user.skillLevel,
        r.user.marketingConsent ? 'yes' : 'no',
        '${r.totalBookings}',
        r.lastBookingDate.isEmpty ? '-' : r.lastBookingDate,
        r.preferredBranch,
      ].map(_csvEscape).join(','));
    }
    final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await shareCsv(
      filename: 'lets-padel-customers-$stamp.csv',
      content: buf.toString(),
      subject: 'Let\'s Padel customers $stamp',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: FutureBuilder<List<_CustomerRow>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load customers:\n${snap.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = _sorted(snap.data!);
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<_Sort>(
                        initialValue: _sort,
                        isDense: true,
                        decoration: const InputDecoration(
                            labelText: 'Sort by',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8)),
                        items: const [
                          DropdownMenuItem(
                              value: _Sort.mostActive,
                              child: Text('Most active')),
                          DropdownMenuItem(
                              value: _Sort.name, child: Text('Name')),
                          DropdownMenuItem(
                              value: _Sort.lastBooking,
                              child: Text('Last booking')),
                        ],
                        onChanged: (v) => setState(() => _sort = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('CSV'),
                      onPressed:
                          rows.isEmpty ? null : () => _exportCsv(rows),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${rows.length} customers',
                    style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                for (final r in rows)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: r.user.isAdmin
                            ? AppTheme.courtBlueDark
                            : AppTheme.ballLime,
                        child: r.user.isAdmin
                            ? const Icon(Icons.shield,
                                color: AppTheme.ballLime, size: 18)
                            : Text(
                                r.user.skillLevel.isEmpty
                                    ? '?'
                                    : r.user.skillLevel,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.courtBlueDark),
                              ),
                      ),
                      title: Text(
                          '${r.user.name.isEmpty ? '(no name)' : r.user.name}'
                          '${r.user.isAdmin ? '  ·  ADMIN' : ''}'),
                      subtitle: Text(
                        '${r.user.phone} · ${r.user.email}\n'
                        '${r.totalBookings} bookings'
                        '${r.lastBookingDate.isEmpty ? '' : ' · last ${r.lastBookingDate}'}'
                        ' · prefers ${r.preferredBranch}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (_) => _toggleAdmin(r.user),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(r.user.isAdmin
                                ? 'Remove admin access'
                                : 'Make admin'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
