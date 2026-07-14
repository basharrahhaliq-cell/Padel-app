import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import 'academy_screen.dart';
import 'home_screen.dart';
import 'open_matches_screen.dart';
import 'profile_screen.dart';
import 'tournaments_screen.dart' show TournamentsScreen;

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
          3 => 'Academy',
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
        0 => HomeScreen(
            profile: widget.profile,
            onGoToTab: (tab) => setState(() => _tab = tab),
          ),
        1 => OpenMatchesScreen(profile: widget.profile),
        2 => TournamentsScreen(profile: widget.profile),
        3 => AcademyScreen(profile: widget.profile),
        _ => ProfileScreen(profile: widget.profile),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.group_add), label: 'Matches'),
          NavigationDestination(
              icon: Icon(Icons.emoji_events), label: 'Events'),
          NavigationDestination(icon: Icon(Icons.school), label: 'Academy'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
