/// Lebanese phone number validation and normalization.
///
/// Accepts common ways people write their number:
///   03 123 456 · 70123456 · +961 3 123456 · 961-71-123-456 · 0096176123456
/// Mobile prefixes: 3, 70, 71, 76, 78, 79, 81. Landlines (7 digits after
/// the area code) are also accepted so the club can be reached either way.
class LebanesePhone {
  LebanesePhone._();

  static final _cleanup = RegExp(r'[\s\-().]');

  /// Returns the number normalized to international format (+961XXXXXXX),
  /// or null when it is not a valid Lebanese number.
  static String? normalize(String input) {
    var digits = input.replaceAll(_cleanup, '');
    if (digits.startsWith('00961')) {
      digits = digits.substring(5);
    } else if (digits.startsWith('+961')) {
      digits = digits.substring(4);
    } else if (digits.startsWith('961') && digits.length > 8) {
      digits = digits.substring(3);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (!RegExp(r'^\d+$').hasMatch(digits)) return null;

    // Mobile: 3 + 6 digits, or (70|71|76|78|79|81) + 6 digits.
    final mobile = RegExp(r'^(3\d{6}|(70|71|76|78|79|81)\d{6})$');
    // Landline: area code (1,4,5,6,7,8,9) + 6 digits.
    final landline = RegExp(r'^[1456789]\d{6}$');
    if (mobile.hasMatch(digits) || landline.hasMatch(digits)) {
      return '+961$digits';
    }
    return null;
  }

  static bool isValid(String input) => normalize(input) != null;
}
