import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../../utils/validators.dart';
import '../auth/login_screen.dart' show levelName;
import '../contact_us_screen.dart';
import '../privacy_policy_screen.dart';

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
