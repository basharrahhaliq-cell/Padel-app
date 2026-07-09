import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../models/app_user.dart';
import '../../models/banner_item.dart';
import '../../models/branch.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../theme.dart';
import 'booking_flow_screen.dart';
import 'my_bookings_screen.dart';
import 'open_matches_screen.dart';
import 'profile_screen.dart';
import 'tournaments_screen.dart'
    show TournamentsScreen, TournamentDetailScreen;

class CustomerHome extends StatefulWidget {
  final AppUser profile;

  const CustomerHome({super.key, required this.profile});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Register this device for open-match / tournament pushes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationService>().registerForPush(widget.profile);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_tab) {
          0 => l10n.appTitle,
          1 => 'Open Matches',
          2 => 'Tournaments',
          3 => l10n.myBookingsTab,
          _ => 'Profile',
        }),
        actions: [
          IconButton(
            tooltip: l10n.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthService>().signOut(),
          ),
        ],
      ),
      body: switch (_tab) {
        0 => _BranchPicker(profile: widget.profile),
        1 => OpenMatchesScreen(profile: widget.profile),
        2 => TournamentsScreen(profile: widget.profile),
        3 => MyBookingsScreen(profile: widget.profile),
        _ => ProfileScreen(profile: widget.profile),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.sports_tennis), label: l10n.bookTab),
          const NavigationDestination(
              icon: Icon(Icons.group_add), label: 'Matches'),
          const NavigationDestination(
              icon: Icon(Icons.emoji_events), label: 'Events'),
          NavigationDestination(
              icon: const Icon(Icons.event_note), label: l10n.myBookingsTab),
          const NavigationDestination(
              icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

/// Swipeable promo cards managed by the owner (announcements only).
class _BannerCarousel extends StatelessWidget {
  final AppUser profile;

  const _BannerCarousel({required this.profile});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    return StreamBuilder<List<BannerItem>>(
      stream: db.banners(),
      builder: (context, snap) {
        final banners =
            (snap.data ?? []).where((b) => b.active).toList();
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
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.courtBlue,
                              AppTheme.courtBlueDark
                            ],
                          ),
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

class _BranchPicker extends StatelessWidget {
  final AppUser profile;

  const _BranchPicker({required this.profile});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final db = context.read<FirestoreService>();
    return StreamBuilder<List<Branch>>(
      stream: db.branches(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final branches = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _BannerCarousel(profile: profile),
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
    );
  }
}
