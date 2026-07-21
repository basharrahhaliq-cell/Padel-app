import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../models/branch.dart';
import '../../models/coach.dart';
import '../../models/court.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../theme.dart';
import '../../utils/time_utils.dart';
import '../../widgets/coach_avatar.dart';

/// Academy: browse coaches and book a session.
class AcademyScreen extends StatelessWidget {
  final AppUser profile;

  const AcademyScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    return StreamBuilder<List<Coach>>(
      stream: db.coaches(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final coaches = snap.data!.where((c) => c.active).toList();
        if (coaches.isEmpty) {
          return const Center(
              child: Text('No coaches available yet — coming soon!'));
        }
        final money = NumberFormat.currency(symbol: '\$');
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
                'Improve your game with a session from one of our coaches.'),
            const SizedBox(height: 12),
            for (final coach in coaches)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  leading: CoachAvatar(coach: coach),
                  title: Text(coach.name,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${coach.bio.isEmpty ? '' : '${coach.bio}\n'}'
                    'From ${money.format(coach.prices.values.isEmpty ? 0 : coach.prices.values.reduce((a, b) => a < b ? a : b))} per session',
                  ),
                  isThreeLine: coach.bio.isNotEmpty,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => LessonBookingScreen(
                              coach: coach, profile: profile))),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Book a session: type -> date -> available time (court auto-assigned).
class LessonBookingScreen extends StatefulWidget {
  final Coach coach;
  final AppUser profile;

  const LessonBookingScreen(
      {super.key, required this.coach, required this.profile});

  @override
  State<LessonBookingScreen> createState() => _LessonBookingScreenState();
}

class _LessonBookingScreenState extends State<LessonBookingScreen> {
  String _sessionType = 'private';
  String? _branchId;
  DateTime _date = DateTime.now();
  bool _booking = false;

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    final money = NumberFormat.currency(symbol: '\$');
    final coach = widget.coach;

