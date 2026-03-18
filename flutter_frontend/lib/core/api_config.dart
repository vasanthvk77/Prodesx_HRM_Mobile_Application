class ApiConfig {
  static const String serverUrl = 'http://localhost:5217';
  static const String baseUrl = '$serverUrl/api';

  // Auth Endpoints
  static const String login = '$baseUrl/auth/login';
  static const String logout = '$baseUrl/auth/logout';
  static const String switchOrganization = '$baseUrl/auth/switch-organization';

  // Employees
  static const String employees = '$baseUrl/employees';

  // Attendance
  static const String attendanceStatus = '$baseUrl/Attendance/status';
  static const String attendancePunch = '$baseUrl/Attendance';

  // Shifts
  static const String shiftRoster = '$baseUrl/ShiftAssignments/roster';

  // CRM / Leads
  static const String leads = '$baseUrl/leads';

  // Organizations
  static const String organizations = '$baseUrl/organizations';
  static const String userOrganizations = '$baseUrl/users/organizations';

  static String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$serverUrl/$cleanPath';
  }
}
