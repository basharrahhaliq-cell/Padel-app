import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';

/// Sign-up / login with email+password or Google, plus the Firestore user
/// profile (name, phone, skill level, role) that goes with the account.
///
/// Phone/SMS *login* was removed (it requires the paid Firebase plan), but
/// every profile still carries a required, validated Lebanese phone number
/// so the owner can always reach the customer about a booking.
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AuthService([FirebaseAuth? auth, FirebaseFirestore? db])
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  Stream<User?> get authState => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Stream<AppUser?> profileOf(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? AppUser.fromDoc(doc) : null);

  Future<void> signUpWithEmail({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await _ensureProfile(cred.user!, name: name, phone: phone, email: email);
  }

  Future<void> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  /// Google sign-in. Creates the profile on first login; the phone number
  /// is collected right after by the "complete profile" screen (AuthGate
  /// routes there while the profile has no phone).
  /// The Firebase project's Web client ID — required on Android to get
  /// an ID token (we don't ship google-services.json). Client IDs are
  /// public identifiers, safe to commit.
  static const _webClientId =
      '941590347459-mtaud4e1kj95vgprhl2jc5m5jphr3bvd.apps.googleusercontent.com';

  Future<void> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    await google.initialize(serverClientId: _webClientId);
    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final cred = await _auth.signInWithCredential(credential);
    await _ensureProfile(cred.user!,
        name: account.displayName ?? '', email: account.email);
  }

  /// Fills in profile fields (used by the complete-profile screen and the
  /// profile/settings screen). Only the provided fields change.
  Future<void> updateProfile(String uid, Map<String, dynamic> fields) =>
      _db.collection('users').doc(uid).update(fields);

  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Not signed in with Google — nothing to do.
    }
    await _auth.signOut();
  }

  /// Creates the users/{uid} profile on first login; never downgrades an
  /// existing profile (so a manually granted admin role is preserved).
  Future<void> _ensureProfile(User user,
      {String? name, String? phone, String? email}) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) {
      final updates = <String, dynamic>{};
      final existing = snap.data() ?? {};
      if (name != null &&
          name.isNotEmpty &&
          (existing['name'] as String? ?? '').isEmpty) {
        updates['name'] = name;
      }
      if (phone != null && phone.isNotEmpty) updates['phone'] = phone;
      if (updates.isNotEmpty) await ref.update(updates);
      return;
    }
    await ref.set({
      ...AppUser(
        uid: user.uid,
        name: name ?? '',
        phone: phone ?? '',
        email: email ?? user.email ?? '',
        role: 'customer',
      ).toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
