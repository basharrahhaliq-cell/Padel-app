import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import 'admin_more_screen.dart';
import 'dashboard_screen.dart';
import 'day_grid_screen.dart';

/// Owner home: Dashboard / Day view / More (pricing, revenue, customers…).
class AdminHome extends StatefulWidget {
  final AppUser profile;

  const AdminHome({super.key, required this.profile});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = const [
      DashboardScreen(),
      DayGridScreen(),
      AdminMoreScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.appTitle} — ${l10n.adminTitle}'),
        actions: [
          IconButton(
            tooltip: l10n.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthService>().signOut(),
          ),
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.list_alt), label: l10n.dashboardTab),
          NavigationDestination(
              icon: const Icon(Icons.grid_view), label: l10n.dayGridTab),
          const NavigationDestination(
              icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}
