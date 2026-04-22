class ApiConfig {
  static const String serverUrl = 'http://localhost:5217';
  static const String pythonServerUrl = 'http://localhost:8000';
  static const String baseUrl = '$serverUrl/api';

  // Auth Endpoints
  static const String login = '$baseUrl/auth/login';
  static const String logout = '$baseUrl/auth/logout';
  static const String switchOrganization = '$baseUrl/auth/switch-organization';

  // Employees
  static const String employees = '$baseUrl/employees';
  static const String unlinkedUsers = '$baseUrl/employees/unlinked-users';
  static String employee(int id) => '$employees/$id';
  static String employeePhoto(int id) => '$employees/$id/photo';
  static String employeeSignature(int id) => '$employees/$id/signature';
  static String employeeBankDetails(int id) => '$employees/$id/bank-details';
  static const String exportEmployeesExcel = '$baseUrl/employees/export-excel';
  static const String exportEmployeesPdf = '$baseUrl/employees/export-pdf';

  // Dynamic Form (Employee Fields)
  static const String employeeFields = '$baseUrl/DynamicForm/employee-fields';
  static const String updateEmployeeFields =
      '$baseUrl/DynamicForm/update-fields';
  static const String createMasterField = '$baseUrl/DynamicForm/create-field';
  static String deleteMasterField(int id) =>
      '$baseUrl/DynamicForm/delete-field/$id';

  // SignalR Hubs
  static const String employeesHub = '$serverUrl/hubs/employees';
  static const String attendanceHub = '$serverUrl/hubs/attendance';
  static const String empOTHub = '$serverUrl/hubs/empot';
  static const String professionalTaxHub = '$serverUrl/hubs/professionaltax';
  static const String allowancesHub = '$serverUrl/hubs/allowances';
  static const String staffAllowancesHub = '$serverUrl/hubs/staffallowances';
  static const String deductionsHub = '$serverUrl/hubs/deductions';
  static const String staffDeductionsHub = '$serverUrl/hubs/staffdeductions';
  static const String salaryYearsHub = '$serverUrl/hubs/salaryyears';
  static const String salarySettingsHub = '$serverUrl/hubs/salarysettings';

  // Benefits (Allowances & Deductions)
  static const String allowances = '$baseUrl/Allowances';
  static const String saveAllowance = '$allowances/SaveAllowance';
  static const String updateAllowance = '$allowances/UpdateAllowance';
  static const String getAllowanceByOrgId = '$allowances/GetAllowanceByOrgId';
  static const String deleteAllowance = '$allowances/DeleteAllowance';

  static const String saveStaffAllowance = '$allowances/SaveStaffAllowance';
  static const String updateStaffAllowance = '$allowances/UpdateStaffAllowance';
  static const String getStaffAllowanceByOrgId = '$allowances/GetStaffAllowanceByOrgId';
  static const String deleteStaffAllowance = '$allowances/DeleteStaffAllowance';

  static const String deductions = '$baseUrl/Deductions';
  static const String saveDeduction = '$deductions/SaveDeduction';
  static const String updateDeduction = '$deductions/UpdateDeduction';
  static const String getDeductionsByOrgId = '$deductions/GetDeductionsByOrgId';
  static const String deleteDeduction = '$deductions/DeleteDeduction';

  static const String saveStaffDeduction = '$deductions/SaveStaffDeduction';
  static const String updateStaffDeduction = '$deductions/UpdateStaffDeduction';
  static const String getStaffDeductionsByOrgId = '$deductions/GetStaffDeductionsByOrgId';
  static const String deleteStaffDeduction = '$deductions/DeleteStaffDeduction';

  // Statutory Settings
  static const String payrollSettings = '$baseUrl/payroll-settings';

  // Attendance
  static const String attendanceStatus = '$baseUrl/Attendance/status';
  static const String attendancePunch = '$baseUrl/Attendance';
  static const String attendanceMaster = '$baseUrl/AttendanceMaster';
  static const String bulkAttendanceMaster = '$baseUrl/AttendanceMaster/bulk';
  static const String exportAttendanceRegister = '$baseUrl/Attendance/export-register';

  // Leave Types
  static const String leaveTypes = '$baseUrl/LeaveType';
  static const String leaveTypeSettings = '$baseUrl/LeaveType/settings';
  static const String toggleLeaveType = '$baseUrl/LeaveType/toggle';

  // Shifts
  static const String shiftRoster = '$baseUrl/ShiftAssignments/roster';

  // Overtime (OT)
  static const String empOT = '$baseUrl/EmpOT';
  static const String getOTByOrgId = '$empOT/GetOTByOrgId';
  static const String saveEmpOT = '$empOT/SaveOT';
  static const String updateEmpOT = '$empOT/UpdateOT';
  static const String deleteEmpOT = '$empOT/DeleteOT';

  // CRM / Leads
  static const String leads = '$baseUrl/leads';

  // Organizations
  static const String organizations = '$baseUrl/organizations';
  static const String userOrganizations = '$baseUrl/users/organizations';
  static const String designationBulkDelete =
      '$baseUrl/designations/bulk-delete';

  // Designations
  static const String designations = '$baseUrl/designations';
  static const String parentDesignations = '$baseUrl/designations/parents';
  static String designation(int id) => '$designations/$id';

  // Departments
  static const String departments = '$baseUrl/departments';
  static const String departmentBulkDelete = '$baseUrl/departments/bulk-delete';
  static String department(int id) => '$departments/$id';

  // Professional Tax
  static const String professionalTax = '$baseUrl/ProfessionalTax';
  static const String saveProfessionalTax = '$professionalTax/SaveProfessionalTax';
  static const String updateProfessionalTax = '$professionalTax/UpdateProfessionalTax';
  static const String getProfessionalTax = '$professionalTax/GetProfessionalTax';
  static const String deleteProfessionalTax = '$professionalTax/DeleteProfessionalTax';

  // User Management
  static const String users = '$baseUrl/users';
  static const String roles = '$baseUrl/users/roles';
  static const String loginSessions = '$baseUrl/users/login-sessions';

  static String grantAccess(int userId) => '$users/$userId/access';
  static String revokeAccess(int userId, int orgId) =>
      '$users/$userId/access/$orgId';
  static String deleteUser(int userId) => '$users/$userId';

  // Calendar Settings & Salary Year
  static const String calendarSettings = '$baseUrl/OrganizationCalendarSettings';
  static const String salaryYear = '$baseUrl/SalaryYear';
  static const String getSalaryYearsByOrgId = '$salaryYear/GetSalaryYearsByOrgId';
  static const String saveSalaryYear = '$salaryYear/SaveSalaryYear';
  static const String updateSalaryYear = '$salaryYear/UpdateSalaryYear';
  static const String deleteSalaryYear = '$salaryYear/DeleteSalaryYear';
  
  // Basic Pay (Salary Settings)
  static const String salarySettings = '$baseUrl/SalarySettings';
  static const String getSalarySettings = '$salarySettings/GetSalarySettings';
  static const String saveSalarySettings = '$salarySettings/SaveSalarySettings';
  static const String updateSalarySettings = '$salarySettings/UpdateSalarySettings';

  // Salary Export
  static const String exportStaffSalary = '$baseUrl/staff-salary/export';
  static const String exportBulkPaySlips = '$baseUrl/staff-salary/payslip/bulk';
  static String individualPaySlip(int employeeId) => '$baseUrl/staff-salary/payslip/$employeeId';

  static String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$serverUrl/$cleanPath';
  }
}
