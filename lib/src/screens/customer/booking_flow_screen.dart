import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../models/app_user.dart';
import '../../models/branch.dart';
import '../../models/court.dart';
import '../../models/happy_hour_rule.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../utils/slot_engine.dart';
import '../../utils/time_utils.dart';
import 'booking_confirm_screen.dart';

/// One screen, four quick choices: court -> date -> duration -> start time.
/// Each start time shows its exact price; happy-hour slots carry a 🎉 tag.
class BookingFlowScreen extends StatefulWidget {
  final Branch branch;
  final AppUser profile;

  const BookingFlowScreen(
      {super.key, required this.branch, required this.profile});

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  Court? _court;
  DateTime _date = DateTime.now();
  int _duration = 90;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final db = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: Text(widget.branch.name)),
      body: StreamBuilder<List<Court>>(
        stream: db.courts(widget.branch.id),
        builder: (context, courtSnap) {
          if (!courtSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final courts = courtSnap.data!;
          final selectedCourt = _court != null
              ? courts.firstWhere((c) => c.id == _court!.id,
                  orElse: () => courts.first)
              : (courts.isNotEmpty ? courts.first : null);

          if (selectedCourt == null) {
            return Center(child: Text(l10n.noSlotsAvailable));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionTitle(context, l10n.chooseCourt),
              _courtPicker(courts, selectedCourt),
              const SizedBox(height: 20),
              _sectionTitle(context, l10n.chooseDate),
              _datePicker(),
              const SizedBox(height: 20),
              _sectionTitle(context, l10n.chooseDuration),
              _durationPicker(l10n),
              const SizedBox(height: 20),
              _sectionTitle(context, l10n.chooseTime),
              _SlotGrid(
                key: ValueKey(
                    '${selectedCourt.id}_${dateKey(_date)}_$_duration'),
                branch: widget.branch,
                court: selectedCourt,
                date: dateKey(_date),
                duration: _duration,
                profile: widget.profile,
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _courtPicker(List<Court> courts, Court selected) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final court in courts)
          ChoiceChip(
            selected: court.id == selected.id,
            selectedColor: AppTheme.courtBlue,
            labelStyle: TextStyle(
                color: court.id == selected.id ? Colors.white : null),
            label: Text(
                '${court.name} · ${court.type == CourtType.outdoor ? l10n.outdoor : l10n.indoor}'),
            onSelected: (_) => setState(() => _court = court),
          ),
      ],
    );
  }

  Widget _datePicker() {
    final today = DateTime.now();
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final day = DateTime(today.year, today.month, today.day + i);
          final selected = dateKey(day) == dateKey(_date);
          return GestureDetector(
            onTap: () => setState(() => _date = day),
            child: Container(
              width: 64,
              decoration: BoxDecoration(
                color: selected ? AppTheme.courtBlue : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: selected
                        ? AppTheme.courtBlue
                        : Colors.blueGrey.shade100),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat.E().format(day),
                      style: TextStyle(
                          fontSize: 13,
                          color: selected ? Colors.white70 : Colors.grey)),
                  Text('${day.day}',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: selected ? Colors.white : Colors.black87)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _durationPicker(dynamic l10n) {
    return SegmentedButton<int>(
      segments: [
        for (final d in ClubHours.gameDurations)
          ButtonSegment(value: d, label: Text(l10n.durationLabel(d))),
      ],
      selected: {_duration},
      onSelectionChanged: (s) => setState(() => _duration = s.first),
    );
  }
}

/// Live grid of available start times for the current selection.
class _SlotGrid extends StatelessWidget {
  final Branch branch;
  final Court court;
  final String date;
  final int duration;
  final AppUser profile;

  const _SlotGrid({
    super.key,
    required this.branch,
    required this.court,
    required this.date,
    required this.duration,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final db = context.read<FirestoreService>();

    return StreamBuilder<List<HappyHourRule>>(
      stream: db.happyHourRules(),
      builder: (context, ruleSnap) {
        return StreamBuilder<List<BusyInterval>>(
          stream: db.busyIntervals(branch.id, court.id, date),
          builder: (context, busySnap) {
            if (!ruleSnap.hasData || !busySnap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final now = DateTime.now();
            final isToday = dateKey(now) == date;
            final slots = SlotEngine.availableSlots(
              court: court,
              durationMinutes: duration,
              date: date,
              busy: busySnap.data!,
              rules: ruleSnap.data!,
              notBefore: isToday ? now.hour * 60 + now.minute : null,
            );

            if (slots.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(l10n.noSlotsAvailable)),
              );
            }

            // Compact equal boxes, three per row; happy-hour slots
            // glow lime with a 🎉 next to the discounted price.
            String price(double v) => v == v.roundToDouble()
                ? '\$${v.round()}'
                : NumberFormat.currency(symbol: '\$').format(v);
            return GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.7,
              children: [
                for (final slot in slots)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BookingConfirmScreen(
                          branch: branch,
                          court: court,
                          date: date,
                          slot: slot,
                          profile: profile,
                        ),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: slot.happyHour != null
                            ? AppTheme.ballLime.withValues(alpha: 0.35)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: slot.happyHour != null
                                ? AppTheme.ballLime
                                : Colors.blueGrey.shade100),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(formatMinutes(slot.startMinutes),
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              slot.happyHour != null
                                  ? '${price(slot.price)} 🎉'
                                  : price(slot.price),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: slot.happyHour != null
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: slot.happyHour != null
                                      ? AppTheme.courtBlueDark
                                      : Colors.grey.shade700),
                            ),
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
    );
  }
}
