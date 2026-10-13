import 'package:np_pole_tag_stickerman/helpers/parsing.dart';

/// One tag, as `GET /tags/my` reports it.
///
/// No nested `du` or `batch`: the API sends the ids flat, and [batchCode]
/// alongside them, so a list of 500 carries no repeated objects.
class Tag {
  final int tagId;
  final int duId;
  final int? batchId;

  /// The batch's printed name, e.g. `BT-MP-2026-0038`. Null while the tag is
  /// still in the pool.
  final String? batchCode;

  /// What is printed on the physical sticker, e.g. `M2GG0`.
  final String tagCode;

  final String status;
  final String? remarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? createdBy;
  final int? updatedBy;
  final String? orgCode;

  /// When a reviewer accepted the capture filed against this tag, and null
  /// while nobody has.
  ///
  /// Only the Completed list of `GET /tags/my` carries it. Every other
  /// endpoint that sends a tag leaves it null rather than paying for a second
  /// read per row, so null here is "nobody asked" as often as it is "nobody
  /// accepted" - nothing outside that list should conclude anything from it.
  final DateTime? approvedAt;

  const Tag({
    required this.tagId,
    required this.duId,
    this.batchId,
    this.batchCode,
    required this.tagCode,
    required this.status,
    this.remarks,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.orgCode,
    this.approvedAt,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      tagId: json['tag_id'],
      duId: json['du_id'],
      batchId: json['batch_id'],
      batchCode: json['batch_code'],
      tagCode: json['tag_code'] ?? '',
      status: json['status'] ?? '',
      remarks: json['remarks'],
      createdAt: parseServerDate(json['created_at']),
      updatedAt: parseServerDate(json['updated_at']),
      createdBy: json['created_by'],
      updatedBy: json['updated_by'],
      orgCode: json['org_code'],
      // Absent from a server that has not been deployed yet, which reads as
      // null - the same as a pole still in QC's queue, and the right answer
      // for both.
      approvedAt: parseServerDate(json['approved_at']),
    );
  }

  /// Dates go out as UTC: [parseServerDate] returns local time, so writing it
  /// back plain would shift it again on the next read.
  Map<String, dynamic> toJson() {
    return {
      'tag_id': tagId,
      'du_id': duId,
      'batch_id': batchId,
      'batch_code': batchCode,
      'tag_code': tagCode,
      'status': status,
      'remarks': remarks,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
      'org_code': orgCode,
      // Written back with the rest so the cached copy he opens with no signal
      // says the same as the one that arrived with it.
      'approved_at': approvedAt?.toUtc().toIso8601String(),
    };
  }
}
