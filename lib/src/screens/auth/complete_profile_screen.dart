import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import 'login_screen.dart' show levelName;

/// Shown right after a Google sign-in (or any profile missing required
/// fields): collects the Lebanese phone number, padel level, and the
/// optional marketing consent. AuthGate keeps routing here until done.
class CompleteProfileScreen extends StatefulWidget {
  final AppUser profile;

  const CompleteProfileScreen({super.key, required this.profile});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.profile.name);
  late final TextEditingController _phone =
      TextEditingController(text: widget.profile.phone);
  late String _skillLevel =
      widget.profile.skillLevel.isEmpty ? 'D' : widget.profile.skillLevel;
  late bool _marketingConsent = widget.profile.marketingConsent;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final auth = context.read<AuthService>();
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.fillAllFields)));
      return;
    }
    final phone = LebanesePhone.normalize(_phone.text);
    if (phone == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.invalidPhone)));
      return;
    }
    setState(() => _busy = true);
    try {
      await auth.updateProfile(widget.profile.uid, {
        'name': _name.text.trim(),
        'phone': phone,
        'skillLevel': _skillLevel,
        'marketingConsent': _marketingConsent,
      });
      // AuthGate sees the completed profile and moves on automatically.
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.genericError(e.toString()))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.completeProfileTitle),
        actions: [
          IconButton(
            tooltip: l10n.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthService>().signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l10n.completeProfileHint),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l10n.nameLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
                labelText: l10n.phoneLabel, hintText: l10n.phoneHint),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _skillLevel,
            decoration: InputDecoration(labelText: l10n.skillLevelLabel),
            items: [
              for (final level in kSkillLevels)
                DropdownMenuItem(
                    value: level, child: Text(levelName(l10n, level))),
            ],
            onChanged: (v) => setState(() => _skillLevel = v!),
          ),
          CheckboxListTile(
            value: _marketingConsent,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(l10n.marketingConsentLabel,
                style: const TextStyle(fontSize: 14)),
            onChanged: (v) => setState(() => _marketingConsent = v ?? false),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.continueButton),
          ),
        ],
      ),
    );
  }
}
