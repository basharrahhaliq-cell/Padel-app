import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../admin/admin_home.dart';
import '../customer/customer_home.dart';
import 'login_screen.dart';

/// Decides which world you land in:
/// signed out -> login, admin -> owner dashboard, customer -> booking.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return StreamBuilder<User?>(
      stream: auth.authState,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Splash();
        }
        final user = snap.data;
        if (user == null) return const LoginScreen();

        return StreamBuilder<AppUser?>(
          stream: auth.profileOf(user.uid),
          builder: (context, profileSnap) {
            if (!profileSnap.hasData) return const _Splash();
            final profile = profileSnap.data!;
            return profile.isAdmin
                ? AdminHome(profile: profile)
                : CustomerHome(profile: profile);
          },
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
