import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/providers/auth_providers.dart';
import 'package:np_pole_tag_stickerman/providers/awaiting_receipt_providers.dart';
import 'package:np_pole_tag_stickerman/providers/batch_tag_providers.dart';
import 'package:np_pole_tag_stickerman/providers/form_options_providers.dart';
import 'package:np_pole_tag_stickerman/providers/my_batch_providers.dart';
import 'package:np_pole_tag_stickerman/providers/search_providers.dart';
import 'package:np_pole_tag_stickerman/providers/tag_providers.dart';

/// Signs the man out and takes everything of his off the handset with him.
///
/// One place on purpose. This used to be a list written out at the logout
/// button, added to whenever a screen got built, and what it did not mention
/// simply stayed: the search kept its own copy of the results, so the next man
/// to sign in landed on a home screen showing the last man's tags - with the
/// header above it reading his own count of zero. My Work had the same hole.
///
/// A screen that keeps the signed-in man's data adds its line here. Nowhere
/// else knows the full list, so nowhere else can be the one that forgets.
Future<void> signOut(WidgetRef ref) async {
  await clearUserData(ref.read);

  // Last, so nothing above runs against a handset that is already signed out.
  await ref.read(authProvider.notifier).logout();
}

/// `ref.read`, from either a widget or a provider.
typedef Reader = T Function<T>(ProviderListenable<T> provider);

/// Everything of the last man's that [signOut] takes off the handset.
///
/// Split out so the sign-outs nobody tapped - a login the server no longer
/// accepts, or the Crew role taken away - wipe the same list. They used to
/// skip it, so the next man to sign in on that phone saw the last man's tags.
Future<void> clearUserData(Reader read) async {
  // His tags, and the pick-lists whose ids belong to one utility.
  await read(tagProvider.notifier).clear();
  await read(formOptionsCacheProvider).clear();

  // The batches, on the phone and on screen. Both: the cache alone leaves what
  // My Work has already loaded sitting in front of the next man.
  await read(batchCacheProvider).clear();
  read(batchTagProvider.notifier).clear();
  read(myBatchProvider.notifier).clear();

  // The search holds its own copy of whatever it found, so clearing the list
  // it copied from does not touch it.
  read(searchProvider.notifier).clear();

  // The envelopes waiting to be accepted, on the phone and on screen. Both:
  // the cache alone leaves what the accept screen has already loaded sitting
  // in front of the next man, offering him an Accept button on another man's
  // paper.
  await read(awaitingReceiptProvider.notifier).clear();

  // Deliberately kept: his unfinished forms and anything still waiting to
  // reach the office. Those are work he has done, not a view of someone's
  // data, and throwing them away on a sign-out would lose poles.
}
