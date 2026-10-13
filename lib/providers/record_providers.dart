import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/models/pole_record.dart';
import 'package:np_pole_tag_stickerman/providers/api_providers.dart';

/// Every record filed against one pole, fetched when he opens it.
///
/// A family keyed by tag id, so opening two poles in a row does not hand the
/// second one the first one's answer.
///
/// `autoDispose`, and that word is the whole of the fix it carries. Without it
/// the answer was kept for the life of the app: the first read of a pole was
/// the only read, on the grounds that what the office holds against a finished
/// pole does not change. That was true until a pole could be sent back. Now
/// every rework files another record and moves which one is live - so a man
/// who had opened that pole once was shown a replaced record with CURRENT
/// against it, and nothing on the sheet could have told him otherwise.
///
/// Dropping the cache when the sheet closes costs one request per open, which
/// is what this was always meant to be: the office's copy, asked for rather
/// than remembered. Without signal the sheet says so, and that is the honest
/// answer - a stale record read back offline would be this app agreeing with
/// itself.
///
/// Newest first, the order the server sends. The live record is the one flagged
/// `isCurrent`; the rest are the attempts it replaced.
final tagRecordsProvider = FutureProvider.autoDispose
    .family<List<PoleRecord>, int>((ref, tagId) {
      return ref.read(apiProvider).getTagRecords(tagId);
    });
