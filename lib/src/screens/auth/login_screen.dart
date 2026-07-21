import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import '../contact_us_screen.dart';
import '../privacy_policy_screen.dart';

/// Login / sign-up with email+password, or one tap with Google.
/// Sign-up collects the required profile: name, Lebanese phone number,
/// padel level, and the optional marketing consent.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _creatingAccount = false;
  bool _busy = false;
  String _skillLevel = 'D';
  bool _marketingConsent = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      if (mounted) _snack(context.l10n.authFailed(e.message ?? e.code));
    } on GoogleSignInException catch (e) {
      // Cancelled sign-in is not an error worth showing.
      if (e.code != GoogleSignInExceptionCode.canceled && mounted) {
        _snack(context.l10n.authFailed(e.description ?? e.code.name));
      }
    } catch (e) {
      if (mounted) _snack(context.l10n.genericError(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitEmail() async {
    final l10n = context.l10n;
    final auth = context.read<AuthService>();
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      _snack(l10n.fillAllFields);
      return;
    }
    if (_creatingAccount) {
      if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
        _snack(l10n.fillAllFields);
        return;
      }
      final phone = LebanesePhone.normalize(_phone.text);
      if (phone == null) {
        _snack(l10n.invalidPhone);
        return;
      }
      await _run(() async {
        await auth.signUpWithEmail(
          name: _name.text.trim(),
          phone: phone,
          email: _email.text.trim(),
          password: _password.text,
        );
        await auth.updateProfile(auth.currentUser!.uid, {
          'skillLevel': _skillLevel,
          'marketingConsent': _marketingConsent,
        });
      });
    } else {
      await _run(
          () => auth.signInWithEmail(_email.text.trim(), _password.text));
    }
  }

  Future<void> _forgotPassword() async {
    final l10n = context.l10n;
    if (_email.text.trim().isEmpty) {
      _snack(l10n.fillAllFields);
      return;
    }
    await _run(() async {
      await context.read<AuthService>().resetPassword(_email.text.trim());
      _snack(l10n.resetEmailSent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const BrandLogo(height: 150),
              const SizedBox(height: 28),
              if (_creatingAccount) ...[
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
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l10n.emailLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.passwordLabel),
              ),
              if (_creatingAccount) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _skillLevel,
                  decoration:
                      InputDecoration(labelText: l10n.skillLevelLabel),
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
                  onChanged: (v) =>
                      setState(() => _marketingConsent = v ?? false),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submitEmail,
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_creatingAccount ? l10n.signUp : l10n.signIn),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.g_mobiledata, size: 32),
                label: Text(l10n.continueWithGoogle),
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => context.read<AuthService>().signInWithGoogle()),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () =>
                        setState(() => _creatingAccount = !_creatingAccount),
                child: Text(
                    _creatingAccount ? l10n.haveAccount : l10n.noAccountYet),
              ),
              if (!_creatingAccount)
                TextButton(
                  onPressed: _busy ? null : _forgotPassword,
                  child: Text(l10n.forgotPassword),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ContactUsScreen())),
                    child: Text(l10n.contactUsTitle,
                        style: TextStyle(color: Colors.grey.shade600)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen())),
                    child: Text(l10n.privacyPolicyTitle,
                        style: TextStyle(color: Colors.grey.shade600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Human-readable level name, shared by every screen that shows levels.
String levelName(dynamic l10n, String level) {
  switch (level) {
    case 'A':
      return l10n.levelA;
    case 'B':
      return l10n.levelB;
    case 'C':
      return l10n.levelC;
    case 'D':
      return l10n.levelD;
    default:
      return level;
  }
}
