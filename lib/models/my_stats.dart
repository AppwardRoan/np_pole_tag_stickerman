/// The figures across the top of the home screen, as
/// `GET /stats/stickerman` reports them.
///
/// Counted by the server rather than by the phone, and that is the whole
/// reason this exists. The screen used to total the lists in [MyTags], which
/// was right only while his whole history fit under the server's cap - past it
/// the tiles reported the cap and stopped moving, so the man who had done the
/// most work read his own day short. The bundle figures were never in that
/// reply at all.
///
/// Numbers only. The words - "1 of 2", ONGOING against DONE - are written on
/// the screen, the same division the server keeps for every other stat call.
class MyStats {
  /// Stickers he has accepted and not yet put on a pole.
  ///
  /// Accepted alone. A sticker the office has sent out but he has not claimed
  /// is not in here, because the tile sits directly above the list and the
  /// list draws the same set - counting it would put a figure over a tab that
  /// does not hold it. Those are [awaitingBatches] instead.
  final int assigned;

  /// Stickers on poles, as far as the server knows. A pole he filed with no
  /// signal is still counted under [assigned] here until the queue drains.
  final int completed;

  /// Of those, the ones he filed today - counted from midnight in Manila
  /// rather than the server's own midnight, which falls at eight in the
  /// morning here.
  ///
  /// The figure the bar leads with, because at three in the afternoon the
  /// number he wants is his day, not his year. Carries the same caveat as
  /// [completed]: a pole still in the queue is not in here, and the header
  /// adds the queue back on.
  final int completedToday;

  /// Envelopes the office has sent out that he has not yet claimed.
  ///
  /// Batches rather than stickers, because that is the unit of the tap: one
  /// Accept claims a whole share. The strip under the header counts these.
  ///
  /// Read from here rather than from the accept screen's own endpoint. The
  /// strip has to know whether to draw at all, and asking for the list every
  /// time the app opens is a request per morning to be told "nothing" - the
  /// answer on most of them. The list itself is fetched on the tap.
  final int awaitingBatches;

  /// Bundles any of his stickers came out of.
  final int batchesTotal;

  /// How many of those are finished.
  final int batchesDone;

  const MyStats({
    this.assigned = 0,
    this.completed = 0,
    this.completedToday = 0,
    this.awaitingBatches = 0,
    this.batchesTotal = 0,
    this.batchesDone = 0,
  });

  static const MyStats empty = MyStats();

  /// Something is out with him that he has not said he is holding.
  bool get hasWaitingBatches => awaitingBatches > 0;

  /// Nothing has been handed to him yet - a new hire's first morning.
  bool get hasNoBatches => batchesTotal == 0;

  /// Every bundle he holds is finished. False when he holds none, because
  /// "done" would be claiming he finished something.
  bool get allBatchesDone => batchesTotal > 0 && batchesDone == batchesTotal;

  factory MyStats.fromJson(Map<String, dynamic> json) {
    // Each read falls back to zero on its own rather than the whole reply
    // failing on one missing key: a tile showing 0 is wrong in one corner,
    // where a thrown error is a header that does not draw at all.
    int read(String key) {
      final value = json[key];
      return value is int ? value : 0;
    }

    return MyStats(
      assigned: read('assigned'),
      completed: read('completed'),
      // Absent from anything this phone cached before the field existed, and
      // zero is the right answer to that: the reply it was saved from could
      // not have told us. It is right again within one refresh.
      completedToday: read('completed_today'),
      awaitingBatches: read('awaiting_batches'),
      batchesTotal: read('batches_total'),
      batchesDone: read('batches_done'),
    );
  }

  /// For the cache. The header is the first thing drawn when the app opens,
  /// which is regularly somewhere with no signal - the last known figures
  /// beat three blanks.
  Map<String, dynamic> toJson() {
    return {
      'assigned': assigned,
      'completed': completed,
      'completed_today': completedToday,
      'awaiting_batches': awaitingBatches,
      'batches_total': batchesTotal,
      'batches_done': batchesDone,
    };
  }
}
