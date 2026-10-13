import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:np_pole_tag_stickerman/providers/api_providers.dart';
import 'package:np_pole_tag_stickerman/services/api_exception.dart';
import 'package:np_pole_tag_stickerman/services/csv_export.dart';

/// Which download is running, if any.
///
/// The batch id of the one in flight, or [everything] for the whole-history
/// file. One at a time: the buttons disable while it runs, so two taps cannot
/// put two files into the share sheet at once.
class ExportState {
  /// Stands for "no batch named" - the file covering all of them. Negative so
  /// it can never collide with a real batch id.
  static const int everything = -1;

  final int? running;

  const ExportState({this.running});

  bool get isBusy => running != null;

  bool isRunning(int? batchId) => running == (batchId ?? everything);
}

class ExportNotifier extends StateNotifier<ExportState> {
  ExportNotifier(this._ref) : super(const ExportState());

  final Ref _ref;

  final _export = const CsvExport();

  /// Fetches the file and opens the share sheet on it.
  ///
  /// Returns the reason it failed, or null when it worked. Handed back rather
  /// than held in the state: a failed download is a sentence to put in front of
  /// him once, not a condition the screen stays in - and the screen is the only
  /// thing that can show a snack bar.
  Future<String?> download({int? batchId, Rect? origin}) async {
    if (state.isBusy) return null;

    state = ExportState(running: batchId ?? ExportState.everything);

    try {
      final file = await _ref
          .read(apiProvider)
          .downloadMyPolesCsv(batchId: batchId);

      await _export.share(
        bytes: file.bytes,
        filename: file.filename,
        subject: batchId == null
            ? 'My tagged poles'
            : 'Tagged poles - ${file.filename.replaceAll('.csv', '')}',
        origin: origin,
      );

      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      // Writing the file or opening the share sheet, rather than the request.
      // Rare, and nothing he can act on beyond trying again.
      return 'Could not save the file. Please try again.';
    } finally {
      state = const ExportState();
    }
  }
}

final exportProvider = StateNotifierProvider<ExportNotifier, ExportState>(
  (ref) => ExportNotifier(ref),
);
