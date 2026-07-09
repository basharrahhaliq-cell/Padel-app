import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart';
import '../theme.dart';

/// WhatsApp contact buttons, one per branch.
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  // Branch WhatsApp numbers in international format (no + or spaces,
  // as required by wa.me links).
  static const List<(String, String)> _branches = [
    ('Airport Road', '96176111614'),
    ('Hazmieh', '96178952231'),
  ];

  Future<void> _openWhatsApp(BuildContext context, String number) async {
    final l10n = context.l10n;
    final uri = Uri.parse('https://wa.me/$number');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.couldNotOpenWhatsapp)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.contactUsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Image.asset('assets/images/lets_padel_logo.png', height: 120),
          const SizedBox(height: 24),
          Text(l10n.contactUsHint, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          for (final (name, number) in _branches)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // WhatsApp green
                ),
                icon: const Icon(Icons.chat),
                label: Text(l10n.whatsappButton(name)),
                onPressed: () => _openWhatsApp(context, number),
              ),
            ),
          const SizedBox(height: 8),
          for (final (name, number) in _branches)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('$name · +$number',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

/// Small reusable brand logo widget (login, splash, contact).
class BrandLogo extends StatelessWidget {
  final double height;

  const BrandLogo({super.key, this.height = 140});

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/images/lets_padel_logo.png',
        height: height,
        errorBuilder: (_, _, _) => const Icon(Icons.sports_tennis,
            size: 64, color: AppTheme.courtBlue),
      );
}
