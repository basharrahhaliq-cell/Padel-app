import 'package:flutter/material.dart';

import '../../main.dart';
import '../theme.dart';

/// Shown when the app runs before Firebase has been connected.
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 72, color: AppTheme.courtBlue),
              const SizedBox(height: 24),
              Text(l10n.firebaseNotConfigured,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(l10n.firebaseSetupHint, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
