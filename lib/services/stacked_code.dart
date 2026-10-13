import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Turns a tag code printed *down* the sticker into one printed across, so the
/// text recogniser will look at it.
///
/// The recogniser reads rows. It wants letters sitting side by side, sharing a
/// baseline, close together - that is its whole idea of what text is. The
/// printed tags carry their code one letter to a line, each letter alone with
/// white space above and below it, and against that the recogniser returns not
/// a bad guess but nothing at all: no blocks, no lines, no text. Measured on
/// the phone, from a sharp photo, in good light. The English reader and the
/// Japanese one both, and the Japanese one is built for writing that runs
/// downward.
///
/// So the photo is rebuilt before it is read: find the letters, cut them out,
/// stand them in a row. What comes back is an ordinary word in black on white,
/// which is the one thing the recogniser is good at.
///
/// Returns the paths of the rebuilt pictures, best first - empty when the
/// photo does not look like a stacked code: a code printed across, a page of
/// writing, a wall. Empty means "nothing to do here", not "failed": the scan
/// carries on with what the ordinary read found.
///
/// There can be two, because the photo is read two ways - see `_InkRule`. On
/// 39 photos from the phone, at a pole and a wall, the careful way read 25
/// cleanly and the plain way 13, but they missed different photos: between
/// them, 29.
///
/// [cutOff] is set when the top or bottom letter runs off the edge of the
/// photo. Held close, the N of N2L6Q lost its top half to the frame, was read
/// as something else, and the scan told him a sticker that was right was the
/// wrong tag. A half letter is not worth guessing at; he needs to step back.
Future<({List<String> paths, bool cutOff})> rebuildStackedCode(
  String photoPath,
) async {
  final bytes = await File(photoPath).readAsBytes();

  // Off the UI thread. It is a tenth of a second or so of pixel work, which is
  // long enough to jerk the camera preview if it ran here.
  final result = await Isolate.run(() => _rebuild(bytes));

  final paths = <String>[];
  for (final (i, strip) in result.strips.indexed) {
    final out = '$photoPath.row$i.png';
    await File(out).writeAsBytes(strip);
    paths.add(out);
  }
  return (paths: paths, cutOff: result.cutOff);
}

/// The two ways a pixel is judged to be print.
enum _InkRule {
  /// Darker than its paper, on paper as white as the sticker, and black rather
  /// than a shade darker. Keeps bark, stone and concrete out of the letters.
  careful,

  /// Darker than its paper and nothing more. Lets through more of the wall,
  /// but holds on to letters the careful rule loses in shade.
  plain,
}

/// The longest side the work is done at.
///
/// A phone photo is several thousand pixels across and none of that detail
/// helps here - the letters are enormous. Shrinking first is what keeps this
/// quick enough to sit in the middle of a scan.
const int _workingSize = 800;

/// How much darker than its surroundings a pixel has to be to count as ink.
const int _inkDepth = 45;

/// How wide a square the paper is judged over.
///
/// Each square then takes the whitest of itself and its eight neighbours, so
/// the paper is really judged over three times this. Wider than a letter
/// stroke and narrower than the shading across the photo, which is the whole
/// trick: the area always contains some sticker, never only ink.
///
/// Sixteen on its own was not wide enough. The phone's photos are 480 by 720,
/// and from arm's length the strokes of the printed code are seventeen or
/// eighteen pixels thick - a square could sit wholly inside one, take ink for
/// paper, and punch a hole through the letter. The L lost its foot and read
/// as I, the N came out in pieces, and the scan matched nothing.
const int _paperBlock = 16;

