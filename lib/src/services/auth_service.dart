import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

/// Sign-up / login with email+password or phone OTP, and the Firestore
/// user profile (name, phone, role) that goes with the Firebase account.
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

  /// Phone auth step 1: sends the SMS code. Callbacks mirror Firebase's:
  /// [onCodeSent] receives the verificationId needed for step 2.
  Future<void> startPhoneSignIn({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
    required void Function() onAutoVerified,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        final cred = await _auth.signInWithCredential(credential);
        await _ensureProfile(cred.user!, phone: phoneNumber);
        onAutoVerified();
      },
      verificationFailed: (e) => onError(e.message ?? e.code),
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Phone auth step 2: confirms the SMS code the user typed.
  Future<void> confirmSmsCode({
    required String verificationId,
    required String smsCode,
    required String name,
    required String phone,
  }) async {
    final credential = PhoneAuthProvider.credential(
        verificationId: verificationId, smsCode: smsCode);
    final cred = await _auth.signInWithCredential(credential);
    await _ensureProfile(cred.user!, name: name, phone: phone);
  }

  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> signOut() => _auth.signOut();

  /// Creates the users/{uid} profile on first login; never downgrades an
  /// existing profile (so a manually granted admin role is preserved).
  Future<void> _ensureProfile(User user,
      {String? name, String? phone, String? email}) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) {
      final updates = <String, dynamic>{};
      if (name != null && name.isNotEmpty) updates['name'] = name;
      if (phone != null && phone.isNotEmpty) updates['phone'] = phone;
      if (updates.isNotEmpty) await ref.update(updates);
      return;
    }
    await ref.set(AppUser(
      uid: user.uid,
      name: name ?? '',
      phone: phone ?? user.phoneNumber ?? '',
      email: email ?? user.email ?? '',
      role: 'customer',
    ).toMap());
  }
}
