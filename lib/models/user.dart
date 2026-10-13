import 'package:np_pole_tag_stickerman/helpers/parsing.dart';

import 'crew.dart';
import 'role.dart';

class User {
  final int userId;
  final String firstName;
  final String lastName;
  final String? middleName;
  final String? suffix;
  final String email;
  final String? contact;
  final String username;
  final bool isActive;
  final String? authProvider;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<Role> roles;
  final Crew? crew;

  /// Null until an admin puts them in one, which today is everybody.
  final String? orgCode;

  /// The server's answer to "may this account use this app?", from `/login` and
  /// `/me`. Not worked out here on purpose: this app used to match the role
  /// name itself, and when an admin renamed the role to "Crew" on 2026-09-09
  /// every man in the field was locked out until a new APK reached his phone.
  /// The server owns the question now, so the next rename is a redeploy.
  ///
  /// Defaults to false, which is the safe way round: a reply without the field
  /// is a backend too old to have it, and letting someone in on a missing
  /// answer would put a Dispatcher on the tagging screens.
  final bool canUseMobile;

  /// Whether he leads the crew he is on, answered by the server for the same
  /// reason [canUseMobile] is: the rule belongs where the batches are dealt,
  /// not on the handset.
  ///
  /// A batch goes to the leader and nobody else, so a member who is not the
  /// leader has no tags, no batch to accept and no poles to file - every screen
  /// in this app is about his own paper, and he has none.
  ///
  /// Defaults to true, the opposite way round from [canUseMobile], and the
  /// difference is deliberate. That one guards the door, so an unknown answer
  /// must mean no. This one only decides whether to show him a wall, and a
  /// missing answer means the reply came from a build that did not carry it -
  /// a user cached by the previous version of this app. Defaulting to false
  /// would put that wall in front of a leader restarting his phone out of
  /// signal, with his own batch in the van. Letting him through is the state
  /// this app was in before the field existed at all.
  final bool isCrewLeader;

  User({
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.middleName,
    this.suffix,
    required this.email,
    this.contact,
    required this.username,
    this.isActive = true,
    this.authProvider,
    this.createdAt,
    this.updatedAt,
    this.roles = const [],
    this.crew,
    this.orgCode,
    this.canUseMobile = false,
    this.isCrewLeader = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      middleName: json['middle_name'],
      suffix: json['suffix'],
      email: json['email'] ?? '',
      contact: json['contact'],
      username: json['username'] ?? '',
      isActive: json['is_active'] ?? true,
      authProvider: json['auth_provider'],
      createdAt: parseServerDate(json['created_at']),
      updatedAt: parseServerDate(json['updated_at']),
      roles: json['roles'] != null
          ? (json['roles'] as List).map((r) => Role.fromJson(r)).toList()
          : [],
      crew: json['crew'] != null ? Crew.fromJson(json['crew']) : null,
      orgCode: json['org_code'],
      canUseMobile: json['can_use_mobile'] ?? false,
      isCrewLeader: json['is_crew_leader'] ?? true,
    );
  }

  /// The same shape [User.fromJson] reads, so a user cached on the phone
  /// reloads through the one parser rather than a second, drifting copy.
  ///
  /// Only ever written to `shared_preferences` - the API is never sent a user
  /// from this app. Dates go out as UTC for the reason given in [Role.toJson].
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'middle_name': middleName,
      'suffix': suffix,
      'email': email,
      'contact': contact,
      'username': username,
      'is_active': isActive,
      'auth_provider': authProvider,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
      'roles': roles.map((role) => role.toJson()).toList(),
      'crew': crew?.toJson(),
      'org_code': orgCode,
      'can_use_mobile': canUseMobile,
      'is_crew_leader': isCrewLeader,
    };
  }

  String get fullName => '$firstName $lastName';

  /// Whether this account is allowed in at all - the server's [canUseMobile]
  /// under the name the sign-in code reads it by.
  ///
  /// Holding other roles as well makes no difference: a Dispatcher who is also
  /// on the crew gets in, and does sticker man work, because that is all this
  /// app offers.
  bool get isStickerMan => canUseMobile;
}