({List<Uint8List> strips, bool cutOff}) _rebuild(Uint8List bytes) {
  const nothing = (strips: <Uint8List>[], cutOff: false);

  final decoded = img.decodeImage(bytes);
  if (decoded == null) return nothing;

  // The camera records which way up the phone was rather than rotating the
  // pixels. Left unbaked, a portrait shot is handled here on its side and the
  // column reads as a row.
  final upright = img.bakeOrientation(decoded);

  final longest = max(upright.width, upright.height);
  final scaled = longest > _workingSize
      ? img.copyResize(upright, width: upright.width * _workingSize ~/ longest)
      : upright;

  final grey = img.grayscale(scaled);
  final w = grey.width;
  final h = grey.height;

  final lum = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      lum[y * w + x] = grey.getPixel(x, y).r.toInt();
    }
  }

  // The paper, without the print on it: the lightest pixel in each square of
  // the photo, which is white sticker wherever there is any white sticker to be
  // had, then smoothed back up to full size.
  //
  // Averaging each square instead - the obvious thing, and what was here first
  // - drags the estimate down wherever a letter fills the square, and the
  // middle of a thick stroke then reads as "no darker than its surroundings".
  // The letters came out hollow, with white gashes through them, and NNPQF read
  // as NNPQE. The lightest pixel does not care how much ink is in the square.
  final paper = _paper(lum, w, h);
  final spread = img.copyResize(
    paper,
    width: w,
    height: h,
    interpolation: img.Interpolation.linear,
  );

  final around = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      around[y * w + x] = spread.getPixel(x, y).r.toInt();
    }
  }

  // Only print on the sticker counts. Against bark, a stone wall or a rough
  // concrete pole, "darker than its surroundings" was true all over the
  // photo: every pit and crack came through as a letter-sized mark in the
  // column, the row came out a jumble and the scan read nothing at all. Two
  // things tell print apart from that. It sits on the whitest thing in the
  // photo, which a pole or a wall is not; and it is black on white, far
  // darker than its paper, where a pit in grey stone is only a shade darker.
  final paperFloor = _whitest(paper) * _paperShare;

  final strips = <Uint8List>[];
  var cutOff = false;

  for (final rule in _InkRule.values) {
    final careful = rule == _InkRule.careful;

    final ink = Uint8List(w * h);
    for (var i = 0; i < w * h; i++) {
      final paperHere = around[i];
      final dark = paperHere - lum[i] > _inkDepth;
      ink[i] =
          dark &&
              (!careful ||
                  (paperHere >= paperFloor && lum[i] < paperHere * _inkShare))
          ? 1
          : 0;
    }

    final read = _stripOf(ink, w, h);
    // Asked of the careful reading only: the plain one lets the wall in, and
    // the wall runs off every edge of the photo.
    if (careful) cutOff = read.cutOff;
    if (read.strip != null) strips.add(read.strip!);
  }

  return (strips: strips, cutOff: cutOff);
}

/// The letters found in one reading of the ink, stood in a row.
({Uint8List? strip, bool cutOff}) _stripOf(Uint8List raw, int w, int h) {
  // The unshrunk threshold is kept: the letters are drawn from it later, at
  // their full weight, while the shrunk one is what they are found with.
  final ink = _lettersOnly(_shrinkAway(raw, w, h), w, h);

  const nothing = (strip: null, cutOff: false);

  final bands = _bands(ink, w, h);
  if (bands.length < 3 || bands.length > 12) return nothing;

  final boxes = <_Box>[];
  for (final band in bands) {
    final box = _boxOf(ink, w, h, band);
    if (box == null) return nothing;
    boxes.add(box);
  }

  if (!_looksStacked(boxes, w)) return nothing;

  return (
    strip: img.encodePng(_row(raw, w, boxes)),
    cutOff: _touchesEdge(ink, w, h, boxes),
  );
}

/// Whether a letter of the code runs into the top or bottom of the photo.
///
/// Asked only once a code has been found, and only of the columns its letters
/// stand in. Asked of the whole photo, a wire across the top corner or a crack
/// in the pole running off the bottom told him to step back from a sticker
/// that was already whole in the frame. The outermost row is always blank
/// after `_shrinkAway`, so the edge is taken as the first few rows rather than
/// the very first.
bool _touchesEdge(Uint8List ink, int w, int h, List<_Box> boxes) {
  const edge = 3;
  final left = boxes.map((b) => b.left).reduce(min);
  final right = boxes.map((b) => b.right).reduce(max);

  for (var y = 0; y < h; y++) {
    if (y >= edge && y < h - edge) continue;
    for (var x = left; x < right; x++) {
      if (ink[y * w + x] == 1) return true;
    }
  }
  return false;
}

/// How white the paper round a mark has to be, as a share of the whitest
/// paper in the photo. The sticker is the whitest thing there; the pole and
/// the wall beside it are grey.
const double _paperShare = 0.6;

/// How dark a mark has to be, as a share of its paper. Black print on white
/// is a fifth of it or less; a pit in stone or bark is most of it.
const double _inkShare = 0.55;

