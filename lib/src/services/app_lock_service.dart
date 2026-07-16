import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional fingerprint/face lock for opening the app.
///
/// The preference lives on the device (not in Firestore): biometrics
/// are a property of the phone in your hand, so each device decides
/// for itself.
class AppLockService {
  static const _prefKey = 'appLockEnabled';
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_prefKey) ?? false;

  Future<void> setEnabled(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_prefKey, value);

  /// Whether this phone can do biometric (or device credential) checks.
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Shows the system fingerprint/face/PIN prompt. Returns true when
  /// the user passed the check.
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: "Unlock Let's Padel",
        // Retry instead of failing if the prompt backgrounds the app.
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false; // no biometrics enrolled / cancelled / unsupported
    }
  }
}
