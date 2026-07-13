import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../models/booking.dart';
import '../../models/branch.dart';
import '../../models/court.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../utils/time_utils.dart';

const double _kSlotWidth = 44; // pixels per 30-minute column
const double _kRowHeight = 56;
const double _kLabelWidth = 92;

/// Timeline grid: one row per court, one column per 30 minutes
/// (8 AM – 11 PM). Booked ranges are solid bars, gaps are obvious.
class DayGridScreen extends StatefulWidget {
  const DayGridScreen({super.key});

  @override
  State<DayGridScreen> createState() => _DayGridScreenState();
}

class _DayGridScreenState extends State<DayGridScreen> {
  DateTime _date = DateTime.now();
  String? _branchId;

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
    final db = context.read<FirestoreService>();

    return StreamBuilder<List<Branch>>(
      stream: db.branches(),
      builder: (context, branchSnap) {
        final branches = branchSnap.data ?? [];
        if (branches.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final branchId = _branchId ?? branches.first.id;
        final branch = branches.firstWhere((b) => b.id == branchId,
            orElse: () => branches.first);

        return Column(
          children: [
            Material(
              color: Colors.white,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: branch.id,
                        isDense: true,
                        decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8)),
                        items: [
                          for (final b in branches)
                            DropdownMenuItem(
                                value: b.id, child: Text(b.name)),
                        ],
                        onChanged: (v) => setState(() => _branchId = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(DateFormat.MMMEd().format(_date)),
                      onPressed: _pickDate,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Court>>(
                stream: db.courts(branch.id),
                builder: (context, courtSnap) {
                  final courts = courtSnap.data ?? [];
                  return StreamBuilder<List<Booking>>(
                    stream:
                        db.bookingsOn(dateKey(_date), branchId: branch.id),
                    builder: (context, bookingSnap) {
                      final bookings = bookingSnap.data ?? [];
                      return _grid(l10n, courts, bookings);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _grid(dynamic l10n, List<Court> courts, List<Booking> bookings) {
    final totalSlots =
        (ClubHours.closeMinutes - ClubHours.openMinutes) ~/
            ClubHours.slotStepMinutes;
    final gridWidth = totalSlots * _kSlotWidth;

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: _kLabelWidth + gridWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hour labels
              Row(
                children: [
                  const SizedBox(width: _kLabelWidth),
                  for (int slot = 0; slot < totalSlots; slot++)
                    SizedBox(
                      width: _kSlotWidth,
                      child: slot.isEven
                          ? Text(
                              formatMinutes(ClubHours.openMinutes +
                                  slot * ClubHours.slotStepMinutes),
                              style: const TextStyle(fontSize: 10),
                            )
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              for (final court in courts)
                _courtRow(l10n, court, bookings, totalSlots),
            ],
          ),
        ),
      ),
    );
  }

  Widget _courtRow(
      dynamic l10n, Court court, List<Booking> bookings, int totalSlots) {
    final courtBookings =
        bookings.where((b) => b.courtId == court.id).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: _kLabelWidth,
            child: Text(
              '${court.name}\n${court.type == CourtType.outdoor ? l10n.outdoor : l10n.indoor}',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            height: _kRowHeight,
            width: totalSlots * _kSlotWidth,
            child: Stack(
              children: [
                // background slot cells
                Row(
                  children: [
                    for (int i = 0; i < totalSlots; i++)
                      Container(
                        width: _kSlotWidth,
                        height: _kRowHeight,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                              color: Colors.blueGrey.shade50, width: 0.5),
                        ),
                      ),
                  ],
                ),
                // booking bars
                for (final b in courtBookings)
                  Positioned(
                    left: (b.startMinutes - ClubHours.openMinutes) /
                        ClubHours.slotStepMinutes *
                        _kSlotWidth,
                    width: b.durationMinutes /
                        ClubHours.slotStepMinutes *
                        _kSlotWidth,
                    top: 4,
                    height: _kRowHeight - 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: b.isBlock
                            ? Colors.grey.shade400
                            : AppTheme.courtBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        b.isBlock
                            ? '${l10n.blockedLabel}\n${b.note ?? ''}'
                            : '${b.userName}\n${formatMinutes(b.startMinutes)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
