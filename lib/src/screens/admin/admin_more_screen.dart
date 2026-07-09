import 'package:flutter/material.dart';

import '../../theme.dart';
import 'customers_screen.dart';
import 'pricing_screen.dart';
import 'revenue_screen.dart';

/// Owner "More" menu: everything that isn't day-to-day reservations.
class AdminMoreScreen extends StatelessWidget {
  const AdminMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, Widget Function())>[
      (Icons.attach_money, 'Pricing & happy hours', () => const _Page(
          title: 'Pricing', child: PricingScreen())),
      (Icons.bar_chart, 'Revenue', () =>
          const _Page(title: 'Revenue', child: RevenueScreen())),
      (Icons.people, 'Customers', () => const CustomersScreen()),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final (icon, title, builder) in items)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Icon(icon, color: AppTheme.courtBlue),
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => builder())),
            ),
          ),
      ],
    );
  }
}

class _Page extends StatelessWidget {
  final String title;
  final Widget child;

  const _Page({required this.title, required this.child});

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text(title)), body: child);
}
