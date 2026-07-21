import 'package:web/web.dart' as web;

/// Browser: trigger a plain file download (no share sheets on the web).
Future<void> shareCsvImpl({
  required String filename,
  required String content,
  required String subject,
}) async {
  final anchor = web.HTMLAnchorElement()
    ..href = 'data:text/csv;charset=utf-8,${Uri.encodeComponent(content)}'
    ..download = filename;
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
}
