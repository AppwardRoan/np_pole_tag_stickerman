// ignore_for_file: avoid_print - a command-line harness; printing is the point.
// Runs the stacked-code rebuild over the real photos in test/fixtures and
// writes what it produces into build/, so the strips can be looked at.
//
// Photos named on the command line are run instead of the fixtures - for
// trying a new shot from the phone without adding it to the set.
//
// A plain script rather than a test because `flutter test` will not run on this
// machine - Windows Application Control blocks flutter_tester.exe. The tests in
// test/stacked_code_test.dart say the same things and will run anywhere else.
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:np_pole_tag_stickerman/services/stacked_code.dart';

Future<void> main(List<String> args) async {
  await Directory('build').create(recursive: true);

  final photos = args.isNotEmpty
      ? args
      : const [
          'stacked_tag.jpg',
          'stacked_tag_partial.jpg',
          'stacked_tag_nnpqf.jpg',
          'stacked_tag_nnpqf2.jpg',
          'stacked_tag_boxed.jpg',
        ].map((name) => 'test/fixtures/$name').toList();

  for (final photo in photos) {
    final name = photo.split(RegExp(r'[\\/]')).last;
    final result = await rebuildStackedCode(photo);
    final cut = result.cutOff ? '  CUT OFF' : '';
    if (result.paths.isEmpty) {
      print('$name -> nothing (not seen as a stacked code)$cut');
      continue;
    }

    for (final (i, row) in result.paths.indexed) {
      final bytes = await File(row).readAsBytes();
      final strip = img.decodeImage(bytes)!;
      final out = 'build/row${i}_$name.png';
      await File(out).writeAsBytes(bytes);
      print('$name -> ${strip.width}x${strip.height}  $out$cut');
    }
  }

  if (args.isNotEmpty) return;

  // Must be left alone: a code printed across.
  final across = img.Image(width: 600, height: 400, numChannels: 1);
  img.fill(across, color: img.ColorUint8.rgb(255, 255, 255));
  img.drawString(
    across,
    'NNPQA',
    font: img.arial48,
    x: 120,
    y: 180,
    color: img.ColorUint8.rgb(0, 0, 0),
  );
  await File('build/across.png').writeAsBytes(img.encodePng(across));
  print('across -> ${await rebuildStackedCode('build/across.png')}');

  final blank = img.Image(width: 400, height: 600, numChannels: 1);
  img.fill(blank, color: img.ColorUint8.rgb(240, 240, 240));
  await File('build/blank.png').writeAsBytes(img.encodePng(blank));
  print('blank -> ${await rebuildStackedCode('build/blank.png')}');
}
