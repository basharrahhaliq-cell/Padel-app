import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../admin/admin_home.dart';
import '../customer/customer_home.dart';
import 'complete_profile_screen.dart';
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
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const _Splash();
            }
            final profile = profileSnap.data;
            // Google sign-ins land here before their Firestore profile
            // exists or has a phone/level — collect what's missing.
            if (profile == null || (!profile.isAdmin && !profile.isComplete)) {
              return CompleteProfileScreen(
                profile: profile ??
                    AppUser(
                      uid: user.uid,
                      name: user.displayName ?? '',
                      phone: '',
                      email: user.email ?? '',
                      role: 'customer',
                    ),
              );
            }
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
  Widget build(BuildContext context) => Scaffold(
        // Club navy, matching the Android 12+ system splash before it:
        // launching reads as one branded intro (mark -> full logo).
        backgroundColor: AppTheme.courtBlueDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/lets_padel_logo_white.png',
                height: 160,
                errorBuilder: (_, _, _) => const Icon(
                    Icons.sports_tennis,
                    size: 64,
                    color: Colors.white),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(color: AppTheme.ballLime),
            ],
          ),
        ),
      );
}
