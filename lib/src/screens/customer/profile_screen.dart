import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';
import '../../utils/validators.dart';
import '../../utils/xp.dart';
import '../auth/login_screen.dart' show levelName;
import '../contact_us_screen.dart';
import '../privacy_policy_screen.dart';
import 'my_bookings_screen.dart';
import 'packages_list_screen.dart';
import 'vouchers_list_screen.dart';

/// Customer profile: personal details, padel level, XP progress,
/// notification/marketing preferences, and app links.
class ProfileScreen extends StatelessWidget {
  final AppUser profile;

  const ProfileScreen({super.key, required this.profile});

  Future<void> _editDetails(BuildContext context) async {
    final auth = context.read<AuthService>();
    final name = TextEditingController(text: profile.name);
    final phone = TextEditingController(text: profile.phone);
    String level = profile.skillLevel.isEmpty ? 'D' : profile.skillLevel;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: StatefulBuilder(
          builder: (ctx2, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 12),
              TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Phone number')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: level,
                decoration:
                    const InputDecoration(labelText: 'Your padel level'),
                items: [
                  for (final lvl in kSkillLevels)
                    DropdownMenuItem(
                        value: lvl,
                        child: Text(levelName(ctx2.l10n, lvl))),
                ],
                onChanged: (v) => setState(() => level = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (saved != true || !context.mounted) return;
    final normalized = LebanesePhone.normalize(phone.text);
    if (normalized == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.invalidPhone)));
      return;
    }
    await auth.updateProfile(profile.uid, {
      'name': name.text.trim(),
      'phone': normalized,
      'skillLevel': level,
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              radius: 26,
              backgroundColor: AppTheme.ballLime,
              child: Text(
                profile.name.isEmpty ? '?' : profile.name[0].toUpperCase(),
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.courtBlueDark),
              ),
            ),
            title: Text(profile.name,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            subtitle: Text('${profile.phone}\n${profile.email}'),
            isThreeLine: true,
            trailing: IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _editDetails(context)),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.sports_tennis, color: AppTheme.courtBlue),
                const SizedBox(width: 12),
                Text('Padel level: ',
                    style: TextStyle(color: Colors.grey.shade700)),
                Chip(
                  backgroundColor: AppTheme.courtBlue,
                  label: Text(
                    profile.skillLevel.isEmpty ? '—' : profile.skillLevel,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    profile.skillLevel.isEmpty
                        ? ''
                        : levelName(context.l10n, profile.skillLevel)
                            .split('— ')
                            .last,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading:
                const Icon(Icons.event_note, color: AppTheme.courtBlue),
            title: const Text('My bookings',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Upcoming and past games & lessons'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => Scaffold(
                      appBar:
                          AppBar(title: Text(context.l10n.myBookingsTab)),
                      body: MyBookingsScreen(profile: profile),
                    ))),
          ),
        ),
        const SizedBox(height: 8),
        _XpCard(profile: profile),
        const SizedBox(height: 8),
        _PaidSavedCard(profile: profile),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Notify me about open matches at my level'),
                value: profile.notifyOpenMatches,
                onChanged: (v) => auth
                    .updateProfile(profile.uid, {'notifyOpenMatches': v}),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text(
                    'Send me news, offers, and tournament invites'),
                value: profile.marketingConsent,
                onChanged: (v) => auth
                    .updateProfile(profile.uid, {'marketingConsent': v}),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.account_balance_wallet,
                    color: AppTheme.courtBlue),
                title: const Text('Packages & Wallet'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PackagesListScreen(profile: profile))),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.confirmation_number,
                    color: AppTheme.courtBlue),
                title: const Text('Vouchers'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const VouchersListScreen())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.chat, color: AppTheme.courtBlue),
                title: Text(context.l10n.contactUsTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ContactUsScreen())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined,
                    color: AppTheme.courtBlue),
                title: Text(context.l10n.privacyPolicyTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: Text(context.l10n.signOut),
                onTap: () => auth.signOut(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Lifetime totals: what the customer paid and what vouchers saved them.
class _PaidSavedCard extends StatelessWidget {
  final AppUser profile;

  const _PaidSavedCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return StreamBuilder<List<Booking>>(
      stream: db.myBookings(profile.uid),
      builder: (context, snap) {
        final bookings = snap.data ?? [];
        final paid =
            bookings.fold<double>(0, (sum, b) => sum + b.price);
        final saved =
            bookings.fold<double>(0, (sum, b) => sum + b.voucherDiscount);
        if (paid == 0 && saved == 0) return const SizedBox.shrink();
        return Card(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text('Total paid',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                      Text(money.format(paid),
                          style: const TextStyle(
                              color: AppTheme.courtBlue,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Container(
                    width: 1, height: 36, color: Colors.blueGrey.shade100),
                Expanded(
                  child: Column(
                    children: [
                      Text('Saved with vouchers',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                      Text(money.format(saved),
                          style: const TextStyle(
                              color: Colors.green,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
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

/// XP level, totals, and progress to the next level.
class _XpCard extends StatelessWidget {
  final AppUser profile;

  const _XpCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final level = XpSystem.levelFor(profile.xp);
    final progress = XpSystem.progress(profile.xp);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.courtBlue,
                  child: Text('$level',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('XP Level $level',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      Text(
                          '${profile.xp} XP · '
                          '${profile.matchesPlayed} matches played',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.blueGrey.shade50,
                color: AppTheme.ballLime,
              ),
            ),
            const SizedBox(height: 6),
            Text(
                '${XpSystem.xpToNext(profile.xp)} XP to level ${level + 1} '
                '— play more to increase your level!',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
