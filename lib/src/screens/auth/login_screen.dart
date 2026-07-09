import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../main.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';

/// Login / sign-up with two tabs: Email (password) and Phone (SMS code).
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
  final _smsCode = TextEditingController();

  bool _creatingAccount = false;
  bool _busy = false;
  String? _verificationId; // set once the SMS code has been sent

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password, _smsCode]) {
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
    if (_creatingAccount &&
        (_name.text.trim().isEmpty || _phone.text.trim().isEmpty)) {
      _snack(l10n.fillAllFields);
      return;
    }
    await _run(() async {
      if (_creatingAccount) {
        await auth.signUpWithEmail(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await auth.signInWithEmail(_email.text.trim(), _password.text);
      }
    });
  }

  Future<void> _sendSmsCode() async {
    final l10n = context.l10n;
    final auth = context.read<AuthService>();
    if (_phone.text.trim().isEmpty || _name.text.trim().isEmpty) {
      _snack(l10n.fillAllFields);
      return;
    }
    setState(() => _busy = true);
    await auth.startPhoneSignIn(
      phoneNumber: _phone.text.trim(),
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _busy = false;
        });
        _snack(l10n.codeSentTo(_phone.text.trim()));
      },
      onError: (message) {
        if (!mounted) return;
        setState(() => _busy = false);
        _snack(l10n.authFailed(message));
      },
      onAutoVerified: () {
        if (mounted) setState(() => _busy = false);
      },
    );
  }

  Future<void> _confirmSmsCode() async {
    final auth = context.read<AuthService>();
    if (_verificationId == null || _smsCode.text.trim().isEmpty) return;
    await _run(() => auth.confirmSmsCode(
          verificationId: _verificationId!,
          smsCode: _smsCode.text.trim(),
          name: _name.text.trim(),
          phone: _phone.text.trim(),
        ));
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                const Icon(Icons.sports_tennis,
                    size: 64, color: AppTheme.courtBlue),
                const SizedBox(height: 8),
                Text(l10n.appTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                            color: AppTheme.courtBlue,
                            fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TabBar(
                  labelColor: AppTheme.courtBlue,
                  tabs: [
                    Tab(text: l10n.emailTab),
                    Tab(text: l10n.phoneTab),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 420,
                  child: TabBarView(
                    children: [_emailTab(l10n), _phoneTab(l10n)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emailTab(dynamic l10n) {
    return ListView(
      children: [
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
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _submitEmail,
          child: _busy
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_creatingAccount ? l10n.signUp : l10n.signIn),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() => _creatingAccount = !_creatingAccount),
          child:
              Text(_creatingAccount ? l10n.haveAccount : l10n.noAccountYet),
        ),
        if (!_creatingAccount)
          TextButton(
            onPressed: _busy ? null : _forgotPassword,
            child: Text(l10n.forgotPassword),
          ),
      ],
    );
  }

  Widget _phoneTab(dynamic l10n) {
    final codeSent = _verificationId != null;
    return ListView(
      children: [
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
        if (codeSent)
          TextField(
            controller: _smsCode,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.smsCodeLabel),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy
              ? null
              : codeSent
                  ? _confirmSmsCode
                  : _sendSmsCode,
          child: _busy
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(codeSent ? l10n.verifyCode : l10n.sendCode),
        ),
      ],
    );
  }
}
