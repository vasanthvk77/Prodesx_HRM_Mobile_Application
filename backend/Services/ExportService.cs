using ClosedXML.Excel;
using Microsoft.Reporting.NETCore;
using backend.Models;
using backend.Data;
using System.Data;
using System.Text;
using System.Reflection;
using Newtonsoft.Json;
using Dapper;

namespace backend.Services
{
    public class ExportService
    {
        private readonly DataBaseConnection _db;
        private readonly Microsoft.Extensions.Logging.ILogger<ExportService> _logger;

        public ExportService(DataBaseConnection db, Microsoft.Extensions.Logging.ILogger<ExportService> logger)
        {
            _db = db;
            _logger = logger;
        }

        public byte[] GenerateFormVIPdf(List<Employee> employees, List<HolidayWithAssignments> holidays, Organization org, int? year, DateTime? startDate, DateTime? endDate)
        {
            Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);

            var dt = new DataTable();
            dt.TableName = "FormVIDataSet";
            dt.Columns.Add("OrgName");
            dt.Columns.Add("OrgAddress");
            dt.Columns.Add("Year");
            dt.Columns.Add("SlNo");
            dt.Columns.Add("EmpName");
            dt.Columns.Add("TicketOrFatherName");
            dt.Columns.Add("HolidayName");
            dt.Columns.Add("HolidayDate");
            dt.Columns.Add("HolidayOrder", typeof(int));
            dt.Columns.Add("Status");
            dt.Columns.Add("Remarks");

            // Fetch manual status overrides
            using var conn = _db.CreateConnection();
            var statusOverrides = conn.Query<EmployeeHolidayStatus>(
                "SELECT id as Id, organization_id as OrganizationId, employee_id as EmployeeId, holiday_id as HolidayId, status as Status, remarks as Remarks FROM EmployeeHolidayStatus WHERE organization_id = @OrgId",
                new { OrgId = org.Id }
            ).ToDictionary(s => $"{s.EmployeeId}_{s.HolidayId}");

            var activeHolidays = holidays.Where(h => {
                if (h.HolidayDate == null) return false;
                var hDate = h.HolidayDate.Value;
                if (year != null && hDate.Year != year) return false;
                if (startDate != null && hDate < startDate) return false;
                if (endDate != null && hDate > endDate) return false;
                return true;
            }).OrderBy(h => h.HolidayDate).ToList();

            int serial = 1;
            foreach (var emp in employees)
            {
                int hOrder = 1;
                foreach (var h in activeHolidays)
                {
                    var row = dt.NewRow();
                    row["OrgName"] = org.Name;
                    row["OrgAddress"] = (org.Address ?? "").Replace(",", ", ");
                    row["Year"] = year?.ToString() ?? DateTime.Now.Year.ToString();
                    row["SlNo"] = serial.ToString();
                    row["EmpName"] = emp.Name;
                    row["TicketOrFatherName"] = emp.FatherOrSpouse ?? emp.EmployeeCode ?? "";
                    row["HolidayName"] = h.HolidayName ?? "";
                    row["HolidayDate"] = h.HolidayDate?.ToString("dd.MM.yy") ?? "";
                    row["HolidayOrder"] = hOrder++;

                    // Check for manual override first
                    string status = "";
                    string remarks = "";
                    var key = $"{emp.Id}_{h.HolidayID}";
                    
                    if (statusOverrides.TryGetValue(key, out var overrideStatus))
                    {
                        status = overrideStatus.Status;
                        remarks = overrideStatus.Remarks ?? "";
                    }
                    else
                    {
                        // Default Eligibility check
                        bool isEligible = h.AssignmentType == "All" || (h.Assignments?.Any(a => 
                            (a.TargetType == "Department" && a.TargetId == emp.DepartmentId) ||
                            (a.TargetType == "Designation" && a.TargetId == emp.DesignationId) ||
                            (a.TargetType == "Employee" && a.TargetId == emp.Id)
                        ) ?? false);
                        status = isEligible ? "H" : "";
                    }

                    row["Status"] = status;
                    row["Remarks"] = remarks;
                    dt.Rows.Add(row);
                }
                serial++;
            }

            var reportPath = Path.Combine(Directory.GetCurrentDirectory(), "ReportTemplate", "Form_VI.rdlc");
            using var localReport = new LocalReport();
            localReport.ReportPath = reportPath;
            localReport.DataSources.Add(new ReportDataSource("FormVIDataSet", dt));

            return localReport.Render("PDF");
        }

