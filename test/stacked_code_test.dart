import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:np_pole_tag_stickerman/services/stacked_code.dart';

/// The fixtures are real photos, taken on the phone, of the tag the scan could
/// not read - not pictures drawn to pass. `stacked_tag.jpg` is the clean shot;
/// `stacked_tag_partial.jpg` has the last letter running off the bottom, which
/// is what an unsteady hand at a pole produces; `stacked_tag_boxed.jpg` has a
/// selection box drawn round the letters, which put a thin bar either side of
/// every one of them and broke the read.
///
/// `flutter test` will not run on the machine this was written on - Windows
/// Application Control blocks flutter_tester.exe - so `tool/check_stacked.dart`
/// carries the same checks in a form that does run there.
void main() {
  late Directory work;

  setUp(() async {
    work = await Directory.systemTemp.createTemp('stacked_code_test');
  });

  tearDown(() async {
    if (work.existsSync()) await work.delete(recursive: true);
  });

  Future<String> fixture(String name) async {
    final copy = File('${work.path}/$name');
    await copy.writeAsBytes(await File('test/fixtures/$name').readAsBytes());
    return copy.path;
  }

  Future<img.Image> rowOf(String name) async {
    final rows = (await rebuildStackedCode(await fixture(name))).paths;
    expect(rows, isNotEmpty, reason: '$name is a stacked code');
    return img.decodeImage(await File(rows.first).readAsBytes())!;
  }

  test('stands the letters of a stacked tag in a row', () async {
    final strip = await rowOf('stacked_tag.jpg');

    // The whole point: what comes out is a line of writing, wider than it is
    // tall, where what went in was a column taller than it was wide.
    expect(
      strip.width,
      greaterThan(strip.height * 2),
      reason: 'a row, not a column',
    );
  });

  test('handles the shot with a letter cut off the bottom', () async {
    final strip = await rowOf('stacked_tag_partial.jpg');
    expect(strip.width, greaterThan(strip.height));
  });

  test('says when a letter runs off the edge of the photo', () async {
    // Drawn rather than photographed: in `stacked_tag_partial.jpg` the cut
    // letter sits in shade too deep for the careful reading, which is a
    // different question from whether a cut letter is noticed.
    Future<String> drawn(String name, {required int shift}) async {
      final pic = img.Image(width: 300, height: 600, numChannels: 1);
      img.fill(pic, color: img.ColorUint8.rgb(255, 255, 255));
      for (final (i, letter) in 'N2L6Q'.split('').indexed) {
        img.drawString(
          pic,
          letter,
          font: img.arial48,
          x: 135,
          y: 60 + i * 100 + shift,
          color: img.ColorUint8.rgb(0, 0, 0),
        );
      }
      final path = '${work.path}/$name';
      await File(path).writeAsBytes(img.encodePng(pic));
      return path;
    }

    // The Q pushed partway off the bottom of the photo.
    final cut = await rebuildStackedCode(await drawn('cut.png', shift: 110));
    expect(cut.cutOff, isTrue);

    final whole = await rebuildStackedCode(await drawn('whole.png', shift: 0));
    expect(whole.cutOff, isFalse);
  });

  test('drops the thin bars a selection box draws beside the letters',
      () async {
    final strip = await rowOf('stacked_tag_boxed.jpg');
    expect(strip.width, greaterThan(strip.height * 2));
  });

  test('leaves a photo that is not a stacked code alone', () async {
    // A code printed across, drawn rather than photographed: the guard is about
    // shape, and this is the shape that must come back untouched, or every
    // ordinary scan in the app would be mangled before being read.
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

    final path = '${work.path}/across.png';
    await File(path).writeAsBytes(img.encodePng(across));

    expect((await rebuildStackedCode(path)).paths, isEmpty);
  });

  test('leaves a blank photo alone', () async {
    final blank = img.Image(width: 400, height: 600, numChannels: 1);
    img.fill(blank, color: img.ColorUint8.rgb(240, 240, 240));

    final path = '${work.path}/blank.png';
    await File(path).writeAsBytes(img.encodePng(blank));

    expect((await rebuildStackedCode(path)).paths, isEmpty);
  });
}