/// The whitest paper in the photo - not the single brightest square, which
/// can be a glint of sun, but the one brighter than nineteen in twenty.
double _whitest(img.Image paper) {
  final values = <int>[
    for (final p in paper) p.r.toInt(),
  ]..sort();
  return values[(values.length * 0.95).floor().clamp(0, values.length - 1)]
      .toDouble();
}

/// The photo with the print taken off it, at one pixel per square.
img.Image _paper(Uint8List lum, int w, int h) {
  final across = max(1, (w / _paperBlock).ceil());
  final down = max(1, (h / _paperBlock).ceil());
  final paper = img.Image(width: across, height: down, numChannels: 1);

  for (var by = 0; by < down; by++) {
    for (var bx = 0; bx < across; bx++) {
      var lightest = 0;

      final toY = min(h, (by + 1) * _paperBlock);
      final toX = min(w, (bx + 1) * _paperBlock);

      for (var y = by * _paperBlock; y < toY; y++) {
        for (var x = bx * _paperBlock; x < toX; x++) {
          final v = lum[y * w + x];
          if (v > lightest) lightest = v;
        }
      }

      paper.setPixel(bx, by, img.ColorUint8.rgb(lightest, lightest, lightest));
    }
  }

  // Each square widened to the whitest of its neighbours - see `_paperBlock`.
  final wide = img.Image(width: across, height: down, numChannels: 1);
  for (var by = 0; by < down; by++) {
    for (var bx = 0; bx < across; bx++) {
      var lightest = 0;
      for (var ny = max(0, by - 1); ny <= min(down - 1, by + 1); ny++) {
        for (var nx = max(0, bx - 1); nx <= min(across - 1, bx + 1); nx++) {
          final v = paper.getPixel(nx, ny).r.toInt();
          if (v > lightest) lightest = v;
        }
      }
      wide.setPixel(bx, by, img.ColorUint8.rgb(lightest, lightest, lightest));
    }
  }

  return wide;
}

/// Drops anything too thin to be part of a letter.
///
/// A speck of dust on the sticker, a mark on the wall and the grain of the
/// paper all come through the threshold. None of them survives this: a pixel
/// is kept only when all eight of its neighbours are ink too, which a speck
/// never manages and the middle of a stroke always does.
Uint8List _shrinkAway(Uint8List ink, int w, int h) {
  final out = Uint8List(w * h);

  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      if (ink[i] == 0) continue;

      if (ink[i - w - 1] == 1 &&
          ink[i - w] == 1 &&
          ink[i - w + 1] == 1 &&
          ink[i - 1] == 1 &&
          ink[i + 1] == 1 &&
          ink[i + w - 1] == 1 &&
          ink[i + w] == 1 &&
          ink[i + w + 1] == 1) {
        out[i] = 1;
      }
    }
  }

  return out;
}

/// Keeps only the marks shaped like a printed letter, and wipes everything else.
///
/// The letters are found by the blank rows between them, and on a white
/// background that is all there is. Off one - a sticker on wood, on a pole, a
/// laptop in the corner of the frame - the edge of the sticker against the
/// background came through as one dark line from top to bottom, the grain as
/// dark patches, and between them there was no blank row left anywhere in the
/// photo. The whole picture read as one letter and the scan found nothing.
///
/// So each separate mark is judged on its own first. A letter is no taller
/// than a quarter of the photo, no wider than half as much again as it is
/// tall, and sits in the same column as the other letters. The sticker's edge
/// is too tall, the laptop too big, the grain and a cable off to one side are
/// out of the column.
Uint8List _lettersOnly(Uint8List ink, int w, int h) {
  final owner = Int32List(w * h)..fillRange(0, w * h, -1);
  final marks = <_Box>[];
  final stack = <int>[];

  for (var start = 0; start < w * h; start++) {
    if (ink[start] == 0 || owner[start] >= 0) continue;

    final id = marks.length;
    var left = w, top = h, right = 0, bottom = 0;

    owner[start] = id;
    stack.add(start);

    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      final x = i % w;
      final y = i ~/ w;

      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;

      for (var dy = -1; dy <= 1; dy++) {
        final ny = y + dy;
        if (ny < 0 || ny >= h) continue;
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx;
          if (nx < 0 || nx >= w) continue;
          final n = ny * w + nx;
          if (ink[n] == 1 && owner[n] < 0) {
            owner[n] = id;
            stack.add(n);
          }
        }
      }
    }

    marks.add(_Box(left, top, right + 1, bottom + 1));
  }

  final shortest = max(4, (h * 0.02).round());
  final tallest = h * 0.25;

  final letters = <int>{};
  for (var id = 0; id < marks.length; id++) {
    final m = marks[id];
    if (m.height >= shortest &&
        m.height <= tallest &&
        m.width <= m.height * 1.5) {
      letters.add(id);
    }
  }
  if (letters.isEmpty) return Uint8List(w * h);

  // The column: where the letters' middles cluster, and how far a letter may
  // stray from it - a letter's own height, which allows for a sticker held a
  // little crooked.
  final centres = letters.map((id) => marks[id].centre).toList()..sort();
  final heights = letters.map((id) => marks[id].height).toList()..sort();
  final column = centres[centres.length ~/ 2];
  final stray = heights[heights.length ~/ 2];

  letters.removeWhere((id) => (marks[id].centre - column).abs() > stray);

  final out = Uint8List(w * h);
  for (var i = 0; i < w * h; i++) {
    if (owner[i] >= 0 && letters.contains(owner[i])) out[i] = 1;
  }
  return out;
}

