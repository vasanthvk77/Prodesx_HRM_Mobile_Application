class SalarySettings {
  final int ssId;
  final int employeeId;
  final double basicPay;
  final int salaryYearId;

  SalarySettings({
    required this.ssId,
    required this.employeeId,
    required this.basicPay,
    required this.salaryYearId,
  });

  factory SalarySettings.fromJson(Map<String, dynamic> json) {
    return SalarySettings(
      ssId: json['ssId'] as int? ?? 0,
      employeeId: json['employeeId'] as int,
      basicPay: (json['basicPay'] as num).toDouble(),
      salaryYearId: json['salaryYearId'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (ssId > 0) 'ssId': ssId,
      'employeeId': employeeId,
      'basicPay': basicPay,
      'salaryYearId': salaryYearId,
    };
  }

  SalarySettings copyWith({
    int? ssId,
    int? employeeId,
    double? basicPay,
    int? salaryYearId,
  }) {
    return SalarySettings(
      ssId: ssId ?? this.ssId,
      employeeId: employeeId ?? this.employeeId,
      basicPay: basicPay ?? this.basicPay,
      salaryYearId: salaryYearId ?? this.salaryYearId,
    );
  }
}
