import 'package:flutter/material.dart';

/// Which of the two palettes the app is wearing.
///
/// [indoor] is the mockup, exactly as the design drew it. [sunlight] is the
/// same design walked up to the highest contrast a phone can manage, for a
/// man reading the screen with the sun on it.
enum PaletteMode {
  indoor,
  sunlight;

  bool get isSunlight => this == PaletteMode.sunlight;
}

/// One complete set of colours.
///
/// Two of these exist - [indoorPalette] and [sunlightPalette] - and the app
/// wears one at a time. Every field is named for what it *does*, never for
/// what it looks like, so the same name can be a soft grey in one palette and
/// nearly black in the other and no screen has to care which.
@immutable
class Palette {
  const Palette({
    required this.deepGreen,
    required this.deeperGreen,
    required this.greenSurface,
    required this.greenLine,
    required this.actionGreen,
    required this.midGreen,
    required this.paleGreen,
    required this.mutedGreen,
    required this.onGreen,
    required this.page,
    required this.card,
    required this.ink,
    required this.muted,
    required this.line,
    required this.fieldLine,
    required this.amber,
    required this.danger,
    required this.dangerWash,
    required this.greenWash,
    required this.trough,
    required this.chipBlueWash,
    required this.chipBlueLine,
    required this.chipBlueInk,
    required this.chipGreenWash,
    required this.chipGreenLine,
    required this.chipGreenInk,
    required this.chipAmberWash,
    required this.chipAmberLine,
    required this.chipAmberInk,
    required this.chipSlateWash,
    required this.chipSlateLine,
    required this.chipSlateInk,
    required this.chipRedWash,
    required this.chipRedLine,
    required this.chipRedInk,
  });

  /// The brand green. Login, headers, anything that carries the name.
  final Color deepGreen;

  /// One step off [deepGreen] - the quiet shapes behind the login, and any
  /// panel that sits on green without wanting to be noticed.
  final Color deeperGreen;

  /// Fills on green: the box behind an icon, an inset panel.
  final Color greenSurface;

  /// A line on green, where a border has to be felt rather than seen.
  final Color greenLine;

  /// The green that means "do this" - the primary button.
  final Color actionGreen;

  /// The same idea on a light screen, where [actionGreen] is too pale to
  /// carry white text.
  final Color midGreen;

  /// Small uppercase labels on green, and any text that must stay quiet
  /// without disappearing.
  final Color paleGreen;

  /// Quieter still: the sentence under a heading, on green.
  final Color mutedGreen;

  /// Text on green.
  final Color onGreen;

  /// The screen behind the light pages - the tag list, the form.
  final Color page;

  /// Panels on [page].
  final Color card;

  /// Body text on a light screen.
  final Color ink;

  /// Small print and captions on a light screen.
  final Color muted;

  /// Borders and dividers on a light screen.
  final Color line;

  /// A field's border, which has to read as an edge he can tap into.
  final Color fieldLine;

  /// Work finished, and the scan button. Picked out from the other two
  /// figures because it is the one that goes up as his day goes on.
  final Color amber;

  /// Something is wrong, and the wash it sits on.
  final Color danger;
  final Color dangerWash;

  /// The strip behind "3 tags waiting to upload".
  final Color greenWash;

  /// The trough behind the tabs, and the "showing 20 of 40" strip.
  final Color trough;

  // The status chips, in five families: a pale fill, a line of the same hue,
  // and ink dark enough to read at arm's length.
  //
  // A pale chip with pale lettering - which is what the design draws and what
  // Material's own container colours give - is the first thing to vanish when
  // the display washes out. Dark ink on a light fill keeps the widest gap in
  // brightness there is, and the line keeps the chip's shape once the fill
  // has gone.
  //
  // Solid, saturated chips would read just as well. They are not used because
  // Dispatched sits on every row of the list, and twenty solid blocks stop
  // being a signal.

  /// Dispatched - the office has handed it over.
  final Color chipBlueWash;
  final Color chipBlueLine;
  final Color chipBlueInk;

