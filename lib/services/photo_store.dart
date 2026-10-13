import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

typedef Compressor = Future<void> Function(File source, File target);

class PhotoStore {
  PhotoStore(this._folder, {Compressor? compressor})
    : _compress = compressor ?? _shrink;

  final Directory _folder;
  final Compressor _compress;

  static const String folderName = 'pending_photos';

  static const int _maxEdge = 1600;
  static const int _quality = 70;

  static Future<PhotoStore> open() async {
    final documents = await getApplicationDocumentsDirectory();
    final folder = Directory('${documents.path}/$folderName');

    if (!await folder.exists()) await folder.create(recursive: true);

    return PhotoStore(folder);
  }

  Future<String> keep(String tempPath, String name) async {
    if (!await _folder.exists()) await _folder.create(recursive: true);

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final target = File('${_folder.path}/${stamp}_$name.jpg');

    await _compress(File(tempPath), target);

    return target.path;
  }

  Future<void> discard(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // A photo that will not delete is wasted space, not a failed upload.
        // Losing the tag over it would be the worse outcome.
      }
    }
  }

  static Future<void> _shrink(File source, File target) async {
    final shrunk = await FlutterImageCompress.compressAndGetFile(
      source.absolute.path,
      target.absolute.path,
      minWidth: _maxEdge,
      minHeight: _maxEdge,
      quality: _quality,
    );

    // Some phones refuse a format the plugin cannot re-encode. A full-size
    // photo that uploads beats no photo at all.
    if (shrunk == null) {
      await target.writeAsBytes(await source.readAsBytes());
    }
  }
}
