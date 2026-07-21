import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_lock_service.dart';
import '../theme.dart';
import 'contact_us_screen.dart' show BrandLogo;

/// Sits above the whole app: when the owner of this device turned the
/// fingerprint lock on, the app stays behind this screen until the
/// system biometric check passes. Re-locks after the app spends more
/// than a minute in the background.
class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _checking = true;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    final lock = context.read<AppLockService>();
    final enabled = await lock.isEnabled();
    if (!mounted) return;
    setState(() {
      _locked = enabled;
      _checking = false;
    });
    if (enabled) _unlock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && !_locked) {
      final away = _pausedAt == null
          ? Duration.zero
          : DateTime.now().difference(_pausedAt!);
      if (away > const Duration(minutes: 1)) _relockIfEnabled();
    }
  }

  Future<void> _relockIfEnabled() async {
    final lock = context.read<AppLockService>();
    if (!await lock.isEnabled() || !mounted) return;
    setState(() => _locked = true);
    _unlock();
  }

  Future<void> _unlock() async {
    final lock = context.read<AppLockService>();
    final ok = await lock.authenticate();
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
          backgroundColor: Colors.white, body: SizedBox.shrink());
    }
    if (!_locked) return widget.child;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const BrandLogo(height: 120),
            const SizedBox(height: 40),
            const Icon(Icons.fingerprint,
                size: 56, color: AppTheme.courtBlue),
            const SizedBox(height: 12),
            const Text('App is locked',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.lock_open),
              label: const Text('Unlock'),
              onPressed: _unlock,
            ),
          ],
        ),
      ),
    );
  }
}