  /// Used - on a pole, finished.
  final Color chipGreenWash;
  final Color chipGreenLine;
  final Color chipGreenInk;

  /// A draft - his own unfinished work.
  final Color chipAmberWash;
  final Color chipAmberLine;
  final Color chipAmberInk;

  /// Filed and still on the phone. Deliberately colourless: nothing is wrong
  /// and nothing is owed - it is simply on its way.
  final Color chipSlateWash;
  final Color chipSlateLine;
  final Color chipSlateInk;

  /// A pole the office has sent back.
  ///
  /// Red because something about it was found wrong, which is not the same as
  /// a draft he has not finished - and the amber above is spoken for.
  final Color chipRedWash;
  final Color chipRedLine;
  final Color chipRedInk;
}

/// The design as drawn.
///
/// Lifted from the Stickerman mockup rather than invented, so the phone and
/// the design agree. This is the one to compare against: if a screen looks
/// wrong in sunlight, it is this that it is supposed to look like.
const Palette indoorPalette = Palette(
  deepGreen: Color(0xFF0D3A22),
  deeperGreen: Color(0xFF0B3420),
  greenSurface: Color(0xFF124B2B),
  greenLine: Color(0xFF1A5C36),
  actionGreen: Color(0xFF4FBD7C),
  midGreen: Color(0xFF186235),
  paleGreen: Color(0xFFA9D8B9),
  mutedGreen: Color(0xFF7FAE93),
  onGreen: Color(0xFFEAF4EE),
  page: Color(0xFFF4F6F9),
  card: Color(0xFFFFFFFF),
  ink: Color(0xFF131C26),
  muted: Color(0xFF6B7684),
  line: Color(0xFFE4E8EE),
  fieldLine: Color(0xFFC6CCD6),
  amber: Color(0xFFE0A82E),
  danger: Color(0xFF9C2F1D),
  dangerWash: Color(0xFFFDEFEC),
  greenWash: Color(0xFFEAF4ED),
  trough: Color(0xFFE8EDF3),
  chipBlueWash: Color(0xFFDDE8FB),
  chipBlueLine: Color(0xFFB4CBEE),
  chipBlueInk: Color(0xFF10367C),
  chipGreenWash: Color(0xFFD8EEE0),
  chipGreenLine: Color(0xFFA9D8B9),
  chipGreenInk: Color(0xFF0D3A22),
  chipAmberWash: Color(0xFFFAEBCB),
  chipAmberLine: Color(0xFFE4C87F),
  chipAmberInk: Color(0xFF5C4406),
  chipSlateWash: Color(0xFFE3E8EF),
  chipSlateLine: Color(0xFFC2CBD8),
  chipSlateInk: Color(0xFF2A3644),
  chipRedWash: Color(0xFFFDEFEC),
  chipRedLine: Color(0xFFEFB9AE),
  chipRedInk: Color(0xFF9C2F1D),
);

