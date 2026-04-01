class UserModel {
  final String id;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final int civicScore;
  final String role;
  final String? ward;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    this.civicScore = 0,
    this.role = 'citizen',
    this.ward,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'User',
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      civicScore: json['civic_score'] as int? ?? 0,
      role: json['role'] as String? ?? 'citizen',
      ward: json['ward'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'avatar_url': avatarUrl,
      'civic_score': civicScore,
      'role': role,
      'ward': ward,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? fullName,
    String? phone,
    String? avatarUrl,
    int? civicScore,
    String? role,
    String? ward,
  }) {
    return UserModel(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      civicScore: civicScore ?? this.civicScore,
      role: role ?? this.role,
      ward: ward ?? this.ward,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