        public byte[] GenerateFormVIExcel(List<Employee> employees, List<HolidayWithAssignments> holidays, Organization org, int? year, DateTime? startDate, DateTime? endDate)
        {
            using (var workbook = new XLWorkbook())
            {
                var worksheet = workbook.Worksheets.Add("Form VI");
                int currentRow = 1;

                var activeHolidays = holidays.Where(h => {
                    if (h.HolidayDate == null) return false;
                    var hDate = h.HolidayDate.Value;
                    if (year != null && hDate.Year != year) return false;
                    if (startDate != null && hDate < startDate) return false;
                    if (endDate != null && hDate > endDate) return false;
                    return true;
                }).OrderBy(h => h.HolidayDate).ToList();

                // Fetch manual status overrides
                using var conn = _db.CreateConnection();
                var statusOverrides = conn.Query<EmployeeHolidayStatus>(
                    "SELECT id as Id, organization_id as OrganizationId, employee_id as EmployeeId, holiday_id as HolidayId, status as Status, remarks as Remarks FROM EmployeeHolidayStatus WHERE organization_id = @OrgId",
                    new { OrgId = org.Id }
                ).ToDictionary(s => $"{s.EmployeeId}_{s.HolidayId}");

                int totalCols = 4 + activeHolidays.Count;

                // Legend
                worksheet.Cell(currentRow, 1).Value = "To be marked as follows: 'H' for holidays allowed, 'W/D' for work on double wages, 'W/H' for work with substituted holiday, 'N/E' if not eligible for wages";
                worksheet.Range(currentRow, 1, currentRow, totalCols).Merge().Style.Font.FontSize = 8;
                currentRow++;

                // Title
                worksheet.Cell(currentRow, 1).Value = "Form No. VI - Register of National & Festival Holidays";
                worksheet.Range(currentRow, 1, currentRow, totalCols).Merge().Style.Font.Bold = true;
                worksheet.Range(currentRow, 1, currentRow, totalCols).Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
                currentRow++;

                worksheet.Cell(currentRow, 1).Value = "For the Year " + (year?.ToString() ?? DateTime.Now.Year.ToString());
                worksheet.Range(currentRow, 1, currentRow, totalCols).Merge().Style.Font.Bold = true;
                worksheet.Range(currentRow, 1, currentRow, totalCols).Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
                currentRow++;

                // Org Info
                worksheet.Cell(currentRow, 1).Value = org.Name + " - " + org.Address;
                worksheet.Range(currentRow, 1, currentRow, totalCols).Merge().Style.Font.Italic = true;
                worksheet.Range(currentRow, 1, currentRow, totalCols).Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
                currentRow += 2;

                // Headers - Row 1: Names, Row 2: Dates, Row 3: SlNo
                worksheet.Cell(currentRow, 1).Value = "Sl.No";
                worksheet.Cell(currentRow, 2).Value = "Name of the Employee";
                worksheet.Cell(currentRow, 3).Value = "Ticket No / Father's Name";
                
                for (int i = 0; i < activeHolidays.Count; i++)
                {
                    worksheet.Cell(currentRow, 4 + i).Value = activeHolidays[i].HolidayName;
                    worksheet.Cell(currentRow + 1, 4 + i).Value = activeHolidays[i].HolidayDate?.ToString("dd.MM.yy");
                    worksheet.Cell(currentRow + 2, 4 + i).Value = (i + 1).ToString();
                }
                worksheet.Cell(currentRow, 4 + activeHolidays.Count).Value = "Remarks";

                var headerRange = worksheet.Range(currentRow, 1, currentRow + 2, totalCols);
                headerRange.Style.Font.Bold = true;
                headerRange.Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
                headerRange.Style.Alignment.Vertical = XLAlignmentVerticalValues.Center;
                headerRange.Style.Fill.BackgroundColor = XLColor.LightGray;
                headerRange.Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
                headerRange.Style.Border.InsideBorder = XLBorderStyleValues.Thin;
                currentRow += 3;

                int serial = 1;
                foreach (var emp in employees)
                {
                    worksheet.Cell(currentRow, 1).Value = serial++;
                    worksheet.Cell(currentRow, 2).Value = emp.Name;
                    worksheet.Cell(currentRow, 3).Value = emp.FatherOrSpouse ?? emp.EmployeeCode ?? "";

                    for (int i = 0; i < activeHolidays.Count; i++)
                    {
                        var h = activeHolidays[i];
                        var key = $"{emp.Id}_{h.HolidayID}";
                        string status = "";
                        
                        if (statusOverrides.TryGetValue(key, out var o))
                        {
                            status = o.Status;
                        }
                        else
                        {
                            bool isEligible = h.AssignmentType == "All" || (h.Assignments?.Any(a => 
                                (a.TargetType == "Department" && a.TargetId == emp.DepartmentId) ||
                                (a.TargetType == "Designation" && a.TargetId == emp.DesignationId) ||
                                (a.TargetType == "Employee" && a.TargetId == emp.Id)
                            ) ?? false);
                            status = isEligible ? "H" : "";
                        }
                        worksheet.Cell(currentRow, 4 + i).Value = status;
                    }
                    worksheet.Cell(currentRow, 4 + activeHolidays.Count).Value = "";
                    currentRow++;
                }

                worksheet.Columns().AdjustToContents();
                worksheet.Range(currentRow - serial + 1, 1, currentRow - 1, totalCols).Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
                worksheet.Range(currentRow - serial + 1, 1, currentRow - 1, totalCols).Style.Border.InsideBorder = XLBorderStyleValues.Thin;

                using (var stream = new MemoryStream())
                {
                    workbook.SaveAs(stream);
                    return stream.ToArray();
                }
            }
        }