/// The same design, for a screen with the sun on it.
///
/// Sunlight falling on the glass adds its own light to everything shown,
/// which lifts the blacks and leaves the whites where they are. Two colours
/// that sat eight stops apart at a desk sit one and a half apart on a pole at
/// noon. So the greens went darker, the pale text went paler, and the greys
/// that carried small print went nearly black.
///
/// The ceiling out there is about 2.2 - black on white, the widest gap a
/// phone can make in sun - and every pair below is walked as close to it as
/// it can get without the app turning into a wireframe.
///
/// Anything that is only decoration - a tint behind a panel, a hairline on
/// green - is not walked up. It is accepted that it disappears, which is why
/// nothing here is allowed to *mean* anything by tint alone.
const Palette sunlightPalette = Palette(
  // Darker than the mockup: this is the ground under every pale thing in the
  // header, so lowering it raises all of them at once.
  deepGreen: Color(0xFF06210F),
  deeperGreen: Color(0xFF031508),
  greenSurface: Color(0xFF103D22),
  greenLine: Color(0xFF2E7A4C),
  // Lighter than the mockup, because it carries dark text and the gap
  // between the two is what has to survive.
  actionGreen: Color(0xFF8CE5AF),
  midGreen: Color(0xFF14582F),
  // "Quiet" outdoors cannot mean "dim" - a dim thing on green is a gone
  // thing. It means small and spaced instead.
  paleGreen: Color(0xFFD9EFE1),
  // The old #7FAE93 was the first casualty of the sun: the "Updated 9:42 AM"
  // line went to nothing. There is barely room below paleGreen out there, so
  // this is only a shade under it.
  mutedGreen: Color(0xFFC7E3D2),
  onGreen: Color(0xFFFFFFFF),
  // White, where the mockup had a faint grey. The grey separated the page
  // from the cards on it, which is a distinction the sun erases anyway, and
  // white is the brightest thing the display can do. Cards are told apart by
  // their line now, not by their fill.
  page: Color(0xFFFFFFFF),
  card: Color(0xFFFFFFFF),
  ink: Color(0xFF000000),
  // Not really muted any more. It carries the line under every tag code in
  // forty-odd places, and at the old #6B7684 every one washed out. Small
  // print is made quiet here by being small, not by being faint.
  muted: Color(0xFF39424F),
  // Load-bearing. With the page and the cards both white, this line is the
  // only thing saying where one row stops and the next begins.
  line: Color(0xFFB9C2CE),
  fieldLine: Color(0xFF7E8896),
  // Lighter than the mockup, to widen the gap under the dark label on the
  // scan button - the one control he must find without looking.
  amber: Color(0xFFFFCE4D),
  danger: Color(0xFF7A1F0F),
  dangerWash: Color(0xFFFBDBD3),
  // A two-percent tint is a white band outdoors, and this strip is the only
  // thing telling him his morning's work has not left the phone yet.
  greenWash: Color(0xFFD7EBDE),
  trough: Color(0xFFDCE3EB),
  // Each line below is a good deal darker than the design draws it: every one
  // of these fills reads as white in direct sun, so the border is all that is
  // holding the chip's shape.
  chipBlueWash: Color(0xFFCADCF7),
  chipBlueLine: Color(0xFF3F6FBE),
  chipBlueInk: Color(0xFF0B2A66),
  chipGreenWash: Color(0xFFBFE4CC),
  chipGreenLine: Color(0xFF2F7A52),
  chipGreenInk: Color(0xFF06210F),
  chipAmberWash: Color(0xFFF7DFA6),
  chipAmberLine: Color(0xFF8F6F1E),
  chipAmberInk: Color(0xFF4A3400),
  chipSlateWash: Color(0xFFD2DAE4),
  chipSlateLine: Color(0xFF6B7A8C),
  chipSlateInk: Color(0xFF1B2530),
  chipRedWash: Color(0xFFFBDBD3),
  chipRedLine: Color(0xFFA85540),
  chipRedInk: Color(0xFF7A1F0F),
);

/// Every colour the app uses, in one place.
///
/// Nothing outside this file should write a colour literal: a screen asks the
/// theme, and the theme asks here.
///
/// These are getters onto [active] rather than constants, which is the one
/// concession the toggle costs. The palette can change while the app is
/// running, so a colour cannot be baked into a widget at compile time - which
/// is why a widget that reads one of these cannot be `const`.
abstract final class AppColors {
  /// The palette the app is wearing. Set from `main.dart` before the frame is
  /// built; nothing else should write it.
  static Palette active = sunlightPalette;