    return Scaffold(
      appBar: AppBar(title: Text(coach.name)),
      body: StreamBuilder<List<Branch>>(
        stream: db.branches(),
        builder: (context, branchSnap) {
          final branches = (branchSnap.data ?? [])
              .where((b) =>
                  coach.branchIds.isEmpty ||
                  coach.branchIds.contains(b.id))
              .toList();
          if (branches.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final branch = branches
                  .where((b) => b.id == _branchId)
                  .firstOrNull ??
              branches.first;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (coach.bio.isNotEmpty) ...[
                Text(coach.bio),
                const SizedBox(height: 16),
              ],
              Text('Session type',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: _sessionType,
                onChanged: (v) => setState(() => _sessionType = v!),
                child: Column(
                  children: [
                    for (final entry in kSessionTypes.entries)
                      RadioListTile<String>(
                        value: entry.key,
                        dense: true,
                        title: Text(entry.value),
                        secondary: Text(
                            money.format(coach.priceFor(entry.key)),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.courtBlue)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (branches.length > 1) ...[
                Text('Branch',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final b in branches)
                      ChoiceChip(
                        selected: b.id == branch.id,
                        label: Text(b.name),
                        onSelected: (_) =>
                            setState(() => _branchId = b.id),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Text('Date', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 14,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final today = DateTime.now();
                    final day =
                        DateTime(today.year, today.month, today.day + i);
                    final selected = dateKey(day) == dateKey(_date);
                    return GestureDetector(
                      onTap: () => setState(() => _date = day),
                      child: Container(
                        width: 60,
                        decoration: BoxDecoration(
                          color:
                              selected ? AppTheme.courtBlue : Colors.white,
                          borderRadius: BorderRadius.circular(12),
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
                                    fontSize: 12,
                                    color: selected
                                        ? Colors.white70
                                        : Colors.grey)),
                            Text('${day.day}',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: selected
                                        ? Colors.white
                                        : Colors.black87)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text('Available times (60 min)',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              StreamBuilder<List<Court>>(
                stream: db.courts(branch.id),
                builder: (context, courtSnap) {
                  final courts = courtSnap.data ?? [];
                  return _LessonSlots(
                    // New key (fresh load) only when the selection
                    // actually changes — unrelated screen refreshes
                    // no longer restart the loading.
                    key: ValueKey(
                        '${branch.id}_${dateKey(_date)}_${courts.length}'),
                    coach: coach,
                    branch: branch,
                    courts: courts,
                    date: dateKey(_date),
                    enabled: !_booking,
                    onPick: (court, start) =>
                        _confirm(branch, court, start),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirm(Branch branch, Court court, int start) async {
    final db = context.read<FirestoreService>();
    final notifications = context.read<NotificationService>();
    final coach = widget.coach;
    final money = NumberFormat.currency(symbol: '\$');
    final price = coach.priceFor(_sessionType);

    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm lesson'),
        content: Text(
            '${kSessionTypes[_sessionType]} with ${coach.name}\n'
            '${branch.name} · ${court.name}\n'
            '${DateFormat.MMMEd().format(_date)} · '
            '${formatMinutes(start)} – ${formatMinutes(start + FirestoreService.lessonMinutes)}\n\n'
            'Price: ${money.format(price)} (paid at the club)'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Book lesson')),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() => _booking = true);
    final booking = Booking(
      id: '',
      branchId: branch.id,
      courtId: court.id,
      branchName: branch.name,
      courtName: court.name,
      date: dateKey(_date),
      startMinutes: start,
      durationMinutes: FirestoreService.lessonMinutes,
      userId: widget.profile.uid,
      userName: widget.profile.name,
      userPhone: widget.profile.phone,
      price: price,
      status: BookingStatus.confirmed,
      isLesson: true,
      coachId: coach.id,
      coachName: coach.name,
      sessionType: _sessionType,
    );
    try {
      final id = await db.createLessonBooking(booking);
      await notifications.scheduleGameReminder(
        bookingId: id,
        booking: booking,
        title: 'Your lesson with ${coach.name} is in 2 hours!',
        body: reminderBodyFor(booking),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Lesson booked! Find it under Profile → '
              'My bookings. 🎾')));
      Navigator.of(context).pop();
    } on SlotTakenException {
      if (!mounted) return;
      setState(() => _booking = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('That time was just taken — pick another slot.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _booking = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
    }
  }
}

/// Loads the coach's free times ONCE per selection and keeps the
/// result: parent rebuilds (live streams elsewhere on the screen) no
/// longer restart the loading — the old inline FutureBuilder refetched
/// on every rebuild, which on slow connections looked like an endless
/// spinner. Errors show a Retry button instead of buffering forever.
class _LessonSlots extends StatefulWidget {
  final Coach coach;
  final Branch branch;
  final List<Court> courts;
  final String date;
  final bool enabled;
  final void Function(Court court, int startMinutes) onPick;

  const _LessonSlots({
    super.key,
    required this.coach,
    required this.branch,
    required this.courts,
    required this.date,
    required this.enabled,
    required this.onPick,
  });

  @override
  State<_LessonSlots> createState() => _LessonSlotsState();
}

class _LessonSlotsState extends State<_LessonSlots> {
  late Future<List<(int, Court)>> _future = _load();

  Future<List<(int, Court)>> _load() =>
      context.read<FirestoreService>().lessonSlots(
            coach: widget.coach,
            branch: widget.branch,
            courts: widget.courts,
            date: widget.date,
          );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<(int, Court)>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Could not load the times — check your '
                    'connection.'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  onPressed: () => setState(() => _future = _load()),
                ),
              ],
            ),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final slots = snap.data!;
        if (slots.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No free times this day — the coach '
                'may not work this day or is fully booked. '
                'Try another date.'),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (start, court) in slots)
              ActionChip(
                backgroundColor: Colors.white,
                label: Text(formatMinutes(start)),
                onPressed: widget.enabled
                    ? () => widget.onPick(court, start)
                    : null,
              ),
          ],
        );
      },
    );
  }
}