        public byte[] GenerateEmployeesExcel(List<Employee> employees, List<OrganizationFieldAccess> fields, string organizationName)
        {
            using (var workbook = new XLWorkbook())
            {
                var worksheet = workbook.Worksheets.Add("Employees");
                int currentRow = 1;

                // Sort fields by Section and then by FieldOrder to match the form's flow
                var visibleFields = fields.Where(f => f.IsVisible)
                    .OrderBy(f => GetSectionOrder(f.FieldMetadata?.SectionName))
                    .ThenBy(f => f.FieldMetadata?.FieldOrder ?? 0)
                    .ToList();

                // Header
                for (int i = 0; i < visibleFields.Count; i++)
                {
                    worksheet.Cell(currentRow, i + 1).Value = visibleFields[i].CustomLabel ?? visibleFields[i].FieldMetadata?.DisplayLabel ?? visibleFields[i].FieldMetadata?.FieldKey ?? "Field";
                }

                var headerRange = worksheet.Range(1, 1, 1, Math.Max(visibleFields.Count, 1));
                headerRange.Style.Font.Bold = true;
                headerRange.Style.Fill.BackgroundColor = XLColor.LightGray;

                // Data
                foreach (var emp in employees)
                {
                    currentRow++;
                    for (int i = 0; i < visibleFields.Count; i++)
                    {
                        worksheet.Cell(currentRow, i + 1).Value = GetFieldValue(emp, visibleFields[i]);
                    }
                }

                worksheet.Columns().AdjustToContents();

                using (var stream = new MemoryStream())
                {
                    workbook.SaveAs(stream);
                    return stream.ToArray();
                }
            }
        }

        private static int GetSectionOrder(string? sectionName)
        {
            if (string.IsNullOrEmpty(sectionName)) return 99;
            return sectionName.Trim() switch
            {
                "Personal Information" => 1,
                "Bank Account Details" => 2,
                "Contact Info" => 3,
                "Exit Details & Remarks" => 4,
                _ => 10
            };
        }

        public byte[] GenerateEmployeesPdf(List<Employee> employees, Organization org, List<OrganizationFieldAccess> fields, string? formTemplate = null)
        {
            Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);

            var dt = new DataTable();
            dt.TableName = "EmployeeDataSet";
            dt.Columns.Add("OrgName");
            dt.Columns.Add("OrgAddress");
            dt.Columns.Add("SlNo");
            dt.Columns.Add("Name");
            dt.Columns.Add("EmpCode");
            dt.Columns.Add("Gender");
            dt.Columns.Add("FatherSpouse");
            dt.Columns.Add("DOB");
            dt.Columns.Add("JoiningDate");
            dt.Columns.Add("Designation");
            dt.Columns.Add("PresentAddress");
            dt.Columns.Add("PermanentAddress");
            dt.Columns.Add("PFNo");
            dt.Columns.Add("ESICNo");
            dt.Columns.Add("AadharNo");
            dt.Columns.Add("Days80Date");
            dt.Columns.Add("PermanentDate");
            dt.Columns.Add("Suspension");
            dt.Columns.Add("AccNo");
            dt.Columns.Add("BankName");
            dt.Columns.Add("BranchName");
            dt.Columns.Add("IfscCode");
            dt.Columns.Add("Mobile");
            dt.Columns.Add("Email");
            dt.Columns.Add("ExitDate");
            dt.Columns.Add("ExitReason");
            dt.Columns.Add("Remarks");
            dt.Columns.Add("AdditionalData");
            dt.Columns.Add("Photo", typeof(byte[]));
            dt.Columns.Add("Signature", typeof(byte[]));

