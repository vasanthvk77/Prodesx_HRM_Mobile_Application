class OvertimeRecord {
  final dynamic overDutyId;
  final dynamic organizationId;
  final dynamic employeeId;
  final DateTime overDutyDate;
  final double hours;
  final double? ratePerHour;
  final double amount;
  final String? remarks;
  final DateTime? createdDateTime;
  final dynamic createdBy;

  // UI-only / Joined fields (populated from employee data)
  final String? employeeName;
  final String? employeeCode;
  final String? profilePictureUrl;

  const OvertimeRecord({
    required this.overDutyId,
    required this.organizationId,
    required this.employeeId,
    required this.overDutyDate,
    required this.hours,
    this.ratePerHour,
    required this.amount,
    this.remarks,
    this.createdDateTime,
    this.createdBy,
    this.employeeName,
    this.employeeCode,
    this.profilePictureUrl,
  });

  factory OvertimeRecord.fromJson(Map<String, dynamic> json) {
    // Handle case-insensitive keys (EmployeeName vs employeeName, etc.)
    final name = json['employeeName'] ?? json['EmployeeName'];
    final code = json['employeeCode'] ?? json['EmployeeCode'];
    final pic = json['profilePictureUrl'] ?? json['ProfilePictureUrl'];

    return OvertimeRecord(
      overDutyId: json['overDutyId'] ?? json['OverDutyId'],
      organizationId: json['organizationId'] ?? json['OrganizationId'],
      employeeId: json['employeeId'] ?? json['EmployeeId'],
      overDutyDate: DateTime.parse(json['overDutyDate'] ?? json['OverDutyDate']),
      hours: (json['hours'] ?? json['Hours'] as num).toDouble(),
      ratePerHour: (json['ratePerHour'] ?? json['RatePerHour']) != null
          ? (json['ratePerHour'] ?? json['RatePerHour'] as num).toDouble()
          : null,
      amount: (json['amount'] ?? json['Amount'] as num).toDouble(),
      remarks: json['remarks'] ?? json['Remarks'],
      createdDateTime: (json['createdDateTime'] ?? json['CreatedDateTime']) != null
          ? DateTime.parse(json['createdDateTime'] ?? json['CreatedDateTime'])
          : null,
      createdBy: json['createdBy'] ?? json['CreatedBy'],
      employeeName: name,
      employeeCode: code,
      profilePictureUrl: pic,
    );
  }

  Map<String, dynamic> toJson() => {
        'overDutyId': overDutyId,
        'organizationId': organizationId,
        'employeeId': employeeId,
        'overDutyDate': overDutyDate.toIso8601String(),
        'hours': hours,
        'ratePerHour': ratePerHour,
        'amount': amount,
        'remarks': remarks,
      };

  OvertimeRecord copyWith({
    String? employeeName,
    String? employeeCode,
    String? profilePictureUrl,
  }) =>
      OvertimeRecord(
        overDutyId: overDutyId,
        organizationId: organizationId,
        employeeId: employeeId,
        overDutyDate: overDutyDate,
        hours: hours,
        ratePerHour: ratePerHour,
        amount: amount,
        remarks: remarks,
        createdDateTime: createdDateTime,
        createdBy: createdBy,
        employeeName: employeeName ?? this.employeeName,
        employeeCode: employeeCode ?? this.employeeCode,
        profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      );
}
