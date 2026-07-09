import 'package:cloud_firestore/cloud_firestore.dart';

/// App user profile stored in Firestore under users/{uid}.
/// role is either "customer" or "admin". To make yourself the owner/admin,
/// change the role field to "admin" in the Firebase console (see SETUP.md).
class AppUser {
  final String uid;
  final String name;
  final String phone;
  final String email;
  final String role;

  const AppUser({
    required this.uid,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
  });

  bool get isAdmin => role == 'admin';

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      name: (data['name'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      role: (data['role'] as String?) ?? 'customer',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'email': email,
        'role': role,
      };
}
