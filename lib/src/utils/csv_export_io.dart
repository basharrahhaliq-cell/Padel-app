import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Phone/desktop: write to a temp file and open the share sheet.
Future<void> shareCsvImpl({
  required String filename,
  required String content,
  required String subject,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'text/csv')],
    subject: subject,
  ));
}
