import 'package:np_pole_tag_stickerman/helpers/parsing.dart';

/// One role as the API reports it, e.g.
/// `{"role_id": 10, "role_name": "Crew", "updated_at": "..."}`.
///
/// Never sent to the server - this app only ever asks which roles the signed-in
/// user holds, and the web app owns the Roles admin screen. [toJson] exists so
/// the signed-in user can be cached on the phone for the next launch.
class Role {
  final int roleId;
  final String roleName;
  final DateTime? updatedAt;

  const Role({required this.roleId, required this.roleName, this.updatedAt});

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      roleId: json['role_id'],
      roleName: json['role_name'] ?? '',
      updatedAt: parseServerDate(json['updated_at']),
    );
  }

  /// The same shape [Role.fromJson] reads, so a cached role reloads through the
  /// one parser. `toUtc()` matters: [parseServerDate] returns local time, and
  /// writing that back without a zone would make the next read treat it as UTC
  /// and shift it again on every save/load cycle.
  Map<String, dynamic> toJson() {
    return {
      'role_id': roleId,
      'role_name': roleName,
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }
}