/// The runs of rows that have ink in them - one per letter, on a stacked tag.
List<({int top, int bottom})> _bands(Uint8List ink, int w, int h) {
  final bands = <({int top, int bottom})>[];
  final floor = max(2, h ~/ 400);

  int? start;
  for (var y = 0; y < h; y++) {
    var count = 0;
    for (var x = 0; x < w; x++) {
      count += ink[y * w + x];
    }

    final on = count > floor;
    if (on && start == null) {
      start = y;
    } else if (!on && start != null) {
      bands.add((top: start, bottom: y));
      start = null;
    }
  }
  if (start != null) bands.add((top: start, bottom: h));

  // Anything shorter than this is a scratch, not a printed character.
  final shortest = max(4, (h * 0.02).round());
  final kept = bands.where((b) => b.bottom - b.top >= shortest).toList();
  if (kept.isEmpty) return kept;

  // Then judged against each other rather than against the frame. The letters
  // of one code are all the same size of print, so a band half the height of
  // the rest is the top of a letter cut off by the edge of the photo, or a mark
  // on the wall - either way not a character, and stood in the row it would
  // read as one.
  final heights = kept.map((b) => b.bottom - b.top).toList()..sort();
  final middle = heights[heights.length ~/ 2];

  return kept
      .where(
        (b) =>
            b.bottom - b.top >= middle * 0.45 &&
            b.bottom - b.top <= middle * 2.2,
      )
      .toList();
}

