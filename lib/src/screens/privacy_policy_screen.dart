import 'package:flutter/material.dart';

import '../../main.dart';

/// Simple privacy policy — required by the App Store and Google Play.
/// The policy text is intentionally kept in one place; when Arabic is
/// added, translate [_sections] the same way as lib/l10n/app_en.arb.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const List<(String, String)> _sections = [
    (
      'What we collect',
      'When you create an account we store your name, phone number, email '
          'address, and padel skill level. When you book a court we store '
          'the booking details (branch, court, date, time, duration, and '
          'price). If you join open matches or tournaments we store your '
          'participation and results.'
    ),
    (
      'Why we collect it',
      'Your name and phone number let the club identify and contact you '
          'about your reservations. Your skill level is used to match you '
          'with open matches and tournaments of your level. Booking history '
          'is kept so you and the club can see past and upcoming games.'
    ),
    (
      'Marketing',
      'We only send news, offers, and tournament invitations if you ticked '
          '"Send me news, offers, and tournament invites" — you can change '
          'this any time in your profile.'
    ),
    (
      'Notifications',
      'The app sends booking reminders and, if enabled in your profile, '
          'notifications about open matches at your level and tournaments. '
          'You can turn these off in your profile or in your phone settings.'
    ),
    (
      'Where your data lives',
      'Data is stored securely in Google Firebase (Firestore) and is only '
          'accessible to you and club staff. We do not sell or share your '
          'data with third parties. Payments are made at the club — the app '
          'stores no payment card details.'
    ),
    (
      'Your choices',
      'You can update your profile details in the app at any time. To '
          'delete your account and data, contact the club and we will '
          'remove them.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyPolicyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final (title, body) in _sections) ...[
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}
