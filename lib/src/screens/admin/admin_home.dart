import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'day_grid_screen.dart';
import 'pricing_screen.dart';
import 'revenue_screen.dart';

/// Owner home: Dashboard / Day view / Pricing / Revenue.
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
      PricingScreen(),
      RevenueScreen(),
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
          NavigationDestination(
              icon: const Icon(Icons.attach_money), label: l10n.pricingTab),
          NavigationDestination(
              icon: const Icon(Icons.bar_chart), label: l10n.revenueTab),
        ],
      ),
    );
  }
}
