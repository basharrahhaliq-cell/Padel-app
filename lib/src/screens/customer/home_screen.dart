import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../models/app_user.dart';
import '../../models/banner_item.dart';
import '../../models/booking.dart';
import '../../models/branch.dart';
import '../../models/package_offer.dart';
import '../../models/tournament.dart';
import '../../services/firestore_service.dart';
import '../../services/tournament_service.dart';
import '../../theme.dart';
import '../../utils/time_utils.dart';
import '../../utils/xp.dart';
import 'booking_flow_screen.dart';
import 'packages_list_screen.dart';
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
        _XpBar(profile: profile),
        const SizedBox(height: 12),
        _WalletChip(profile: profile),
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
        _PackagesStrip(profile: profile),
        _TournamentsStrip(profile: profile, onShowAll: () => onGoToTab(2)),
      ],
    );
  }
}

/// XP level bar, Padel-IQ style: level star → progress → next level.
class _XpBar extends StatelessWidget {
  final AppUser profile;

  const _XpBar({required this.profile});

  @override
  Widget build(BuildContext context) {
    final level = XpSystem.levelFor(profile.xp);
    final progress = XpSystem.progress(profile.xp);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.courtBlueDark,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.ballLime,
                child: Text('$level',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.courtBlueDark)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    color: AppTheme.ballLime,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.ballLime, width: 2),
                ),
                child: Text('${level + 1}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Play more to increase your level',
              style: TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}

/// Wallet balance at a glance (hidden when empty/expired); tapping it
/// opens the packages screen.
class _WalletChip extends StatelessWidget {
  final AppUser profile;

  const _WalletChip({required this.profile});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final wallet = profile.usableWallet(dateKey(DateTime.now()));
    if (wallet <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PackagesListScreen(profile: profile))),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.courtBlueDark,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet,
                  color: AppTheme.ballLime),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Wallet · valid until ${profile.walletExpiry}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
              ),
              Text(money.format(wallet),
                  style: const TextStyle(
                      color: AppTheme.ballLime,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The club's prepaid packages, shown as pricing boxes right on Home.
/// Live from the database — the owner edits them in Packages & Wallet.
class _PackagesStrip extends StatelessWidget {
  final AppUser profile;

  const _PackagesStrip({required this.profile});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return StreamBuilder<List<PackageOffer>>(
      stream: db.packages(),
      builder: (context, snap) {
        final packages =
            (snap.data ?? []).where((p) => p.active).toList();
        if (packages.isEmpty) return const SizedBox.shrink();
        void openPackages() => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => PackagesListScreen(profile: profile)));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Packages',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                TextButton(
                    onPressed: openPackages, child: const Text('See all')),
              ],
            ),
            if (packages.length <= 3)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, p) in packages.indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: openPackages,
                        child: PackageBox(
                          package: p,
                          money: money,
                          highlighted:
                              packages.length == 3 ? i == 1 : i == 0,
                        ),
                      ),
                    ),
                  ],
                ],
              )
            else
              SizedBox(
                height: 210,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: packages.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => SizedBox(
                    width: 150,
                    child: InkWell(
                      onTap: openPackages,
                      child: PackageBox(
                          package: packages[i],
                          money: money,
                          highlighted: false),
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

/// The customer's upcoming bookings — every one of them, as compact
/// rows in a single card (not just the next game).
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
        final upcoming = (snap.data ?? [])
            .where((b) => b
                .startDateTime
                .add(Duration(minutes: b.durationMinutes))
                .isAfter(now))
            .toList();
        // Padel-IQ style empty state: turn "no game" into a call to action.
        if (upcoming.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text("You don't have a match yet — book it now!",
                      style: TextStyle(
                          fontSize: 15, color: Colors.grey.shade700)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.ballLime,
                      foregroundColor: AppTheme.courtBlueDark,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Book Match'),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                BranchPickerScreen(profile: profile))),
                  ),
                ],
              ),
            ),
          );
        }
        return Card(
          color: AppTheme.courtBlueDark,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  upcoming.length == 1
                      ? 'Your next game'
                      : 'Your upcoming games (${upcoming.length})',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                for (final b in upcoming)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Icon(b.isLesson ? Icons.school : Icons.schedule,
                            color: AppTheme.ballLime, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${DateFormat.MMMEd().format(parseDateKey(b.date))} · '
                            '${formatMinutes(b.startMinutes)}'
                            '${b.isLesson ? ' · lesson with ${b.coachName}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${b.branchName == 'Airport Road' ? 'Airport' : b.branchName} · ${b.courtName}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
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

/// Horizontal scroller of upcoming tournaments, Padel-IQ style.
class _TournamentsStrip extends StatelessWidget {
  final AppUser profile;
  final VoidCallback onShowAll;

  const _TournamentsStrip({required this.profile, required this.onShowAll});

  @override
  Widget build(BuildContext context) {
    final service = context.read<TournamentService>();
    return StreamBuilder<List<Tournament>>(
      stream: service.tournaments(),
      builder: (context, snap) {
        final upcoming =
            (snap.data ?? []).where((t) => !t.isPast).toList();
        if (upcoming.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tournaments',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                TextButton(
                    onPressed: onShowAll, child: const Text('Show all')),
              ],
            ),
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final t in upcoming)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => TournamentDetailScreen(
                                    tournamentId: t.id,
                                    profile: profile))),
                        child: Container(
                          width: 230,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.courtBlueDark,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.emoji_events,
                                      color: AppTheme.ballLime, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(t.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                '${t.branchName} · Level ${t.level}\n'
                                '${t.dates.isEmpty ? '' : DateFormat.MMMEd().format(parseDateKey(t.dates.first))} · '
                                '${t.format == TournamentFormat.knockout ? 'Knockout' : 'Americano'}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
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
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Full-bleed photo background when provided.
                            if (b.imageUrl.isNotEmpty)
                              Image.network(
                                b.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            if (b.imageUrl.isNotEmpty)
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.black87,
                                      Colors.transparent
                                    ],
                                  ),
                                ),
                              ),
                            Padding(
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