class _Box {
  const _Box(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left;
  int get height => bottom - top;
  double get centre => (left + right) / 2;
}

/// The letter in a band, and not whatever else shares those rows with it.
///
/// Taking the full width of the ink would do if the sticker were the only thing
/// in the photo. It is not: a mark on the wall level with the letter P stretched
/// its box from one edge of the frame to the other, which then failed the
/// "as wide as it is tall" test below and lost the whole read.
_Box? _boxOf(Uint8List ink, int w, int h, ({int top, int bottom}) band) {
  final columns = List<int>.filled(w, 0);
  for (var y = band.top; y < band.bottom; y++) {
    for (var x = 0; x < w; x++) {
      columns[x] += ink[y * w + x];
    }
  }

  // The runs: each one a stretch of columns with ink in it.
  final runs = <({int left, int right, int weight})>[];

  var left = -1;
  var right = -1;
  var weight = 0;

  for (var x = 0; x < w; x++) {
    if (columns[x] == 0) {
      if (left >= 0) runs.add((left: left, right: right, weight: weight));
      left = -1;
      right = -1;
      weight = 0;
      continue;
    }

    if (left < 0) left = x;
    right = x + 1;
    weight += columns[x];
  }
  if (left >= 0) runs.add((left: left, right: right, weight: weight));
  if (runs.isEmpty) return null;

  // Runs are gathered into letters before they are weighed. A letter is not one
  // solid run of columns - an N breaks into its two uprights and its diagonal,
  // and taking the heaviest run alone kept a third of the letter and threw the
  // rest away. Anything nearer than about a third of the letter's height
  // belongs to the same character; the next character is a whole line away.
  final reach = max(2, (band.bottom - band.top) ~/ 3);

  var group = <({int left, int right, int weight})>[];
  var best = <({int left, int right, int weight})>[];
  var bestWeight = -1;
  var groupWeight = 0;

  void close() {
    if (groupWeight > bestWeight) {
      bestWeight = groupWeight;
      best = group;
    }
    group = [];
    groupWeight = 0;
  }

  for (final run in runs) {
    if (group.isNotEmpty && run.left - group.last.right > reach) close();
    group.add(run);
    groupWeight += run.weight;
  }
  close();

  if (best.isEmpty) return null;

  // The ends trimmed of anything too thin to be part of a letter. A selection
  // box drawn round the text put a two-pixel bar down each side of every
  // letter, near enough to be swept into the same group, and the row came out
  // as N|N|P|Q|6 - which matches no tag. A printed stroke at this size is
  // several pixels across; a ruled line is not.
  final slender = max(1, (band.bottom - band.top) ~/ 8);
  while (best.length > 1 && best.first.right - best.first.left <= slender) {
    best = best.sublist(1);
  }
  while (best.length > 1 && best.last.right - best.last.left <= slender) {
    best = best.sublist(0, best.length - 1);
  }

  final boxLeft = best.first.left;
  final boxRight = best.last.right;

  // Then given back whatever the band clipped off. A band ends at the first row
  // with almost no ink in it, and the thin stem at the foot of an F can fall
  // under that where the photo is shaded - which cost the bottom third of an F
  // and had it read as an E. Once the letter's own columns are known the rest
  // of it can be followed up and down without the rest of the photo getting in.
  var top = band.top;
  while (top > 0 && _inkInRow(ink, w, top - 1, boxLeft, boxRight)) {
    top--;
  }

  var bottom = band.bottom;
  while (bottom < h && _inkInRow(ink, w, bottom, boxLeft, boxRight)) {
    bottom++;
  }

  return _Box(boxLeft, top, boxRight, bottom);
}

bool _inkInRow(Uint8List ink, int w, int y, int left, int right) {
  for (var x = left; x < right; x++) {
    if (ink[y * w + x] == 1) return true;
  }
  return false;
}

/// Whether these really are letters stacked one above another.
///
/// This guard matters more than the rebuilding does. Everything that reaches
/// the recogniser normally - a code printed across, a label, a page - has to be
/// left alone, and the test for that is the shape of the thing: a stacked code
/// is a narrow column of characters sitting one under the next, each about as
/// wide as it is tall, all lined up on the same centre.
bool _looksStacked(List<_Box> boxes, int w) {
  for (final box in boxes) {
    // A line of writing rather than a single character.
    if (box.width > box.height * 3) return false;
  }

  final centres = boxes.map((b) => b.centre).toList();
  final leftmost = centres.reduce(min);
  final rightmost = centres.reduce(max);

  // Wandering left and right means separate things scattered about the photo,
  // not one code running down it.
  return rightmost - leftmost <= w * 0.25;
}

/// The letters stood in a row: black on white, nothing else in the picture.
///
/// Drawn from the ink rather than cut out of the photo. Cutting worked - the
/// letters came out whole and in order - but each one carried its own patch of
/// the wall with it, a different shade from its neighbours, and against that
/// patchwork the recogniser read the F of NNPQF as an E. Print is black on
/// white, so that is what it is handed.
img.Image _row(Uint8List ink, int w, List<_Box> boxes) {
  final tall = boxes.map((b) => b.height).reduce(max);
  final gap = max(4, tall ~/ 3);
  final margin = max(6, tall ~/ 2);

  final width =
      boxes.fold(0, (sum, b) => sum + b.width) +
      gap * (boxes.length - 1) +
      margin * 2;

  final strip = img.Image(
    width: width,
    height: tall + margin * 2,
    numChannels: 1,
  );
  img.fill(strip, color: img.ColorUint8.rgb(255, 255, 255));

  final black = img.ColorUint8.rgb(0, 0, 0);
  var x = margin;

  for (final box in boxes) {
    // Sat on a common baseline rather than a common top. A letter that came out
    // a little short belongs level with the feet of the others, not their
    // heads.
    final top = margin + (tall - box.height);

    for (var y = box.top; y < box.bottom; y++) {
      for (var sx = box.left; sx < box.right; sx++) {
        if (ink[y * w + sx] == 1) {
          strip.setPixel(x + sx - box.left, top + y - box.top, black);
        }
      }
    }

    x += box.width + gap;
  }

  return strip;
}
