import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../models/booking.dart';
import '../../models/branch.dart';
import '../../models/court.dart';
import '../../models/open_match.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../utils/time_utils.dart';
import 'block_time_sheet.dart';

/// All reservations for a chosen date, filterable by branch and court.
/// The owner can cancel any booking and block time ranges from here.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _date = DateTime.now();
  String? _branchId; // null = all
  String? _courtId; // null = all

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _cancelAsAdmin(Booking booking) async {
    final l10n = context.l10n;
    final db = context.read<FirestoreService>();
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminCancelConfirm),
        content: Text(
            '${booking.userName} — ${formatMinutes(booking.startMinutes)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.keepBooking)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.yesCancel)),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await db.cancelBooking(booking, enforceCutoff: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.bookingCancelled)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final db = context.read<FirestoreService>();
    final money = NumberFormat.currency(symbol: '\$');

    return Column(
      children: [
        _filters(l10n, db),
        Expanded(
          child: StreamBuilder<List<OpenMatch>>(
            stream: db.openMatchesOn(dateKey(_date)),
            builder: (context, matchSnap) {
              final matchByBooking = {
                for (final m in matchSnap.data ?? <OpenMatch>[])
                  m.bookingId: m,
              };
              return StreamBuilder<List<Booking>>(
            stream: db.bookingsOn(dateKey(_date), branchId: _branchId),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var bookings = snap.data!;
              if (_courtId != null) {
                bookings =
                    bookings.where((b) => b.courtId == _courtId).toList();
              }
              if (bookings.isEmpty) {
                return Center(child: Text(l10n.noBookingsYet));
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(l10n.bookingsCount(bookings.length),
                      style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  for (final b in bookings)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: b.isBlock
                              ? Colors.grey.shade300
                              : AppTheme.ballLime,
                          child: Icon(
                              b.isBlock ? Icons.block : Icons.person,
                              color: AppTheme.courtBlueDark,
                              size: 20),
                        ),
                        title: Text(b.isBlock
                            ? '${l10n.blockedLabel} — ${b.note ?? ''}'
                            : b.isLesson
                                ? '${b.userName} · LESSON with ${b.coachName}'
                                : b.isOpenMatch
                                    ? '${b.userName}  ·  OPEN MATCH'
                                    : b.userName),
                        subtitle: Text(
                          '${b.branchName} · ${b.courtName}\n'
                          '${formatMinutes(b.startMinutes)} – ${formatMinutes(b.endMinutes)}'
                          '${b.isBlock ? '' : ' · ${b.userPhone}'}'
                          '${b.voucherCode != null ? ' · ${b.voucherCode}' : ''}'
                          '${matchByBooking.containsKey(b.id) ? '\nPlayers: ${matchByBooking[b.id]!.allPlayerNames.join(', ')}' : ''}',
                        ),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!b.isBlock)
                              Text(money.format(b.price),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.courtBlue)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent, size: 20),
                              onPressed: () => _cancelAsAdmin(b),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          );
            },
          ),
        ),
      ],
    );
  }

  Widget _filters(dynamic l10n, FirestoreService db) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: StreamBuilder<List<Branch>>(
          stream: db.branches(),
          builder: (context, branchSnap) {
            final branches = branchSnap.data ?? [];
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(DateFormat.yMMMEd().format(_date)),
                        onPressed: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: l10n.blockTime,
                      icon: const Icon(Icons.block),
                      onPressed: branches.isEmpty
                          ? null
                          : () => showBlockTimeSheet(
                              context, branches, _date),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        isExpanded: true,
                        initialValue: _branchId,
                        isDense: true,
                        decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8)),
                        items: [
                          DropdownMenuItem(
                              value: null, child: Text(l10n.allBranches)),
                          for (final b in branches)
                            DropdownMenuItem(
                                value: b.id, child: Text(b.name)),
                        ],
                        onChanged: (v) => setState(() {
                          _branchId = v;
                          _courtId = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _branchId == null
                          ? DropdownButtonFormField<String?>(
                              isExpanded: true,
                              initialValue: null,
                              isDense: true,
                              decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8)),
                              items: [
                                DropdownMenuItem(
                                    value: null,
                                    child: Text(l10n.allCourts)),
                              ],
                              onChanged: null,
                            )
                          : StreamBuilder<List<Court>>(
                              stream: db.courts(_branchId!),
                              builder: (context, courtSnap) {
                                final courts = courtSnap.data ?? [];
                                return DropdownButtonFormField<String?>(
                                  isExpanded: true,
                                  initialValue: _courtId,
                                  isDense: true,
                                  decoration: const InputDecoration(
                                      contentPadding:
                                          EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8)),
                                  items: [
                                    DropdownMenuItem(
                                        value: null,
                                        child: Text(l10n.allCourts)),
                                    for (final c in courts)
                                      DropdownMenuItem(
                                          value: c.id,
                                          child: Text(c.name)),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _courtId = v),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