  static Color get deepGreen => active.deepGreen;
  static Color get deeperGreen => active.deeperGreen;
  static Color get greenSurface => active.greenSurface;
  static Color get greenLine => active.greenLine;
  static Color get actionGreen => active.actionGreen;
  static Color get midGreen => active.midGreen;
  static Color get paleGreen => active.paleGreen;
  static Color get mutedGreen => active.mutedGreen;
  static Color get onGreen => active.onGreen;
  static Color get page => active.page;
  static Color get card => active.card;
  static Color get ink => active.ink;
  static Color get muted => active.muted;
  static Color get line => active.line;
  static Color get fieldLine => active.fieldLine;
  static Color get amber => active.amber;
  static Color get danger => active.danger;
  static Color get dangerWash => active.dangerWash;
  static Color get greenWash => active.greenWash;
  static Color get trough => active.trough;
  static Color get chipBlueWash => active.chipBlueWash;
  static Color get chipBlueLine => active.chipBlueLine;
  static Color get chipBlueInk => active.chipBlueInk;
  static Color get chipGreenWash => active.chipGreenWash;
  static Color get chipGreenLine => active.chipGreenLine;
  static Color get chipGreenInk => active.chipGreenInk;
  static Color get chipAmberWash => active.chipAmberWash;
  static Color get chipAmberLine => active.chipAmberLine;
  static Color get chipAmberInk => active.chipAmberInk;
  static Color get chipSlateWash => active.chipSlateWash;
  static Color get chipSlateLine => active.chipSlateLine;
  static Color get chipSlateInk => active.chipSlateInk;
  static Color get chipRedWash => active.chipRedWash;
  static Color get chipRedLine => active.chipRedLine;
  static Color get chipRedInk => active.chipRedInk;
}

/// The two fonts, and the rule for which is which.
///
/// [body] is for words - headings, messages, buttons. [mono] is for anything
/// typed, counted or measured: tag codes, coordinates, accuracies, heights,
/// the figures in the header. A code in a proportional face is a code he can
/// misread, and `M2GG0` is exactly the string that must not be misread.
///
/// Both are bundled in `assets/fonts`, never fetched. He opens this app where
/// there is no signal.
abstract final class AppFonts {
  static const String body = 'Barlow';
  static const String mono = 'IBMPlexMono';
}

/// The app's theme, built from whichever palette is being worn.
///
/// Built by hand rather than from a seed colour: `ColorScheme.fromSeed` picks
/// its own greens, and the mockup already picked them.
abstract final class AppTheme {
  static ThemeData of(Palette p) {
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: p.midGreen,
      onPrimary: Colors.white,
      primaryContainer: p.deepGreen,
      onPrimaryContainer: p.onGreen,
      secondary: p.actionGreen,
      onSecondary: p.deepGreen,
      secondaryContainer: p.greenWash,
      onSecondaryContainer: p.deepGreen,
      tertiary: p.paleGreen,
      onTertiary: p.deepGreen,
      tertiaryContainer: p.greenWash,
      onTertiaryContainer: p.deepGreen,
      error: p.danger,
      onError: Colors.white,
      errorContainer: p.dangerWash,
      onErrorContainer: p.danger,
      surface: p.card,
      onSurface: p.ink,
      surfaceContainerLow: p.card,
      surfaceContainerHighest: p.trough,
      onSurfaceVariant: p.muted,
      outline: p.fieldLine,
      outlineVariant: p.line,
    );

    // Two sizes up across the app, asked for 2026-10-01: every size spelled
    // in a widget went up by two, and this takes the text that names no size
    // of its own - buttons, fields, hints - up by the same.
    //
    // From the Material 3 sizes directly. `ThemeData.textTheme` carries no
    // sizes until `Theme.of` fills them in, and `apply(fontSizeDelta:)` on
    // one without sizes is an assertion that stops the app from opening.
    //
    // The colours have to go back on by hand. Those sizes are sizes only,
    // and they replace the theme's own styles rather than merging into them -
    // left bare, every dialog title and message drew in no colour at all.
    final sizes = Typography.englishLike2021.apply(
      fontSizeDelta: 2,
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final onPrimarySizes = Typography.englishLike2021.apply(
      fontSizeDelta: 2,
      bodyColor: scheme.onPrimary,
      displayColor: scheme.onPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppFonts.body,
      scaffoldBackgroundColor: p.page,
      dividerTheme: DividerThemeData(color: p.line, space: 1),
      textTheme: sizes,
      primaryTextTheme: onPrimarySizes,
    );
  }
}
