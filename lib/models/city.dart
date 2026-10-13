/// A city, as the API's `CityOut` describes it.
///
/// Arrives two ways, which is why most of it is nullable: nested inside a crew
/// on `/auth/login` and `/me`, where only the id and name are sent, or whole
/// from a future `/cities` call. A null [duId] means "not sent", never "this
/// city has no DU" - the column is `nullable=False` on the server.
class City {
  final int cityId;
  final String cityName;
  final int? duId;
  final String? orgCode;
  final int? createdBy;

  const City({
    required this.cityId,
    required this.cityName,
    this.duId,
    this.orgCode,
    this.createdBy,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      cityId: json['city_id'],
      cityName: json['city_name'] ?? '',
      duId: json['du_id'],
      orgCode: json['org_code'],
      createdBy: json['created_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'city_id': cityId,
      'city_name': cityName,
      'du_id': duId,
      'org_code': orgCode,
      'created_by': createdBy,
    };
  }
}
