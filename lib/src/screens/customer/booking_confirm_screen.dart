import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../models/branch.dart';
import '../../models/court.dart';
import '../../models/voucher.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../theme.dart';
import '../../utils/slot_engine.dart';
import '../../utils/time_utils.dart' show formatMinutes, parseDateKey, dateKey;

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
  final _voucherField = TextEditingController();
  Voucher? _voucher; // validated voucher, applied to the price
  String? _voucherError;
  bool _useWallet = false;

  double get _finalPrice =>
      _voucher == null ? widget.slot.price : _voucher!.apply(widget.slot.price);

  double get _discount => widget.slot.price - _finalPrice;

  double get _walletAvailable =>
      widget.profile.usableWallet(dateKey(DateTime.now()));

  /// How much of the final price the wallet covers when enabled.
  double get _walletUsed => !_useWallet
      ? 0
      : (_walletAvailable >= _finalPrice ? _finalPrice : _walletAvailable);

  double get _payAtClub => _finalPrice - _walletUsed;

  @override
  void dispose() {
    _voucherField.dispose();
    super.dispose();
  }

  Future<void> _applyVoucher() async {
    final db = context.read<FirestoreService>();
    final code = _voucherField.text.trim().toUpperCase();
    if (code.isEmpty) return;
    final voucher = await db.voucherByCode(code);
    final reason = voucher == null
        ? 'Unknown voucher code.'
        : voucher.rejectionReason(widget.profile.uid, widget.branch.id);
    setState(() {
      _voucher = reason == null ? voucher : null;
      _voucherError = reason;
    });
  }

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
      price: _finalPrice,
      happyHourLabel: widget.slot.happyHour?.label,
      status: BookingStatus.confirmed,
      voucherCode: _voucher?.code,
      voucherDiscount: _discount,
      walletUsed: _walletUsed,
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
    } on VoucherRejectedException catch (e) {
      if (!mounted) return;
      setState(() {
        _voucher = null;
        _voucherError = e.reason;
        _busy = false;
      });
    } on WalletRejectedException {
      if (!mounted) return;
      setState(() {
        _useWallet = false;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Your wallet credit is no longer available — '
              'price is payable at the club.')));
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
      body: ListView(
        padding: const EdgeInsets.all(20),
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
                    // Voucher code
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _voucherField,
                            textCapitalization:
                                TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Voucher code (optional)',
                              isDense: true,
                              errorText: _voucherError,
                            ),
                            onChanged: (_) {
                              if (_voucher != null || _voucherError != null) {
                                setState(() {
                                  _voucher = null;
                                  _voucherError = null;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                            onPressed: _applyVoucher,
                            child: const Text('Apply')),
                      ],
                    ),
                    if (_voucher != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                            '${_voucher!.code} applied — you save '
                            '${money.format(_discount)}',
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600)),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.totalPrice,
                            style:
                                Theme.of(context).textTheme.titleMedium),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_voucher != null)
                              Text(money.format(widget.slot.price),
                                  style: TextStyle(
                                      decoration:
                                          TextDecoration.lineThrough,
                                      color: Colors.grey.shade500)),
                            Text(money.format(_finalPrice),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                        color: AppTheme.courtBlue,
                                        fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    if (_walletAvailable > 0) ...[
                      const SizedBox(height: 4),
                      CheckboxListTile(
                        value: _useWallet,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                            'Use wallet credit '
                            '(${money.format(_walletAvailable)} available)',
                            style: const TextStyle(fontSize: 14)),
                        onChanged: (v) =>
                            setState(() => _useWallet = v ?? false),
                      ),
                      if (_useWallet)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Wallet pays ${money.format(_walletUsed)}'
                            '${_payAtClub > 0 ? ' · ${money.format(_payAtClub)} at the club' : ' — nothing to pay at the club! 🎉'}',
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                    const SizedBox(height: 8),
                    if (!_useWallet || _payAtClub > 0)
                      Text(l10n.payAtClub,
                          style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
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
