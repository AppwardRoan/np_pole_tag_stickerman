import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/config/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which palette the app is wearing, and remembering it between openings.
///
/// Sunlight is the default, because that is where the work happens. The
/// indoor palette is the design as drawn, kept for a desk and for showing the
/// app to somebody who is not standing in a field.
///
/// Persisted, because a man who has chosen sunlight once has chosen it for
/// the whole job, and asking him to choose again every morning is the same as
/// not having the switch.
class PaletteController extends StateNotifier<PaletteMode> {
  PaletteController() : super(PaletteMode.sunlight) {
    _restore();
  }

  static const _key = 'palette_mode';

  /// Read off the phone, not the server: he changes this standing in the sun
  /// with no signal.
  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);

    if (saved == PaletteMode.indoor.name) state = PaletteMode.indoor;
  }

  Future<void> toggle() async {
    state = state.isSunlight ? PaletteMode.indoor : PaletteMode.sunlight;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, state.name);
  }
}

final paletteProvider = StateNotifierProvider<PaletteController, PaletteMode>(
  (ref) => PaletteController(),
);

/// The colours themselves, so a widget can watch these rather than the mode.
final palettePickedProvider = Provider<Palette>((ref) {
  return ref.watch(paletteProvider).isSunlight
      ? sunlightPalette
      : indoorPalette;
});
