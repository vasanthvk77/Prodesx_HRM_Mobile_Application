using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using System.Data;
using backend.Models;
using backend.Data;
using backend.Hubs;
using backend.Services;

namespace backend.Controllers
{
    public class BulkPaySlipRequest
    {
        public byte Month { get; set; }
        public int SalaryYearId { get; set; }
        public int Year { get; set; }
    }

    [Authorize]
    [ApiController]
    [Route("api/staff-salary")]
    public class StaffSalaryController : ControllerBase
    {
        private readonly DataBaseConnection _db;
        private readonly IHubContext<StaffSalaryHub> _hubContext;
        private readonly ILogger<StaffSalaryController> _logger;
        private readonly ExportService _exportService;

        public StaffSalaryController(DataBaseConnection db, IHubContext<StaffSalaryHub> hubContext, ILogger<StaffSalaryController> logger, ExportService exportService)
        {
            _db = db;
            _hubContext = hubContext;
            _logger = logger;
            _exportService = exportService;
        }

        private int GetOrgId()
        {
            var claim = User.FindFirst("OrganizationId")?.Value;
            return int.TryParse(claim, out var id) ? id : 0;
        }

        private int GetUserId()
        {
            var claim = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
            return int.TryParse(claim, out var id) ? id : 0;
        }

        /// <summary>
        /// Live payroll calculation — called when admin clicks "Calculate".
        /// Pure SELECT, no data is inserted. Always reflects current attendance.
        /// </summary>
        [HttpGet("preview")]
        public async Task<IActionResult> GetPayrollPreview([FromQuery] int salaryYearId, [FromQuery] byte month, [FromQuery] int year)
        {
            var orgId = GetOrgId();
            try
            {
                using var conn = _db.CreateConnection();
                var parameters = new DynamicParameters();
                parameters.Add("@OrganizationId", orgId);
                parameters.Add("@SalaryYearId", salaryYearId);
                parameters.Add("@Month", month);
                parameters.Add("@Year", year);

                var preview = await conn.QueryAsync<PayrollPreviewModel>(
                    "sp_GetMonthlySalaryPreview", parameters, commandType: CommandType.StoredProcedure);

                int totalDays = DateTime.DaysInMonth(year, month);
                var result = preview.ToList();
                foreach (var item in result) item.TotalDaysInMonth = totalDays;

                return Ok(result);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching payroll preview for OrgId: {OrgId}", orgId);
                return StatusCode(500, new { message = ex.Message });
            }
        }

