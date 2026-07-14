import 'package:cloud_firestore/cloud_firestore.dart';

/// Padel skill levels used across sign-up, open matches and tournaments.
/// A = advanced, B = intermediate, C = beginner-intermediate, D = beginner.
const List<String> kSkillLevels = ['A', 'B', 'C', 'D'];

/// App user profile stored in Firestore under users/{uid}.
/// role is either "customer" or "admin". To make yourself the owner/admin,
/// change the role field to "admin" in the Firebase console (see SETUP.md).
class AppUser {
  final String uid;
  final String name;
  final String phone;
  final String email;
  final String role;

  /// Padel level: A / B / C / D (empty until the user picks one).
  final String skillLevel;

  /// "Send me news, offers, and tournament invites."
  final bool marketingConsent;

  /// "Notify me about open matches at my level" (on by default).
  final bool notifyOpenMatches;

  /// Gamification — written only by the Cloud Function after games happen.
  final int xp;
  final int matchesPlayed;

  /// Prepaid wallet: credit granted by the owner when a package is
  /// bought at the club. Unusable after [walletExpiry] (yyyy-MM-dd).
  final double walletBalance;
  final String walletExpiry;

  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    this.skillLevel = '',
    this.marketingConsent = false,
    this.notifyOpenMatches = true,
    this.xp = 0,
    this.matchesPlayed = 0,
    this.walletBalance = 0,
    this.walletExpiry = '',
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  /// True once the required fields exist (Google sign-ins start without a
  /// phone/level and are routed to the complete-profile screen).
  bool get isComplete => phone.isNotEmpty && skillLevel.isNotEmpty;

  /// Usable wallet credit (0 when expired).
  double usableWallet(String todayKey) => walletBalance > 0 &&
          walletExpiry.isNotEmpty &&
          walletExpiry.compareTo(todayKey) >= 0
      ? walletBalance
      : 0;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      name: (data['name'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      role: (data['role'] as String?) ?? 'customer',
      skillLevel: (data['skillLevel'] as String?) ?? '',
      marketingConsent: (data['marketingConsent'] as bool?) ?? false,
      notifyOpenMatches: (data['notifyOpenMatches'] as bool?) ?? true,
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      matchesPlayed: (data['matchesPlayed'] as num?)?.toInt() ?? 0,
      walletBalance: (data['walletBalance'] as num?)?.toDouble() ?? 0,
      walletExpiry: (data['walletExpiry'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'email': email,
        'role': role,
        'skillLevel': skillLevel,
        'marketingConsent': marketingConsent,
        'notifyOpenMatches': notifyOpenMatches,
      };
}
