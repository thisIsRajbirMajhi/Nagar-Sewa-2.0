class DepartmentModel {
  final String id;
  final String name;
  final String code;
  final String? description;
  final String? contactEmail;
  final String? contactPhone;
  final List<String> geoZones;
  final DateTime createdAt;

  const DepartmentModel({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.contactEmail,
    this.contactPhone,
    this.geoZones = const [],
    required this.createdAt,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      description: json['description'] as String?,
      contactEmail: json['contact_email'] as String?,
      contactPhone: json['contact_phone'] as String?,
      geoZones:
          (json['geo_zones'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