            int serial = 1;
            foreach (var emp in employees)
            {
                var row = dt.NewRow();
                row["OrgName"] = org.Name;
                row["OrgAddress"] = org.Address ?? "";
                row["SlNo"] = serial++.ToString();
                
                row["Name"] = IsVisible(fields, "name") ? GetFieldValue(emp, fields, "name") : null;
                row["EmpCode"] = (IsVisible(fields, "employeeCode") || IsVisible(fields, "empCode")) ? GetFieldValue(emp, fields, "employeeCode") : null;
                row["Gender"] = IsVisible(fields, "gender") ? GetFieldValue(emp, fields, "gender") : null;
                row["FatherSpouse"] = (IsVisible(fields, "fatherOrSpouse") || IsVisible(fields, "fatherName")) ? GetFieldValue(emp, fields, "fatherOrSpouse") : null;
                row["DOB"] = (IsVisible(fields, "dateOfBirth") || IsVisible(fields, "dob")) ? GetFieldValue(emp, fields, "dateOfBirth") : null;
                row["JoiningDate"] = (IsVisible(fields, "joiningDate") || IsVisible(fields, "dateOfJoining")) ? GetFieldValue(emp, fields, "joiningDate") : null;
                
                var desig = IsVisible(fields, "designation") ? GetFieldValue(emp, fields, "designation") : null;
                var dept = IsVisible(fields, "department") ? GetFieldValue(emp, fields, "department") : null;
                row["Designation"] = (desig != null && dept != null && dept != "--") ? $"{desig} ({dept})" : (desig ?? dept);

                row["PresentAddress"] = IsVisible(fields, "presentAddress") ? GetFieldValue(emp, fields, "presentAddress") : null;
                row["PermanentAddress"] = IsVisible(fields, "permanentAddress") ? GetFieldValue(emp, fields, "permanentAddress") : null;
                row["PFNo"] = (IsVisible(fields, "employeePfNo") || IsVisible(fields, "pfNo")) ? GetFieldValue(emp, fields, "employeePfNo") : null;
                row["ESICNo"] = (IsVisible(fields, "employeeEsicNo") || IsVisible(fields, "esicNo")) ? GetFieldValue(emp, fields, "employeeEsicNo") : null;
                row["AadharNo"] = (IsVisible(fields, "employeeAadharNo") || IsVisible(fields, "aadharNo")) ? GetFieldValue(emp, fields, "employeeAadharNo") : null;
                row["Days80Date"] = IsVisible(fields, "days80ServiceCompletionDate") ? GetFieldValue(emp, fields, "days80ServiceCompletionDate") : null;
                row["PermanentDate"] = IsVisible(fields, "permanentAppointmentDate") ? GetFieldValue(emp, fields, "permanentAppointmentDate") : null;
                row["Suspension"] = IsVisible(fields, "periodOfSuspension") ? GetFieldValue(emp, fields, "periodOfSuspension") : null;
                
                row["AccNo"] = (IsVisible(fields, "bankAccountNumber") || IsVisible(fields, "accountNumber")) ? GetFieldValue(emp, fields, "accountNumber") : null;
                row["BankName"] = (IsVisible(fields, "bankName") || IsVisible(fields, "bank")) ? GetFieldValue(emp, fields, "bankName") : null;
                row["BranchName"] = (IsVisible(fields, "bankBranch") || IsVisible(fields, "branch") || IsVisible(fields, "branchName")) ? GetFieldValue(emp, fields, "branchName") : null;
                row["IfscCode"] = (IsVisible(fields, "bankIfsc") || IsVisible(fields, "ifsc") || IsVisible(fields, "ifscCode")) ? GetFieldValue(emp, fields, "ifscCode") : null;

                row["Mobile"] = IsVisible(fields, "mobile") ? GetFieldValue(emp, fields, "mobile") : null;
                row["Email"] = IsVisible(fields, "email") ? GetFieldValue(emp, fields, "email") : null;
                row["ExitDate"] = (IsVisible(fields, "dateOfExit") || IsVisible(fields, "exitDate")) ? GetFieldValue(emp, fields, "dateOfExit") : null;
                row["ExitReason"] = (IsVisible(fields, "reasonForExit") || IsVisible(fields, "exitReason")) ? GetFieldValue(emp, fields, "reasonForExit") : null;
                row["Remarks"] = IsVisible(fields, "remarks") ? GetFieldValue(emp, fields, "remarks") : null;

                var mappedKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase) 
                { 
                    "name", "employeeCode", "empCode", "gender", "fatherOrSpouse", "fatherName", "dateOfBirth", "dob", "joiningDate", "dateOfJoining", 
                    "designation", "department", "presentAddress", "permanentAddress", "employeePfNo", "pfNo", 
                    "employeeEsicNo", "esicNo", "employeeAadharNo", "aadharNo", "days80ServiceCompletionDate", 
                    "permanentAppointmentDate", "periodOfSuspension", "bankAccountNumber", "accountNumber", 
                    "bankName", "bank", "accountHolderName", "bankBranch", "branch", "branchName", "bankIfsc", "ifsc", "ifscCode",
                    "mobile", "email", "dateOfExit", "exitDate", "reasonForExit", "exitReason", "remarks"
                };

