class SalaryYear {
  final int salaryYearId;
  final int organizationID;
  final String fromYear;
  final String toYear;
  final DateTime dateFrom;
  final DateTime dateTo;
  final int createdBy;
  final DateTime? createdDate;

  SalaryYear({
    required this.salaryYearId,
    required this.organizationID,
    required this.fromYear,
    required this.toYear,
    required this.dateFrom,
    required this.dateTo,
    required this.createdBy,
    this.createdDate,
  });

  factory SalaryYear.fromJson(Map<String, dynamic> json) {
    return SalaryYear(
      salaryYearId: json['salaryYearId'] ?? 0,
      organizationID: json['organizationID'] ?? json['organizationId'] ?? 0,
      fromYear: json['fromYear']?.toString() ?? '',
      toYear: json['toYear']?.toString() ?? '',
      dateFrom: json['dateFrom'] != null ? DateTime.parse(json['dateFrom'].toString()) : DateTime.now(),
      dateTo: json['dateTo'] != null ? DateTime.parse(json['dateTo'].toString()) : DateTime.now(),
      createdBy: json['createdBy'] ?? 0,
      createdDate: json['createdDate'] != null ? DateTime.parse(json['createdDate'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'salaryYearId': salaryYearId,
      'organizationID': organizationID,
      'fromYear': fromYear,
      'toYear': toYear,
      'dateFrom': dateFrom.toIso8601String(),
      'dateTo': dateTo.toIso8601String(),
      'createdBy': createdBy,
      if (createdDate != null) 'createdDate': createdDate!.toIso8601String(),
    };
  }
}
