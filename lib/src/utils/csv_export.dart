import 'csv_export_io.dart'
    if (dart.library.js_interop) 'csv_export_web.dart' as impl;

/// Hands a CSV report to the user, in whatever way fits the platform:
/// phones open the share sheet (WhatsApp/email/AirDrop), browsers
/// download the file directly.
Future<void> shareCsv({
  required String filename,
  required String content,
  required String subject,
}) =>
    impl.shareCsvImpl(
        filename: filename, content: content, subject: subject);
