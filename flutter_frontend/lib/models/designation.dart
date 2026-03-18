
class Designation {
  final int id;
  final int organizationId;
  final String? organizationName;
  final String designationName;
  final int? parentDesignationId;
  final String? parentDesignationName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Designation({
    required this.id,
    required this.organizationId,
    this.organizationName,
    required this.designationName,
    this.parentDesignationId,
    this.parentDesignationName,
    this.createdAt,
    this.updatedAt,
  });

  factory Designation.fromJson(Map<String, dynamic> json) {
    return Designation(
      id: json['id'] ?? 0,
      organizationId: json['organizationId'] ?? 0,
      organizationName: json['organizationName'],
      designationName: json['designationName'] ?? '',
      parentDesignationId: json['parentDesignationId'],
      parentDesignationName: json['parentDesignationName'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationId': organizationId,
      'organizationName': organizationName,
      'designationName': designationName,
      'parentDesignationId': parentDesignationId,
      'parentDesignationName': parentDesignationName,
    };
  }
}
