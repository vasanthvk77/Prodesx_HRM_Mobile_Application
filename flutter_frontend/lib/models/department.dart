class Department {
  final int id;
  final int organizationId;
  final String? organizationName;
  final String departmentName;
  final int? parentDepartmentId;
  final String? parentDepartmentName;

  Department({
    required this.id,
    required this.organizationId,
    this.organizationName,
    required this.departmentName,
    this.parentDepartmentId,
    this.parentDepartmentName,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'] ?? 0,
      organizationId: json['organizationId'] ?? 0,
      organizationName: json['organizationName'],
      departmentName: json['departmentName'] ?? '',
      parentDepartmentId: json['parentDepartmentId'],
      parentDepartmentName: json['parentDepartmentName'] ?? json['parent_department_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationId': organizationId,
      'organizationName': organizationName,
      'departmentName': departmentName,
      'parentDepartmentId': parentDepartmentId,
    };
  }
}
