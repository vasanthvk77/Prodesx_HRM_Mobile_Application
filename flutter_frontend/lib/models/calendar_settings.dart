class CalendarSettings {
  final int organizationId;
  final int academicStartMonth;
  final int academicStartDay;
  final int academicEndMonth;
  final int academicEndDay;
  final int salaryStartDay;
  final int salaryEndDay;

  CalendarSettings({
    required this.organizationId,
    required this.academicStartMonth,
    required this.academicStartDay,
    required this.academicEndMonth,
    required this.academicEndDay,
    required this.salaryStartDay,
    required this.salaryEndDay,
  });

  factory CalendarSettings.fromJson(Map<String, dynamic> json) {
    return CalendarSettings(
      organizationId: json['organizationId'] ?? 0,
      academicStartMonth: json['academicStartMonth'] ?? 4,
      academicStartDay: json['academicStartDay'] ?? 1,
      academicEndMonth: json['academicEndMonth'] ?? 3,
      academicEndDay: json['academicEndDay'] ?? 31,
      salaryStartDay: json['salaryStartDay'] ?? 1,
      salaryEndDay: json['salaryEndDay'] ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'organizationId': organizationId,
      'academicStartMonth': academicStartMonth,
      'academicStartDay': academicStartDay,
      'academicEndMonth': academicEndMonth,
      'academicEndDay': academicEndDay,
      'salaryStartDay': salaryStartDay,
      'salaryEndDay': salaryEndDay,
    };
  }

  CalendarSettings copyWith({
    int? organizationId,
    int? academicStartMonth,
    int? academicStartDay,
    int? academicEndMonth,
    int? academicEndDay,
    int? salaryStartDay,
    int? salaryEndDay,
  }) {
    return CalendarSettings(
      organizationId: organizationId ?? this.organizationId,
      academicStartMonth: academicStartMonth ?? this.academicStartMonth,
      academicStartDay: academicStartDay ?? this.academicStartDay,
      academicEndMonth: academicEndMonth ?? this.academicEndMonth,
      academicEndDay: academicEndDay ?? this.academicEndDay,
      salaryStartDay: salaryStartDay ?? this.salaryStartDay,
      salaryEndDay: salaryEndDay ?? this.salaryEndDay,
    );
  }
}
