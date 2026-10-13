import 'package:np_pole_tag_stickerman/helpers/parsing.dart';

/// One batch on the My work screen: his share of it, not the batch.
///
/// A run of two hundred is split across a crew, so the batch's own quantity and
/// its Ongoing/Completed status answer a question he did not ask. [myTags] and
/// [myDone] count only the tags carrying his name.
class MyBatch {
  final int batchId;
  final String batchCode;

  /// The job the office wrote on the batch - "JOB 14 / TALISAY".
  final String workOrderName;

  /// Tags in this batch that are his, finished or not.
  final int myTags;

  /// How many of those he has filed.
  final int myDone;

  /// When he last filed a pole in this batch.
  ///
  /// Nullable only defensively: a batch reaches this screen because he
  /// finished something in it, so the server always has a date to send.
  final DateTime? lastDoneAt;

  const MyBatch({
    required this.batchId,
    required this.batchCode,
    required this.workOrderName,
    required this.myTags,
    required this.myDone,
    this.lastDoneAt,
  });

  /// Every one of his in this batch is on a pole. Not the batch's own status -
  /// his colleagues may have plenty left.
  bool get isFinished => myTags > 0 && myDone == myTags;

  factory MyBatch.fromJson(Map<String, dynamic> json) {
    return MyBatch(
      batchId: json['batch_id'] as int,
      batchCode: json['batch_code'] as String? ?? '',
      workOrderName: json['work_order_name'] as String? ?? '',
      myTags: json['my_tags'] as int? ?? 0,
      myDone: json['my_done'] as int? ?? 0,
      lastDoneAt: parseServerDate(json['last_done_at']),
    );
  }

  /// For the cache. `last_done_at` goes back as the server sent it - UTC with
  /// a Z - so reading it returns the same instant rather than one shifted by
  /// the device's offset a second time.
  Map<String, dynamic> toJson() => {
    'batch_id': batchId,
    'batch_code': batchCode,
    'work_order_name': workOrderName,
    'my_tags': myTags,
    'my_done': myDone,
    'last_done_at': lastDoneAt?.toUtc().toIso8601String(),
  };
}

/// One page of [MyBatch] rows, and the count they were cut from.
///
/// The total is what stops the scroll asking for ever. The rows alone cannot
/// say: a short page and the last page look identical until one arrives empty,
/// and asking once more at every bottom is a request per flick of the thumb.
class MyBatchesPage {
  final int total;
  final List<MyBatch> batches;

  const MyBatchesPage({this.total = 0, this.batches = const []});

  static const MyBatchesPage empty = MyBatchesPage();

  factory MyBatchesPage.fromJson(Map<String, dynamic> json) {
    final rows = json['batches'];

    return MyBatchesPage(
      total: json['total'] as int? ?? 0,
      batches: rows is List
          ? rows
                .whereType<Map>()
                .map((row) => MyBatch.fromJson(Map<String, dynamic>.from(row)))
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'total': total,
    'batches': batches.map((batch) => batch.toJson()).toList(),
  };
}
