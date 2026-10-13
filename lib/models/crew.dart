import 'city.dart';

/// The crew a user belongs to, as `/auth/login` and `/me` report it.
///
/// Cut down on the server side: the API's own `CrewOut` also carries batch and
/// tag counters that only its list endpoint computes, so they are not sent
/// here and there is nothing to misread as a real count.
class Crew {
  final int crewId;
  final String crewLabel;

  /// Null where the crew has no city - `crews.city_id` is nullable, and
  /// deleting a city clears it rather than taking the crew with it.
  final City? city;

  /// Who carries this crew's paper. A batch is dealt to the leader alone, so
  /// every other member of the crew has nothing to do - and until the server
  /// sent these, no way of being told why.
  ///
  /// Both null on a crew nobody leads yet. The name arrives already written the
  /// way the rest of the system writes it ("P. Santos"), so this app never
  /// spells a person itself.
  final int? leaderId;
  final String? leaderName;

  const Crew({
    required this.crewId,
    required this.crewLabel,
    this.city,
    this.leaderId,
    this.leaderName,
  });

  factory Crew.fromJson(Map<String, dynamic> json) {
    return Crew(
      crewId: json['crew_id'],
      crewLabel: json['crew_label'] ?? '',
      city: json['city'] != null ? City.fromJson(json['city']) : null,
      leaderId: json['leader_id'],
      leaderName: json['leader_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'crew_id': crewId,
      'crew_label': crewLabel,
      'city': city?.toJson(),
      'leader_id': leaderId,
      'leader_name': leaderName,
    };
  }
}
