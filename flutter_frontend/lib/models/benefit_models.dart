import 'dart:convert';

enum BenefitCategory { allowance, deduction }

class BenefitType {
  final int id;
  final int organizationId;
  final String fullName;
  final String shortName;
  final BenefitCategory category;

  BenefitType({
    required this.id,
    required this.organizationId,
    required this.fullName,
    required this.shortName,
    required this.category,
  });

  factory BenefitType.fromJson(Map<String, dynamic> json, BenefitCategory category) {
    // Handle different ID names from backend
    final idField = category == BenefitCategory.allowance ? 'allowencesId' : 'deductionsId';
    final altIdField = category == BenefitCategory.allowance ? 'AllowencesId' : 'DeductionsId';

    return BenefitType(
      id: json[idField] ?? json[altIdField] ?? json['id'] ?? 0,
      organizationId: json['organizationID'] ?? json['OrganizationID'] ?? json['organizationId'] ?? 0,
      fullName: json['fullName'] ?? json['FullName'] ?? '',
      shortName: json['shortName'] ?? json['ShortName'] ?? '',
      category: category,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'organizationID': organizationId,
      'fullName': fullName,
      'shortName': shortName,
    };
    
    // Add ID with correct field name for backend
    if (id > 0) {
      final idField = category == BenefitCategory.allowance ? 'allowencesId' : 'deductionsId';
      data[idField] = id;
    }
    
    return data;
  }
}

class BenefitAssignment {
  final int id;
  final int benefitId; // allowenceId or deductionId
  final int employeeId;
  final bool calType; // 0 for Percentage, 1 for Fixed
  final double amount;
  final int createdBy;
  final DateTime? createdDate;
  
  // Navigation/Joined properties
  final String? benefitName;
  final String? benefitShortName;
  final String? employeeName;
  final String? employeeCode;
  final String? profilePictureUrl;
  final BenefitCategory category;

  BenefitAssignment({
    required this.id,
    required this.benefitId,
    required this.employeeId,
    required this.calType,
    required this.amount,
    required this.createdBy,
    this.createdDate,
    this.benefitName,
    this.benefitShortName,
    this.employeeName,
    this.employeeCode,
    this.profilePictureUrl,
    required this.category,
  });

  BenefitAssignment copyWith({
    int? id,
    int? benefitId,
    int? employeeId,
    bool? calType,
    double? amount,
    int? createdBy,
    DateTime? createdDate,
    String? benefitName,
    String? benefitShortName,
    String? employeeName,
    String? employeeCode,
    String? profilePictureUrl,
    BenefitCategory? category,
  }) {
    return BenefitAssignment(
      id: id ?? this.id,
      benefitId: benefitId ?? this.benefitId,
      employeeId: employeeId ?? this.employeeId,
      calType: calType ?? this.calType,
      amount: amount ?? this.amount,
      createdBy: createdBy ?? this.createdBy,
      createdDate: createdDate ?? this.createdDate,
      benefitName: benefitName ?? this.benefitName,
      benefitShortName: benefitShortName ?? this.benefitShortName,
      employeeName: employeeName ?? this.employeeName,
      employeeCode: employeeCode ?? this.employeeCode,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      category: category ?? this.category,
    );
  }

  factory BenefitAssignment.fromJson(Map<String, dynamic> json, BenefitCategory category) {
    final idField = category == BenefitCategory.allowance ? 'staffAllowanceId' : 'staffDeductionId';
    final benefitIdField = category == BenefitCategory.allowance ? 'allowenceId' : 'deductionId';
    final altBenefitIdField = category == BenefitCategory.allowance ? 'AllowenceId' : 'DeductionId';
    
    final nameField = category == BenefitCategory.allowance ? 'allowanceName' : 'deductionName';
    final shortNameField = category == BenefitCategory.allowance ? 'allowanceShortName' : 'deductionShortName';

    return BenefitAssignment(
      id: json[idField] ?? json['StaffAllowanceId'] ?? json['StaffDeductionId'] ?? json['id'] ?? 0,
      benefitId: json[benefitIdField] ?? json[altBenefitIdField] ?? json['benefitId'] ?? 0,
      employeeId: json['employeeID'] ?? json['EmployeeID'] ?? json['employeeId'] ?? 0,
      calType: json['calType'] ?? json['CalType'] ?? true,
      amount: (json['amount'] ?? json['Amount'] ?? 0.0).toDouble(),
      createdBy: json['createdBy'] ?? json['CreatedBy'] ?? 0,
      createdDate: json['createdDate'] != null ? DateTime.tryParse(json['createdDate'].toString()) : null,
      benefitName: json[nameField] ?? json['AllowanceName'] ?? json['DeductionName'],
      benefitShortName: json[shortNameField] ?? json['AllowanceShortName'] ?? json['DeductionShortName'],
      employeeName: json['employeeName'] ?? json['EmployeeName'],
      employeeCode: json['employeeCode'] ?? json['EmployeeCode'],
      profilePictureUrl: json['profilePictureUrl'] ?? json['ProfilePictureUrl'],
      category: category,
    );
  }

  Map<String, dynamic> toJson() {
    final idField = category == BenefitCategory.allowance ? 'staffAllowanceId' : 'staffDeductionId';
    final benefitIdField = category == BenefitCategory.allowance ? 'allowenceId' : 'deductionId';

    final Map<String, dynamic> data = {
      benefitIdField: benefitId,
      'employeeID': employeeId,
      'calType': calType,
      'amount': amount,
      'createdBy': createdBy,
    };

    if (id > 0) {
      data[idField] = id;
    }

    return data;
  }
}

class StatutorySettings {
  final int organizationId;
  final bool isPFActive;
  final bool isESIActive;
  final double pfPercentage;
  final double pfCapAmount;
  final double esiPercentage;

  StatutorySettings({
    required this.organizationId,
    required this.isPFActive,
    required this.isESIActive,
    required this.pfPercentage,
    required this.pfCapAmount,
    required this.esiPercentage,
  });

  factory StatutorySettings.fromJson(Map<String, dynamic> json) {
    return StatutorySettings(
      organizationId: json['organizationId'] ?? 0,
      isPFActive: json['isPFActive'] ?? false,
      isESIActive: json['isESIActive'] ?? false,
      pfPercentage: (json['pfPercentage'] ?? 12.0).toDouble(),
      pfCapAmount: (json['pfCapAmount'] ?? 15000.0).toDouble(),
      esiPercentage: (json['esiPercentage'] ?? 0.75).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isPFActive': isPFActive,
      'isESIActive': isESIActive,
      'pfPercentage': pfPercentage,
      'pfCapAmount': pfCapAmount,
      'esiPercentage': esiPercentage,
    };
  }
}
