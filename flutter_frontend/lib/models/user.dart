class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final dynamic organizationId;
  final String? organizationLogo;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.organizationId,
    this.organizationLogo,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    try {
      return User(
        id: json['id'] is int ? json['id'] : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
        name: json['name']?.toString() ?? 'Unknown User',
        email: json['email']?.toString() ?? '',
        role: json['role']?.toString() ?? 'User',
        organizationId: json['organizationId'],
        organizationLogo: json['organizationLogo']?.toString(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'organizationId': organizationId,
      'organizationLogo': organizationLogo,
    };
  }
}
