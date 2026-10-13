import 'package:np_pole_tag_stickerman/helpers/parsing.dart';

/// One batch on the accept screen: paper out with him that he has not claimed.
///
/// The other half of [MyBatch]. That one answers "how far through my share am
/// I"; this one answers "what is waiting for me to say I have it". Both count
/// only the tags carrying his name - a run of two hundred is split across a
/// crew, so the batch's own quantity is three other men's paper as well.
class BatchAwaitingReceipt {
  final int batchId;
  final String batchCode;

  /// The job the office wrote on the batch - "JOB 14 / TALISAY".
  final String workOrderName;

  /// Tags in this batch that are his and still waiting for his tap.
  ///
  /// Not the batch's quantity, and not his whole share either: a batch he has
  /// half-accepted shows only what is left, which is what the one tap will
  /// move.
  final int myTags;

  /// When the crew collected the envelope.
  ///
  /// The clock the screen is showing: the list runs oldest first, and what
  /// makes a row urgent is how long the paper has been out with nobody
  /// admitting they hold it. Nullable only defensively - a batch reaches this
  /// list by being dispatched, and dispatching stamps it.
  final DateTime? dispatchedAt;

  const BatchAwaitingReceipt({
    required this.batchId,
    required this.batchCode,
    required this.workOrderName,
    required this.myTags,
    this.dispatchedAt,
  });

  factory BatchAwaitingReceipt.fromJson(Map<String, dynamic> json) {
    return BatchAwaitingReceipt(
      batchId: json['batch_id'] as int,
      batchCode: json['batch_code'] as String? ?? '',
      workOrderName: json['work_order_name'] as String? ?? '',
      myTags: json['my_tags'] as int? ?? 0,
      dispatchedAt: parseServerDate(json['dispatched_at']),
    );
  }

  /// For the cache. `dispatched_at` goes back as the server sent it - UTC with
  /// a Z - so reading it returns the same instant rather than one shifted by
  /// the device's offset a second time.
  Map<String, dynamic> toJson() => {
    'batch_id': batchId,
    'batch_code': batchCode,
    'work_order_name': workOrderName,
    'my_tags': myTags,
    'dispatched_at': dispatchedAt?.toUtc().toIso8601String(),
  };
}