        /// <summary>
        /// Saves or updates a salary record (Snapshot).
        /// </summary>
        [HttpPost]
        public async Task<IActionResult> UpsertSalary([FromBody] CreateStaffSalaryRequest req)
        {
            var orgId = GetOrgId();
            var userId = GetUserId();

            try
            {
                using var conn = _db.CreateConnection();
                var parameters = new DynamicParameters();
                parameters.Add("@OrganizationId", orgId);
                parameters.Add("@SalaryYearId", req.SalaryYearId);
                parameters.Add("@Month", req.Month);
                parameters.Add("@EmployeeId", req.EmployeeId);
                parameters.Add("@BaseBasicPay", req.BaseBasicPay);
                parameters.Add("@PresentDays", req.PresentDays);
                parameters.Add("@TotalDaysInMonth", req.TotalDaysInMonth);
                parameters.Add("@AllowancesDetail", req.AllowancesDetail);
                parameters.Add("@DeductionsDetail", req.DeductionsDetail);
                parameters.Add("@NetSalary", req.NetSalary);
                parameters.Add("@TotalAllowance", req.TotalAllowance);
                parameters.Add("@TotalDeduction", req.TotalDeduction);
                parameters.Add("@CreatedBy", userId);

                await conn.ExecuteAsync("sp_UpsertStaffSalary", parameters, commandType: CommandType.StoredProcedure);
                return Ok(new { message = "Salary saved successfully" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error upserting salary for EmployeeId: {EmployeeId}", req.EmployeeId);
                return StatusCode(500, new { message = ex.Message });
            }
        }

        /// <summary>
        /// Finalizes/Locks the salary records.
        /// </summary>
        [HttpPost("finalize")]
        public async Task<IActionResult> FinalizeSalary([FromBody] FinalizeSalaryRequest req)
        {
            var orgId = GetOrgId();
            var userId = GetUserId();

            try
            {
                using var conn = _db.CreateConnection();
                var parameters = new DynamicParameters();
                parameters.Add("@OrganizationId", orgId);
                parameters.Add("@SalaryYearId", req.SalaryYearId);
                parameters.Add("@Month", req.Month);
                parameters.Add("@EmployeeId", req.EmployeeId);
                parameters.Add("@IsFinalized", req.IsFinalized);
                parameters.Add("@UpdatedBy", userId);

                await conn.ExecuteAsync("sp_FinalizeStaffSalary", parameters, commandType: CommandType.StoredProcedure);
                return Ok(new { message = req.IsFinalized ? "Payroll finalized and locked" : "Payroll unlocked" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error finalizing salary");
                return StatusCode(500, new { message = ex.Message });
            }
        }

        /// <summary>
        /// Gets all generated salary records for an organization for a specific month.
        /// Useful for showing previously SAVED data instead of a live preview.
        /// </summary>
        [HttpGet("org/{month}")]
        public async Task<IActionResult> GetMonthlySalaries([FromRoute] byte month, [FromQuery] int salaryYearId)
        {
            var orgId = GetOrgId();
            try
            {
                using var conn = _db.CreateConnection();
                var parameters = new DynamicParameters();
                parameters.Add("@OrganizationId", orgId);
                
                var salaries = await conn.QueryAsync<StaffSalary>(
                    "sp_GetStaffSalariesByOrg", parameters, commandType: CommandType.StoredProcedure);
                
                var filtered = salaries.Where(s => s.Month == month && s.SalaryYearId == salaryYearId);
                return Ok(filtered.ToList());
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching organization salaries");
                return StatusCode(500, new { message = ex.Message });
            }
        }

        /// <summary>
        /// Returns salary history for a single employee across all months.
        /// </summary>
        [HttpGet("employee/{employeeId}")]
        public async Task<IActionResult> GetEmployeeSalaries(int employeeId)
        {
            try
            {
                using var conn = _db.CreateConnection();
                var parameters = new DynamicParameters();
                parameters.Add("@EmployeeId", employeeId);
                var salaries = await conn.QueryAsync<StaffSalary>(
                    "sp_GetStaffSalariesByEmployeeId", parameters, commandType: CommandType.StoredProcedure);
                return Ok(salaries);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching salaries for EmployeeId: {EmployeeId}", employeeId);
                return StatusCode(500, new { message = ex.Message });
            }
        }

        [HttpGet("export")]
        public async Task<IActionResult> ExportStaffSalary([FromQuery] byte month, [FromQuery] int salaryYearId, [FromQuery] int year, [FromQuery] string type = "excel")
        {
            var orgId = GetOrgId();
            try
            {
                using var conn = _db.CreateConnection();
                
                // 1. Fetch Organization Info
                var org = await conn.QueryFirstOrDefaultAsync<Organization>(
                    "sp_GetOrganizationById",
                    new { Id = orgId },
                    commandType: CommandType.StoredProcedure
                );
                if (org == null) return NotFound("Organization not found");

                // 2. Fetch Saved Salary Records
                var parameters = new DynamicParameters();
                parameters.Add("@OrganizationId", orgId);
                var salaries = await conn.QueryAsync<StaffSalary>(
                    "sp_GetStaffSalariesByOrg", parameters, commandType: CommandType.StoredProcedure);
                
                var filtered = salaries.Where(s => s.Month == month && s.SalaryYearId == salaryYearId).ToList();

                if (!filtered.Any()) return BadRequest("No saved salary records found for the selected month to export. Please calculate and save first.");

                string monthName = new DateTime(year, month, 1).ToString("MMM_yyyy");
                
                // 3. Generate File
                if (type.ToLower() == "pdf")
                {
                    var fileData = _exportService.GenerateStaffSalaryPdf(filtered, org, month, year);
                    return File(fileData, "application/pdf", $"Salary_Register_{monthName}.pdf");
                }
                else
                {
                    var fileData = _exportService.GenerateStaffSalaryExcel(filtered, org, month, year);
                    return File(fileData, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", $"Salary_Register_{monthName}.xlsx");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Export staff salary failed");
                return StatusCode(500, new { message = "Export failed", details = ex.Message });
            }
        }

        [HttpGet("payslip/{employeeId}")]
        public async Task<IActionResult> DownloadPaySlip(int employeeId, [FromQuery] byte month, [FromQuery] int salaryYearId, [FromQuery] int year)
        {
            var orgId = GetOrgId();
            try
            {
                using var conn = _db.CreateConnection();
                
                // 1. Fetch Organization Info
                var org = await conn.QueryFirstOrDefaultAsync<Organization>(
                    "sp_GetOrganizationById",
                    new { Id = orgId },
                    commandType: CommandType.StoredProcedure
                );
                if (org == null) return NotFound("Organization not found");

                // 2. Fetch Employee Info
                var employee = await conn.QueryFirstOrDefaultAsync<Employee>(
                    "sp_GetEmployeeById",
                    new { Id = employeeId, OrganizationId = orgId },
                    commandType: CommandType.StoredProcedure
                );
                if (employee == null) return NotFound("Employee not found");

                // 2b. Fetch Bank Details
                var bankDetails = await conn.QueryFirstOrDefaultAsync(
                    "sp_GetEmployeeAccountDetails",
                    new { EmployeeId = employeeId },
                    commandType: CommandType.StoredProcedure
                );
                if (bankDetails != null)
                {
                    employee.AccountNumber = bankDetails.AccountNumber?.ToString();
                    employee.BankName = bankDetails.Branch;
                    employee.IfscCode = bankDetails.Ifsc;
                }

                // 3. Fetch Selected Month Salary Record
                var parameters = new DynamicParameters();
                parameters.Add("@OrganizationId", orgId);
                var salaries = await conn.QueryAsync<StaffSalary>(
                    "sp_GetStaffSalariesByOrg", parameters, commandType: CommandType.StoredProcedure);
                
                var salary = salaries.FirstOrDefault(s => s.EmployeeId == employeeId && s.Month == month && s.SalaryYearId == salaryYearId);

                if (salary == null) return BadRequest("Salary record not found for this employee and month. Please calculate and save first.");

                // 4. Generate PDF
                var fileData = _exportService.GenerateIndividualPaySlipPdf(salary, employee, org, month, year);

                string fileName = $"PaySlip_{employee.Name?.Replace(" ", "_") ?? employeeId.ToString()}_{new DateTime(year, month, 1):MMM_yyyy}.pdf";
                return File(fileData, "application/pdf", fileName);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Download pay slip failed");
                return StatusCode(500, new { message = "Failed to generate pay slip", details = ex.Message });
            }
        }

        [HttpPost("payslip/bulk")]
        public async Task<IActionResult> DownloadBulkPaySlips([FromBody] BulkPaySlipRequest req)
        {
            var orgId = GetOrgId();
            try
            {
                if (req.Month == 0 || req.SalaryYearId == 0)
                    return BadRequest("Invalid filter criteria provided.");

                using var conn = _db.CreateConnection();
                
                var org = await conn.QueryFirstOrDefaultAsync<Organization>(
                    "sp_GetOrganizationById", new { Id = orgId }, commandType: CommandType.StoredProcedure);
                if (org == null) return NotFound("Organization not found");

                var parameters = new DynamicParameters();
                parameters.Add("@OrganizationId", orgId);
                var allSalaries = await conn.QueryAsync<StaffSalary>(
                    "sp_GetStaffSalariesByOrg", parameters, commandType: CommandType.StoredProcedure);
                
                var targetSalaries = allSalaries.Where(s => s.Month == req.Month && s.SalaryYearId == req.SalaryYearId).ToList();
                
                if (!targetSalaries.Any()) return BadRequest("No salary records found for the selected month.");

                using var ms = new MemoryStream();
                using (var archive = new System.IO.Compression.ZipArchive(ms, System.IO.Compression.ZipArchiveMode.Create, true))
                {
                    foreach (var salary in targetSalaries)
                    {
                        var employee = await conn.QueryFirstOrDefaultAsync<Employee>(
                            "sp_GetEmployeeById", new { Id = salary.EmployeeId, OrganizationId = orgId }, commandType: CommandType.StoredProcedure);
                        if (employee == null) continue;

                        var bankDetails = await conn.QueryFirstOrDefaultAsync(
                            "sp_GetEmployeeAccountDetails", new { EmployeeId = employee.Id }, commandType: CommandType.StoredProcedure);
                        if (bankDetails != null)
                        {
                            employee.AccountNumber = bankDetails.AccountNumber?.ToString();
                            employee.BankName = bankDetails.Branch;
                            employee.IfscCode = bankDetails.Ifsc;
                        }

                        var fileData = _exportService.GenerateIndividualPaySlipPdf(salary, employee, org, req.Month, req.Year);
                        string cleanName = employee.Name?.Replace(" ", "_") ?? employee.Id.ToString();
                        string fileName = $"PaySlip_{cleanName}_{new DateTime(req.Year, req.Month, 1):MMM_yyyy}.pdf";
                        
                        var entry = archive.CreateEntry(fileName, System.IO.Compression.CompressionLevel.Fastest);
                        using var entryStream = entry.Open();
                        entryStream.Write(fileData, 0, fileData.Length);
                    }
                }
                ms.Seek(0, SeekOrigin.Begin);
                string zipName = $"PaySlips_Bulk_{new DateTime(req.Year, req.Month, 1):MMM_yyyy}.zip";
                return File(ms.ToArray(), "application/zip", zipName);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Download bulk pay slips failed");
                return StatusCode(500, new { message = "Failed to generate bulk pay slips", details = ex.Message });
            }
        }
    }
}
