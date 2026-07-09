import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'src/screens/auth/auth_gate.dart';
import 'src/screens/setup_required_screen.dart';
import 'src/services/auth_service.dart';
import 'src/services/firestore_service.dart';
import 'src/services/notification_service.dart';
import 'src/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    firebaseReady = true;
  } catch (_) {
    // Firebase not configured yet — the app shows the setup screen.
  }

  runApp(PadelApp(firebaseReady: firebaseReady));
}

class PadelApp extends StatelessWidget {
  final bool firebaseReady;

  const PadelApp({super.key, required this.firebaseReady});

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: "Let's Padel",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')], // add Locale('ar') later
      home: firebaseReady ? const AuthGate() : const SetupRequiredScreen(),
    );

    if (!firebaseReady) return app;

    return MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => FirestoreService()),
        Provider(create: (_) => NotificationService()),
      ],
      child: app,
    );
  }
}

/// Shortcut used across screens: `context.l10n.someString`.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
