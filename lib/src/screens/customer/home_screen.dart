import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../models/app_user.dart';
import '../../models/banner_item.dart';
import '../../models/booking.dart';
import '../../models/branch.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../utils/time_utils.dart';
import 'booking_flow_screen.dart';
import 'tournaments_screen.dart' show TournamentDetailScreen;

/// Customer landing page: greeting, promo banners, next game, and big
/// shortcuts to everything the club offers.
class HomeScreen extends StatelessWidget {
  final AppUser profile;

  /// Switches the bottom navigation to the given tab index.
  final void Function(int tab) onGoToTab;

  const HomeScreen(
      {super.key, required this.profile, required this.onGoToTab});

  @override
  Widget build(BuildContext context) {
    final firstName = profile.name.trim().split(' ').first;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Ahla $firstName! 👋',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text('Ready for your next game?',
            style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        BannerCarousel(profile: profile),
        _NextGameCard(profile: profile),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            _ActionCard(
              icon: Icons.sports_tennis,
              title: 'Book a Court',
              subtitle: 'Airport Road · Hazmieh',
              color: AppTheme.courtBlue,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BranchPickerScreen(profile: profile))),
            ),
            _ActionCard(
              icon: Icons.group_add,
              title: 'Open Matches',
              subtitle: 'Find players at your level',
              color: const Color(0xFF199473),
              onTap: () => onGoToTab(1),
            ),
            _ActionCard(
              icon: Icons.emoji_events,
              title: 'Tournaments',
              subtitle: 'Americano & Knockout',
              color: const Color(0xFFCC8A00),
              onTap: () => onGoToTab(2),
            ),
            _ActionCard(
              icon: Icons.school,
              title: 'Academy',
              subtitle: 'Train with our coaches',
              color: const Color(0xFF7B4FBF),
              onTap: () => onGoToTab(3),
            ),
          ],
        ),
      ],
    );
  }
}

/// The customer's next upcoming booking, or nothing if they have none.
class _NextGameCard extends StatelessWidget {
  final AppUser profile;

  const _NextGameCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    return StreamBuilder<List<Booking>>(
      stream: db.myBookings(profile.uid),
      builder: (context, snap) {
        final now = DateTime.now();
        final next = (snap.data ?? [])
            .where((b) => b
                .startDateTime
                .add(Duration(minutes: b.durationMinutes))
                .isAfter(now))
            .firstOrNull;
        if (next == null) return const SizedBox.shrink();
        return Card(
          color: AppTheme.courtBlueDark,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            leading: const Icon(Icons.schedule,
                color: AppTheme.ballLime, size: 32),
            title: Text(
              next.isLesson
                  ? 'Next lesson with ${next.coachName}'
                  : 'Your next game',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13),
            ),
            subtitle: Text(
              '${DateFormat.MMMEd().format(parseDateKey(next.date))} · '
              '${formatMinutes(next.startMinutes)}\n'
              '${next.branchName} · ${next.courtName}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(subtitle,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Swipeable promo cards managed by the owner (announcements only).
class BannerCarousel extends StatelessWidget {
  final AppUser profile;

  const BannerCarousel({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    return StreamBuilder<List<BannerItem>>(
      stream: db.banners(),
      builder: (context, snap) {
        final banners = (snap.data ?? []).where((b) => b.active).toList();
        if (banners.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SizedBox(
            height: 130,
            child: PageView(
              controller: PageController(viewportFraction: 0.94),
              children: [
                for (final b in banners)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: b.tournamentId.isEmpty
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => TournamentDetailScreen(
                                      tournamentId: b.tournamentId,
                                      profile: profile))),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            AppTheme.courtBlue,
                            AppTheme.courtBlueDark
                          ]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text(b.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    Text(b.text,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13)),
                                    if (b.tournamentId.isNotEmpty)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 6),
                                        child: Text('Tap to view →',
                                            style: TextStyle(
                                                color: AppTheme.ballLime,
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.w600)),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (b.imageUrl.isNotEmpty)
                              Image.network(
                                b.imageUrl,
                                width: 110,
                                height: 130,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// "Book a Court": branch list, pushed from the Home screen.
class BranchPickerScreen extends StatelessWidget {
  final AppUser profile;

  const BranchPickerScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final db = context.read<FirestoreService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Book a Court')),
      body: StreamBuilder<List<Branch>>(
        stream: db.branches(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final branches = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.chooseBranch,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final branch in branches)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.ballLime,
                      child: Icon(Icons.location_on,
                          color: AppTheme.courtBlueDark),
                    ),
                    title: Text(branch.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BookingFlowScreen(
                            branch: branch, profile: profile),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
