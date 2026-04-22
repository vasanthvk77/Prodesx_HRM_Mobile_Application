import 'dart:convert';

class StaffSalary {
  final int? salaryId;
  final int? salaryMasterId;
  final int salaryYearId;
  final int month;
  final int employeeId;
  final double baseBasicPay;
  final double presentDays;
  final int totalDaysInMonth;
  final List<SalaryDetail>? allowancesDetail;
  final List<SalaryDetail>? deductionsDetail;
  final bool isFinalized;
  final double netSalary; // Earned Basic
  final double totalAllowance;
  final double? totalBaseAllowance;
  final double totalDeduction;
  final String? employeeName;
  final String? employeeCode;
  final String? profilePictureUrl;

  StaffSalary({
    this.salaryId,
    this.salaryMasterId,
    required this.salaryYearId,
    required this.month,
    required this.employeeId,
    required this.baseBasicPay,
    required this.presentDays,
    required this.totalDaysInMonth,
    this.allowancesDetail,
    this.deductionsDetail,
    required this.isFinalized,
    required this.netSalary,
    required this.totalAllowance,
    this.totalBaseAllowance,
    required this.totalDeduction,
    this.employeeName,
    this.employeeCode,
    this.profilePictureUrl,
  });

  double get grossSalary => netSalary + totalAllowance - totalDeduction;
  double get totalSalWithoutDeduction => netSalary + totalAllowance;

  factory StaffSalary.fromJson(Map<String, dynamic> json) {
    return StaffSalary(
      salaryId: json['salaryId'],
      salaryMasterId: json['salaryMasterId'],
      salaryYearId: json['salaryYearId'],
      month: json['month'],
      employeeId: json['employeeId'],
      baseBasicPay: (json['baseBasicPay'] ?? 0).toDouble(),
      presentDays: (json['presentDays'] ?? 0).toDouble(),
      totalDaysInMonth: json['totalDaysInMonth'] ?? 0,
      allowancesDetail: json['allowancesDetail'] != null 
          ? _parseDetails(json['allowancesDetail']) 
          : null,
      deductionsDetail: json['deductionsDetail'] != null 
          ? _parseDetails(json['deductionsDetail']) 
          : null,
      isFinalized: json['isFinalized'] ?? false,
      netSalary: (json['netSalary'] ?? 0).toDouble(),
      totalAllowance: (json['totalAllowance'] ?? 0).toDouble(),
      totalBaseAllowance: (json['totalBaseAllowance'] ?? 0).toDouble(),
      totalDeduction: (json['totalDeduction'] ?? 0).toDouble(),
      employeeName: json['employeeName'],
      employeeCode: json['employeeCode'],
      profilePictureUrl: json['profilePictureUrl'],
    );
  }

  static List<SalaryDetail> _parseDetails(dynamic detail) {
    if (detail is String) {
      if (detail.isEmpty || detail == '[]') return [];
      try {
        final List<dynamic> list = jsonDecode(detail);
        return list.map((e) => SalaryDetail.fromJson(e)).toList();
      } catch (e) {
        return [];
      }
    } else if (detail is List) {
      return detail.map((e) => SalaryDetail.fromJson(e)).toList();
    }
    return [];
  }
}

class SalaryDetail {
  final String name;
  final double amount;
  final double? baseAmount;

  SalaryDetail({
    required this.name,
    required this.amount,
    this.baseAmount,
  });

  factory SalaryDetail.fromJson(Map<String, dynamic> json) {
    return SalaryDetail(
      name: json['name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      baseAmount: (json['baseAmount'] ?? (json['amount'] ?? 0)).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'baseAmount': baseAmount,
    };
  }
}

class PayrollPreviewModel {
  final int employeeId;
  final String? employeeName;
  final String? employeeCode;
  final String? profilePictureUrl;
  final double baseBasicPay;
  final double presentDays;
  final double totalAllowance;
  final double totalBaseAllowance;
  final double totalDeduction;
  final int totalDaysInMonth;
  final List<SalaryDetail>? allowancesDetail;
  final List<SalaryDetail>? deductionsDetail;
  final bool isFinalized;

  PayrollPreviewModel({
    required this.employeeId,
    this.employeeName,
    this.employeeCode,
    this.profilePictureUrl,
    required this.baseBasicPay,
    required this.presentDays,
    required this.totalAllowance,
    required this.totalBaseAllowance,
    required this.totalDeduction,
    required this.totalDaysInMonth,
    this.allowancesDetail,
    this.deductionsDetail,
    required this.isFinalized,
  });

  double get earnedBasicPay => totalDaysInMonth > 0 ? (baseBasicPay / totalDaysInMonth) * presentDays : 0;
  double get totalSalWithoutDeduction => earnedBasicPay + totalAllowance;
  double get grossSalary => totalSalWithoutDeduction - totalDeduction;

  factory PayrollPreviewModel.fromJson(Map<String, dynamic> json) {
    return PayrollPreviewModel(
      employeeId: json['employeeId'],
      employeeName: json['employeeName'],
      employeeCode: json['employeeCode'],
      profilePictureUrl: json['profilePictureUrl'],
      baseBasicPay: (json['baseBasicPay'] ?? 0).toDouble(),
      presentDays: (json['presentDays'] ?? 0).toDouble(),
      totalAllowance: (json['totalAllowance'] ?? 0).toDouble(),
      totalBaseAllowance: (json['totalBaseAllowance'] ?? 0).toDouble(),
      totalDeduction: (json['totalDeduction'] ?? 0).toDouble(),
      totalDaysInMonth: json['totalDaysInMonth'] ?? 0,
      allowancesDetail: json['allowancesDetail'] != null 
          ? StaffSalary._parseDetails(json['allowancesDetail']) 
          : null,
      deductionsDetail: json['deductionsDetail'] != null 
          ? StaffSalary._parseDetails(json['deductionsDetail']) 
          : null,
      isFinalized: json['isFinalized'] ?? false,
    );
  }
}