                var additionalInfo = new StringBuilder();
                var surplusFields = fields.Where(f => f.IsVisible && f.FieldMetadata != null && !mappedKeys.Contains(f.FieldMetadata.FieldKey)).ToList();
                foreach (var f in surplusFields)
                {
                    var val = GetFieldValue(emp, f);
                    if (val != "--") additionalInfo.AppendLine($"{f.CustomLabel ?? f.FieldMetadata?.DisplayLabel}: {val}");
                }
                row["AdditionalData"] = additionalInfo.Length > 0 ? additionalInfo.ToString() : null;

                row["Photo"] = (object?)GetImageBytes(emp.ProfilePictureUrl) ?? DBNull.Value;
                row["Signature"] = (object?)GetImageBytes(emp.SignatureImageUrl) ?? DBNull.Value;
                
                dt.Rows.Add(row);
            }

            var templateName = formTemplate == "12" ? "Form_12.rdlc" : "Form_U.rdlc";
            var reportPath = Path.Combine(Directory.GetCurrentDirectory(), "ReportTemplate", templateName);
            if (!File.Exists(reportPath)) throw new FileNotFoundException($"Report template not found at {reportPath}");

            using var localReport = new LocalReport();
            localReport.ReportPath = reportPath;
            localReport.DataSources.Add(new ReportDataSource("EmployeeDataSet", dt));

            return localReport.Render("PDF");
        }

        private string GetFieldValue(Employee emp, List<OrganizationFieldAccess> fields, string key)
        {
            var fa = fields.FirstOrDefault(f => string.Equals(f.FieldMetadata?.FieldKey, key, StringComparison.OrdinalIgnoreCase));
            if (fa == null) return "--";
            return GetFieldValue(emp, fa);
        }

        private bool IsVisible(List<OrganizationFieldAccess> fields, string key)
        {
            return fields.Any(f => f.IsVisible && string.Equals(f.FieldMetadata?.FieldKey, key, StringComparison.OrdinalIgnoreCase));
        }

        private byte[]? GetImageBytes(string? relativeUrl)
        {
            if (string.IsNullOrEmpty(relativeUrl)) return null;
            try
            {
                var path = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", relativeUrl.TrimStart('/'));
                if (File.Exists(path)) return File.ReadAllBytes(path);
            }
            catch { }
            return null;
        }

        private string GetFieldValue(Employee emp, OrganizationFieldAccess fieldAccess)
        {
            var meta = fieldAccess.FieldMetadata;
            if (meta == null) return "--";

            var fieldKey = meta.FieldKey;
            
            if (fieldKey.Equals("name", StringComparison.OrdinalIgnoreCase))
                return (string.IsNullOrEmpty(emp.Salutation) ? emp.Name : (emp.Salutation + " " + emp.Name)).Trim();

            if (fieldKey.Equals("bankName", StringComparison.OrdinalIgnoreCase))
                return emp.BankDetails?.AccountHolderName ?? "--";

            if (fieldKey.Equals("bankAccountNumber", StringComparison.OrdinalIgnoreCase) || fieldKey.Equals("accountNumber", StringComparison.OrdinalIgnoreCase)) 
                return emp.BankDetails?.AccountNumber?.ToString() ?? "--";
            if (fieldKey.Equals("bankBranch", StringComparison.OrdinalIgnoreCase) || fieldKey.Equals("branch", StringComparison.OrdinalIgnoreCase) || fieldKey.Equals("branchName", StringComparison.OrdinalIgnoreCase)) 
                return emp.BankDetails?.Branch ?? "--";
            if (fieldKey.Equals("bankIfsc", StringComparison.OrdinalIgnoreCase) || fieldKey.Equals("ifsc", StringComparison.OrdinalIgnoreCase) || fieldKey.Equals("ifscCode", StringComparison.OrdinalIgnoreCase)) 
                return emp.BankDetails?.Ifsc ?? "--";

            var prop = typeof(Employee).GetProperty(fieldKey, BindingFlags.IgnoreCase | BindingFlags.Public | BindingFlags.Instance);
            if (prop != null)
            {
                var val = prop.GetValue(emp);
                if (val is DateTime dt) return dt.ToString("dd-MM-yyyy");
                var valStr = val?.ToString();
                if (!string.IsNullOrEmpty(valStr)) return valStr;
                return "--";
            }

            if (!string.IsNullOrEmpty(emp.CustomFieldsJson))
            {
                try 
                {
                    var customData = JsonConvert.DeserializeObject<Dictionary<string, string>>(emp.CustomFieldsJson);
                    if (customData != null && customData.ContainsKey(fieldKey))
                    {
                        var customVal = customData[fieldKey];
                        if (!string.IsNullOrEmpty(customVal)) return customVal;
                    }
                } 
                catch { }
            }
            return "--";
        }

        public byte[] GenerateMustorRollsPdf(List<MustorRollRecord> records, Organization org)
        {
            Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);

            var dt = new DataTable();
            dt.TableName = "MustorDataSet";
            dt.Columns.Add("OrgName");
            dt.Columns.Add("OrgAddress");
            dt.Columns.Add("SlNo");
            dt.Columns.Add("WomanName");
            dt.Columns.Add("Age");
            dt.Columns.Add("HusbandOrFatherName");
            dt.Columns.Add("NatureOfWork");
            dt.Columns.Add("DateOfEmployment");
            dt.Columns.Add("AttendanceText");
            dt.Columns.Add("NoticePregnancyDate");
            dt.Columns.Add("NoticeDeliveryDate");
            dt.Columns.Add("ProofBirthDate");
            dt.Columns.Add("ProofDeathDate");
            dt.Columns.Add("AdvanceAmount");
            dt.Columns.Add("AdvanceDate");
            dt.Columns.Add("SubsequentAmount");
            dt.Columns.Add("SubsequentDate");
            dt.Columns.Add("BonusAmount");
            dt.Columns.Add("LeaveWagesSec9");
            dt.Columns.Add("LeaveWagesSec10");
            dt.Columns.Add("Remarks");

            int serial = 1;
            foreach (var rec in records)
            {
                var row = dt.NewRow();
                row["OrgName"] = org.Name;
                row["OrgAddress"] = org.Address ?? "";
                row["SlNo"] = serial++.ToString();
                row["WomanName"] = rec.WomanName;
                row["Age"] = rec.Age?.ToString() ?? "";
                row["HusbandOrFatherName"] = rec.HusbandOrFatherName ?? "";
                row["NatureOfWork"] = rec.NatureOfWork ?? "";
                row["DateOfEmployment"] = rec.DateOfEmployment?.ToString("dd-MM-yyyy") ?? "";
                
                var attendanceText = "";
                if (!string.IsNullOrEmpty(rec.AttendanceJson))
                {
                    try
                    {
                        var attList = JsonConvert.DeserializeObject<List<MustorAttendanceRow>>(rec.AttendanceJson);
                        if (attList != null)
                        {
                            foreach (var att in attList) attendanceText += $"{att.MonthYear,-15} {att.DaysEmployed ?? 0,5} {(att.DaysLaidOff ?? 0),12} {(att.DaysNotEmployed ?? 0),12}\n";
                        }
                    }
                    catch { }
                }
                row["AttendanceText"] = attendanceText;
                row["NoticePregnancyDate"] = rec.NoticePregnancyDate?.ToString("dd-MM-yyyy") ?? "";
                row["NoticeDeliveryDate"] = rec.NoticeDeliveryDate?.ToString("dd-MM-yyyy") ?? "";
                row["ProofBirthDate"] = rec.ProofBirthDate?.ToString("dd-MM-yyyy") ?? "";
                row["ProofDeathDate"] = rec.ProofDeathDate?.ToString("dd-MM-yyyy") ?? "";
                row["AdvanceAmount"] = rec.AdvanceAmount?.ToString("0.00") ?? "";
                row["AdvanceDate"] = rec.AdvanceDate?.ToString("dd-MM-yyyy") ?? "";
                row["SubsequentAmount"] = rec.SubsequentAmount?.ToString("0.00") ?? "";
                row["SubsequentDate"] = rec.SubsequentDate?.ToString("dd-MM-yyyy") ?? "";
                row["BonusAmount"] = rec.BonusAmount?.ToString("0.00") ?? "";
                row["LeaveWagesSec9"] = rec.LeaveWagesSec9?.ToString("0.00") ?? "";
                row["LeaveWagesSec10"] = rec.LeaveWagesSec10?.ToString("0.00") ?? "";
                row["Remarks"] = rec.Remarks ?? "";

                dt.Rows.Add(row);
            }

            var reportPath = Path.Combine(Directory.GetCurrentDirectory(), "ReportTemplate", "Form_A.rdlc");
            using var localReport = new LocalReport();
            localReport.ReportPath = reportPath;
            localReport.DataSources.Add(new ReportDataSource("MustorDataSet", dt));

            return localReport.Render("PDF");
        }

        public byte[] GenerateMustorRollsExcel(List<MustorRollRecord> records, Organization org)
        {
            using (var workbook = new XLWorkbook())
            {
                var worksheet = workbook.Worksheets.Add("Mustor Roll");
                int currentRow = 1;
                string[] headers = {
                    "Sl No", "Woman Name", "Age", "Husband/Father Name", "Nature of Work", "Date of Employment",
                    "Attendance", "Notice Pregnancy", "Notice Delivery", "Proof Birth", "Proof Death",
                    "Advance Amt", "Advance Date", "Subsequent Amt", "Subsequent Date", "Bonus",
                    "Leave Wages Sec9", "Leave Wages Sec10", "Remarks"
                };

                for (int i = 0; i < headers.Length; i++) worksheet.Cell(currentRow, i + 1).Value = headers[i];

                var headerRange = worksheet.Range(1, 1, 1, headers.Length);
                headerRange.Style.Font.Bold = true;
                headerRange.Style.Fill.BackgroundColor = XLColor.LightGray;

                int serial = 1;
                foreach (var rec in records)
                {
                    currentRow++;
                    worksheet.Cell(currentRow, 1).Value = serial++;
                    worksheet.Cell(currentRow, 2).Value = rec.WomanName;
                    worksheet.Cell(currentRow, 3).Value = rec.Age?.ToString() ?? "";
                    worksheet.Cell(currentRow, 4).Value = rec.HusbandOrFatherName ?? "";
                    worksheet.Cell(currentRow, 5).Value = rec.NatureOfWork ?? "";
                    worksheet.Cell(currentRow, 6).Value = rec.DateOfEmployment?.ToString("dd-MM-yyyy") ?? "";
                    
                    var attendanceText = "";
                    if (!string.IsNullOrEmpty(rec.AttendanceJson))
                    {
                        try
                        {
                            var attList = JsonConvert.DeserializeObject<List<MustorAttendanceRow>>(rec.AttendanceJson);
                            if (attList != null)
                            {
                                foreach (var att in attList) attendanceText += $"{att.MonthYear}: E={att.DaysEmployed ?? 0}, L={att.DaysLaidOff ?? 0}, N={att.DaysNotEmployed ?? 0}\n";
                            }
                        }
                        catch { }
                    }
                    worksheet.Cell(currentRow, 7).Value = attendanceText;
                    worksheet.Cell(currentRow, 8).Value = rec.NoticePregnancyDate?.ToString("dd-MM-yyyy") ?? "";
                    worksheet.Cell(currentRow, 9).Value = rec.NoticeDeliveryDate?.ToString("dd-MM-yyyy") ?? "";
                    worksheet.Cell(currentRow, 10).Value = rec.ProofBirthDate?.ToString("dd-MM-yyyy") ?? "";
                    worksheet.Cell(currentRow, 11).Value = rec.ProofDeathDate?.ToString("dd-MM-yyyy") ?? "";
                    worksheet.Cell(currentRow, 12).Value = rec.AdvanceAmount?.ToString("0.00") ?? "";
                    worksheet.Cell(currentRow, 13).Value = rec.AdvanceDate?.ToString("dd-MM-yyyy") ?? "";
                    worksheet.Cell(currentRow, 14).Value = rec.SubsequentAmount?.ToString("0.00") ?? "";
                    worksheet.Cell(currentRow, 15).Value = rec.SubsequentDate?.ToString("dd-MM-yyyy") ?? "";
                    worksheet.Cell(currentRow, 16).Value = rec.BonusAmount?.ToString("0.00") ?? "";
                    worksheet.Cell(currentRow, 17).Value = rec.LeaveWagesSec9?.ToString("0.00") ?? "";
                    worksheet.Cell(currentRow, 18).Value = rec.LeaveWagesSec10?.ToString("0.00") ?? "";
                    worksheet.Cell(currentRow, 19).Value = rec.Remarks ?? "";
                }
                worksheet.Columns().AdjustToContents();
                using var stream = new MemoryStream();
                workbook.SaveAs(stream);
                return stream.ToArray();
            }
        }

        public byte[] GenerateDangerousOccurrencesPdf(List<DangerousOccurrence> records, Organization org)
        {
            Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
            var dt = new DataTable();
            dt.TableName = "DangerousOccurrenceDataSet";
            dt.Columns.Add("OrgName");
            dt.Columns.Add("OrgAddress");
            dt.Columns.Add("CalendarYear");
            dt.Columns.Add("SerialNo");
            dt.Columns.Add("OccurrenceDateTime");
            dt.Columns.Add("ReportDespatchDate");
            dt.Columns.Add("Place");
            dt.Columns.Add("Description");
            dt.Columns.Add("DamageDetails");
            dt.Columns.Add("Remarks");

            foreach (var rec in records)
            {
                var row = dt.NewRow();
                row["OrgName"] = org.Name;
                row["OrgAddress"] = org.Address ?? "";
                row["CalendarYear"] = rec.CalendarYear.ToString();
                if (rec.DangerousOccurrenceSerialNo == 0)
                {
                    row["SerialNo"] = "---------";
                    row["OccurrenceDateTime"] = "No Dangerous";
                    row["ReportDespatchDate"] = "Occurrences";
                    row["Place"] = "happened";
                    row["Description"] = "during the Year";
                    row["DamageDetails"] = rec.CalendarYear.ToString();
                    row["Remarks"] = "---------";
                }
                else
                {
                    row["SerialNo"] = rec.DangerousOccurrenceSerialNo.ToString();
                    row["OccurrenceDateTime"] = rec.OccurrenceDatetime?.ToString("dd-MM-yyyy HH:mm") ?? "---------";
                    row["ReportDespatchDate"] = rec.Form18aDespatchDate?.ToString("dd-MM-yyyy") ?? "---------";
                    row["Place"] = rec.DangerousOccurrencePlace ?? "---------";
                    row["Description"] = rec.OccurrenceDescriptionActionTaken ?? "---------";
                    row["DamageDetails"] = rec.DamageDetailsDamageLossRepairReplacementCost ?? "---------";
                    row["Remarks"] = rec.ManagerRemarksAndInitials ?? "---------";
                }
                dt.Rows.Add(row);
            }

            var reportPath = Path.Combine(Directory.GetCurrentDirectory(), "ReportTemplate", "Form_26_A.rdlc");
            using var localReport = new LocalReport();
            localReport.ReportPath = reportPath;
            localReport.DataSources.Add(new ReportDataSource("DangerousOccurrenceDataSet", dt));
            return localReport.Render("PDF");
        }

        public byte[] GenerateDangerousOccurrencesExcel(List<DangerousOccurrence> records, Organization org)
        {
            using (var workbook = new XLWorkbook())
            {
                var worksheet = workbook.Worksheets.Add("Dangerous Occurrences");
                var currentRow = 1;
                worksheet.Cell(currentRow, 1).Value = "Sl. No.";
                worksheet.Cell(currentRow, 2).Value = "Calendar Year";
                worksheet.Cell(currentRow, 3).Value = "Date & Hour of Occurrence";
                worksheet.Cell(currentRow, 4).Value = "Date of Despatch of Report";
                worksheet.Cell(currentRow, 5).Value = "Place of Occurrence";
                worksheet.Cell(currentRow, 6).Value = "Nature of Occurrence & Action Taken";
                worksheet.Cell(currentRow, 7).Value = "Details of Damage/Repair Cost";
                worksheet.Cell(currentRow, 8).Value = "Manager's Remarks";

                var headerRange = worksheet.Range(currentRow, 1, currentRow, 8);
                headerRange.Style.Font.Bold = true;
                headerRange.Style.Fill.BackgroundColor = XLColor.LightGray;
                headerRange.Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
                headerRange.Style.Border.InsideBorder = XLBorderStyleValues.Thin;

                foreach (var rec in records)
                {
                    currentRow++;
                    if (rec.DangerousOccurrenceSerialNo == 0)
                    {
                        worksheet.Cell(currentRow, 1).Value = "---------";
                        worksheet.Cell(currentRow, 2).Value = rec.CalendarYear;
                        worksheet.Cell(currentRow, 3).Value = rec.DangerousOccurrencePlace ?? "No Dangerous Occurrences";
                        worksheet.Range(currentRow, 3, currentRow, 8).Merge().Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
                    }
                    else
                    {
                        worksheet.Cell(currentRow, 1).Value = rec.DangerousOccurrenceSerialNo;
                        worksheet.Cell(currentRow, 2).Value = rec.CalendarYear;
                        worksheet.Cell(currentRow, 3).Value = rec.OccurrenceDatetime?.ToString("dd-MM-yyyy HH:mm") ?? "---------";
                        worksheet.Cell(currentRow, 4).Value = rec.Form18aDespatchDate?.ToString("dd-MM-yyyy") ?? "---------";
                        worksheet.Cell(currentRow, 5).Value = rec.DangerousOccurrencePlace ?? "---------";
                        worksheet.Cell(currentRow, 6).Value = rec.OccurrenceDescriptionActionTaken ?? "---------";
                        worksheet.Cell(currentRow, 7).Value = rec.DamageDetailsDamageLossRepairReplacementCost ?? "---------";
                        worksheet.Cell(currentRow, 8).Value = rec.ManagerRemarksAndInitials ?? "---------";
                    }
                    worksheet.Range(currentRow, 1, currentRow, 8).Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
                    worksheet.Range(currentRow, 1, currentRow, 8).Style.Border.InsideBorder = XLBorderStyleValues.Thin;
                }
                worksheet.Columns().AdjustToContents();
                using var stream = new MemoryStream();
                workbook.SaveAs(stream);
                return stream.ToArray();
            }
        }
    }
}
