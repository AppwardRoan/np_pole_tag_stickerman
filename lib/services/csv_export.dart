import 'dart:io';
import 'dart:ui';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Puts a downloaded spreadsheet somewhere the phone can hand on.
///
/// Written to the app's temporary folder rather than to Downloads. Downloads
/// needs a storage permission that Android has narrowed twice in three
/// versions, and what he does with this file is send it - he is not filing it
/// on the handset. The share sheet copies it wherever it goes, and Android
/// clears the temporary folder on its own afterwards.
class CsvExport {
  const CsvExport();

  /// Writes the bytes and opens the share sheet on them.
  ///
  /// [origin] is where on screen the tap came from, which iPad needs to anchor
  /// the popover. Android ignores it.
  Future<void> share({
    required List<int> bytes,
    required String filename,
    required String subject,
    Rect? origin,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');

    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        // What lands in the subject line when he picks mail. Without it he is
        // sending an attachment with no message at all.
        subject: subject,
        sharePositionOrigin: origin,
      ),
    );
  }
}
