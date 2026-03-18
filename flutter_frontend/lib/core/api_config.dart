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
  static const String designationBulkDelete = '$baseUrl/designations/bulk-delete';


  // Designations
  static const String designations = '$baseUrl/designations';
  static const String parentDesignations = '$baseUrl/designations/parents';
  static String designation(int id) => '$designations/$id';

  // Departments
  static const String departments = '$baseUrl/departments';
  static const String departmentBulkDelete = '$baseUrl/departments/bulk-delete';
  static String department(int id) => '$departments/$id';


  // User Management
  static const String users = '$baseUrl/users';
  static const String roles = '$baseUrl/users/roles';
  static const String loginSessions = '$baseUrl/users/login-sessions';

  static String grantAccess(int userId) => '$users/$userId/access';
  static String revokeAccess(int userId, int orgId) => '$users/$userId/access/$orgId';
  static String deleteUser(int userId) => '$users/$userId';

  static String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$serverUrl/$cleanPath';
  }
}
