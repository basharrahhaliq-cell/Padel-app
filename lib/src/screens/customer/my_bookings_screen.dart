import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../theme.dart';
import '../../utils/time_utils.dart';

/// Upcoming and past bookings, with cancellation (up to 3h before start).
class MyBookingsScreen extends StatelessWidget {
  final AppUser profile;

  const MyBookingsScreen({super.key, required this.profile});

  Future<void> _cancel(BuildContext context, Booking booking) async {
    final l10n = context.l10n;
    final db = context.read<FirestoreService>();
    final notifications = context.read<NotificationService>();

    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancelConfirmTitle),
        content: Text(l10n.cancelConfirmBody),
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
    if (sure != true || !context.mounted) return;

    try {
      await db.cancelBooking(booking);
      await notifications.cancelGameReminder(booking.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.bookingCancelled)));
    } on TooLateToCancelException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.cancelTooLate)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.genericError(e.toString()))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final db = context.read<FirestoreService>();
    final money = NumberFormat.currency(symbol: '\$');

    return StreamBuilder<List<Booking>>(
      stream: db.myBookings(profile.uid),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final now = DateTime.now();
        final upcoming = snap.data!
            .where((b) =>
                b.startDateTime.add(Duration(minutes: b.durationMinutes))
                    .isAfter(now))
            .toList();
        final past = snap.data!
            .where((b) =>
                !b.startDateTime.add(Duration(minutes: b.durationMinutes))
                    .isAfter(now))
            .toList()
            .reversed
            .toList();

        if (upcoming.isEmpty && past.isEmpty) {
          return Center(child: Text(l10n.noBookingsYet));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (upcoming.isNotEmpty) ...[
              Text(l10n.upcoming,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final b in upcoming)
                _BookingCard(
                  booking: b,
                  money: money,
                  onCancel: () => _cancel(context, b),
                ),
              const SizedBox(height: 16),
            ],
            if (past.isNotEmpty) ...[
              Text(l10n.past, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final b in past)
                _BookingCard(booking: b, money: money, onCancel: null),
            ],
          ],
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final NumberFormat money;
  final VoidCallback? onCancel;

  const _BookingCard(
      {required this.booking, required this.money, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final date = parseDateKey(booking.date);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${booking.branchName} · ${booking.courtName}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(money.format(booking.price),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.courtBlue)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${DateFormat.MMMEd().format(date)} · '
              '${formatMinutes(booking.startMinutes)} – ${formatMinutes(booking.endMinutes)}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (booking.happyHourLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${l10n.happyHourTag} ${booking.happyHourLabel}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.courtBlueDark)),
              ),
            if (booking.isOpenMatch)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Open Match — players can join from the '
                    'Matches tab',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.courtBlueDark)),
              ),
            if (onCancel != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onCancel,
                  child: Text(l10n.cancelBooking,
                      style: const TextStyle(color: Colors.redAccent)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
