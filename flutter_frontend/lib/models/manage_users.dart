class ManageUser {
  final int accessID;
  final int userID;
  final int organizationID;
  final int roleID;
  final DateTime grantedDate;
  final bool isActive;
  final String userName;
  final String email;
  final String organizationName;
  final String role;
  final String? organizationLogo;

  ManageUser({
    required this.accessID,
    required this.userID,
    required this.organizationID,
    required this.roleID,
    required this.grantedDate,
    required this.isActive,
    required this.userName,
    required this.email,
    required this.organizationName,
    required this.role,
    this.organizationLogo,
  });

  factory ManageUser.fromJson(Map<String, dynamic> json) {
    return ManageUser(
      accessID: json['accessID'] ?? 0,
      userID: json['userID'] ?? 0,
      organizationID: json['organizationID'] ?? 0,
      roleID: json['roleID'] ?? 0,
      grantedDate: json['grantedDate'] != null 
          ? DateTime.parse(json['grantedDate']) 
          : DateTime.now(),
      isActive: json['isActive'] ?? false,
      userName: json['userName'] ?? 'Unknown',
      email: json['email'] ?? '',
      organizationName: json['organizationName'] ?? 'N/A',
      role: json['role'] ?? 'User',
      organizationLogo: json['organizationLogo'],
    );
  }
}

class UserRole {
  final int roleID;
  final String roleName;

  UserRole({required this.roleID, required this.roleName});

  factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      roleID: json['roleID'] ?? 0,
      roleName: json['roleName'] ?? '',
    );
  }
}

class UserOrganization {
  final int id;
  final String name;
  final String? logoUrl;

  UserOrganization({required this.id, required this.name, this.logoUrl});

  factory UserOrganization.fromJson(Map<String, dynamic> json) {
    return UserOrganization(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      logoUrl: json['logoUrl']?.toString(),
    );
  }
}
