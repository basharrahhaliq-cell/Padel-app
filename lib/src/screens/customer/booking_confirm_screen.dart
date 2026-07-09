import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../models/branch.dart';
import '../../models/court.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../theme.dart';
import '../../utils/slot_engine.dart';
import '../../utils/time_utils.dart';

/// Final review: the customer sees the exact price before confirming.
/// Confirming runs the database transaction and schedules the 2h reminder.
class BookingConfirmScreen extends StatefulWidget {
  final Branch branch;
  final Court court;
  final String date;
  final SlotOption slot;
  final AppUser profile;

  const BookingConfirmScreen({
    super.key,
    required this.branch,
    required this.court,
    required this.date,
    required this.slot,
    required this.profile,
  });

  @override
  State<BookingConfirmScreen> createState() => _BookingConfirmScreenState();
}

class _BookingConfirmScreenState extends State<BookingConfirmScreen> {
  bool _busy = false;

  Future<void> _confirm() async {
    final l10n = context.l10n;
    final db = context.read<FirestoreService>();
    final notifications = context.read<NotificationService>();

    setState(() => _busy = true);
    final booking = Booking(
      id: '',
      branchId: widget.branch.id,
      courtId: widget.court.id,
      branchName: widget.branch.name,
      courtName: widget.court.name,
      date: widget.date,
      startMinutes: widget.slot.startMinutes,
      durationMinutes: widget.slot.durationMinutes,
      userId: widget.profile.uid,
      userName: widget.profile.name,
      userPhone: widget.profile.phone,
      price: widget.slot.price,
      happyHourLabel: widget.slot.happyHour?.label,
      status: BookingStatus.confirmed,
    );

    try {
      final id = await db.createBooking(booking);
      await notifications.scheduleGameReminder(
        bookingId: id,
        booking: booking,
        title: l10n.reminderTitle,
        body: reminderBodyFor(booking),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${l10n.bookingConfirmed} ${l10n.reminderScheduled}')),
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on SlotTakenException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.slotTaken)));
      Navigator.of(context).pop(); // back to the slot list (it's live)
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.genericError(e.toString()))));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final money = NumberFormat.currency(symbol: '\$');
    final date = parseDateKey(widget.date);
    final endMinutes = widget.slot.startMinutes + widget.slot.durationMinutes;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.confirmBookingTitle)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.bookingSummary,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    _row(Icons.location_on, widget.branch.name),
                    _row(
                        Icons.sports_tennis,
                        '${widget.court.name} · ${widget.court.type == CourtType.outdoor ? l10n.outdoor : l10n.indoor}'),
                    _row(Icons.calendar_today,
                        DateFormat.yMMMMEEEEd().format(date)),
                    _row(Icons.schedule,
                        '${formatMinutes(widget.slot.startMinutes)} – ${formatMinutes(endMinutes)} (${l10n.durationLabel(widget.slot.durationMinutes)})'),
                    if (widget.slot.happyHour != null)
                      _row(Icons.celebration,
                          '${l10n.happyHourTag} — ${widget.slot.happyHour!.label}',
                          color: AppTheme.courtBlueDark),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.totalPrice,
                            style:
                                Theme.of(context).textTheme.titleMedium),
                        Text(money.format(widget.slot.price),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                    color: AppTheme.courtBlue,
                                    fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.payAtClub,
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _busy ? null : _confirm,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.confirmButton),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text, {Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(color: color))),
          ],
        ),
      );
}
