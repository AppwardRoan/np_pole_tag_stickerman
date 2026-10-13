import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/models/form_options.dart';
import 'package:np_pole_tag_stickerman/providers/api_providers.dart';
import 'package:np_pole_tag_stickerman/services/form_options_cache.dart';

final formOptionsCacheProvider = Provider<FormOptionsCache>(
  (ref) => const FormOptionsCache(),
);

/// The choices the form offers, read off the phone.
///
/// Deliberately never calls the server. It is read at the pole, where waiting
/// out a 30-second timeout before falling back to the phone would be the whole
/// delay for nothing. [refreshFormOptions] is what fetches, and it runs on the
/// tag list where there is still signal.
///
/// Null means nothing has been saved yet - a handset that has never been
/// online. The screen says so rather than showing an empty form.
final formOptionsProvider = FutureProvider<FormOptions?>((ref) {
  return ref.read(formOptionsCacheProvider).read();
});

/// Fetches the choices and writes them to the phone.
///
/// Called from the tag list, alongside the tags: that screen opens at the
/// office with wifi and again at every pole, so this rides on the one moment
/// signal is likely. Failure is silent on purpose - the phone's copy is the
/// answer either way, and there is nothing he could do about it at a pole.
Future<void> refreshFormOptions(WidgetRef ref) async {
  try {
    final fresh = await ref.read(apiProvider).getFormOptions();
    await ref.read(formOptionsCacheProvider).save(fresh);
    ref.invalidate(formOptionsProvider);
  } catch (_) {
    // No signal, or the server is down. Whatever is on the phone stands.
  }
}
