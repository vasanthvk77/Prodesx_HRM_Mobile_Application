using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Data;
using backend.Models;
using backend.Data;
using backend.Hubs;
using Microsoft.AspNetCore.SignalR;
using System.IO;

namespace backend.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class EmployeesController : ControllerBase
{
    private readonly DataBaseConnection _db;
    private readonly ILogger<EmployeesController> _logger;
    private readonly IHubContext<EmployeesHub> _hubContext;
    private readonly backend.Services.ExportService _exportService;

    public EmployeesController(DataBaseConnection db, ILogger<EmployeesController> logger, IHubContext<EmployeesHub> hubContext, backend.Services.ExportService exportService)
    {
        _db = db;
        _logger = logger;
        _hubContext = hubContext;
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

    // GET /api/employees — list all employees for the specified org or the caller's primary org
    [HttpGet]
    public async Task<IActionResult> GetEmployees([FromQuery] int? organizationId)
    {
        var userOrgId = GetOrgId();
        var targetOrgId = (organizationId.HasValue && organizationId > 0) ? organizationId.Value : userOrgId;

        _logger.LogInformation("[Employees] GET all | TargetOrgId={TargetOrgId} | UserOrgId={UserOrgId}", targetOrgId, userOrgId);
        
        try
        {
            using var conn = _db.CreateConnection();
            var employees = await conn.QueryAsync<Employee>(
                "sp_GetEmployees",
                new { OrganizationId = targetOrgId },
                commandType: CommandType.StoredProcedure);
            return Ok(employees);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Employees] GET failed | OrgId={OrgId}", targetOrgId);
            return StatusCode(500, "Failed to fetch employees");
        }
    }

    // GET /api/employees/unlinked-users — users in this org with no employee profile yet
    [HttpGet("unlinked-users")]
    public async Task<IActionResult> GetUnlinkedUsers()
    {
        var orgId = GetOrgId();
        try
        {
            using var conn = _db.CreateConnection();
            var users = await conn.QueryAsync<UnlinkedUser>(
                "sp_GetUnlinkedUsers",
                new { OrganizationId = orgId },
                commandType: CommandType.StoredProcedure);
            return Ok(users);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Employees] GET unlinked-users failed | OrgId={OrgId}", orgId);
            return StatusCode(500, "Failed to fetch unlinked users");
        }
    }

    // POST /api/employees — create an employee HR profile.
    // Does NOT create a user login. Login accounts are managed via Manage Users.
    // Auto-links to an existing user account if the email already exists in users.
    [HttpPost]
    public async Task<IActionResult> CreateEmployee([FromBody] CreateEmployeeRequest req)
    {
        var orgId = GetOrgId();
        var resolvedOrgId = (req.OrganizationId.HasValue && req.OrganizationId > 0)
            ? req.OrganizationId.Value
            : orgId;

        _logger.LogInformation("[Employees] CREATE | Name={Name} | OrgId={OrgId}",
            req.Name, resolvedOrgId);

        // Validate required fields
        if (string.IsNullOrWhiteSpace(req.Name))
            return BadRequest(new { message = "Employee name is required" });
        if (string.IsNullOrWhiteSpace(req.Email))
            return BadRequest(new { message = "Employee email is required" });

        try
        {
            using var conn = _db.CreateConnection();

            // Verify organization exists
            var orgExists = await conn.ExecuteScalarAsync<int>(
                "sp_OrganizationExistsById",
                new { OrgId = resolvedOrgId },
                commandType: CommandType.StoredProcedure);

            if (orgExists == 0)
            {
                _logger.LogError("[Employees] CREATE failed | Organization does not exist | OrgId={OrgId}", resolvedOrgId);
                return BadRequest(new { message = $"Organization with ID {resolvedOrgId} does not exist" });
            }

            var newId = await conn.ExecuteScalarAsync<int>("sp_CreateEmployee", new
            {
                OrganizationId      = resolvedOrgId,
                LinkToUserId        = req.LinkToUserId,
                EmployeeCode        = req.EmployeeCode,
                Salutation          = req.Salutation,
                Name                = req.Name,
                Email               = req.Email,
                Designation         = req.Designation,
                Gender              = req.Gender,
                Mobile              = req.Mobile,
                JoiningDate         = req.JoiningDate,
                DateOfBirth         = req.DateOfBirth,
                ProfilePictureUrl   = req.ProfilePictureUrl,
                
                // New Fields
                FatherOrSpouse      = req.FatherOrSpouse,
                PresentAddress      = req.PresentAddress,
                PermanentAddress    = req.PermanentAddress,
                EmployeePfNo        = req.EmployeePfNo,
                EmployeeEsicNo      = req.EmployeeEsicNo,
                EmployeeAadharNo    = req.EmployeeAadharNo,
                Days80ServiceCompletionDate = req.Days80ServiceCompletionDate,
                PermanentAppointmentDate    = req.PermanentAppointmentDate,
                PeriodOfSuspension  = req.PeriodOfSuspension,
                SignatureImageUrl   = req.SignatureImageUrl,
                ThumbImpressionImageUrl = req.ThumbImpressionImageUrl,
                DateOfExit          = req.DateOfExit,
                ReasonForExit       = req.ReasonForExit,
                Department          = req.Department,
                DepartmentId        = req.DepartmentId,
                DesignationId       = req.DesignationId,
                Remarks             = req.Remarks,
                CustomFieldsJson    = req.CustomFieldsJson,
                CreatedBy           = GetUserId()
            }, commandType: CommandType.StoredProcedure);

            // Validate that the stored procedure returned a valid ID
            if (newId <= 0)
            {
                _logger.LogError("[Employees] CREATE returned invalid ID: {Id} | Name={Name} | OrgId={OrgId}", newId, req.Name, resolvedOrgId);
                return StatusCode(500, new { message = "Failed to create employee: stored procedure returned invalid ID" });
            }

            _logger.LogInformation("[Employees] CREATE success | EmployeeId={Id} | Name={Name} | OrgId={OrgId}", newId, req.Name, resolvedOrgId);

            // SignalR Notification
            await _hubContext.Clients.Group($"Org_{resolvedOrgId}").SendAsync("EmployeeChanged", new { action = "Create", employeeId = newId, name = req.Name });

            return Ok(new { message = "Employee created successfully", employeeId = newId });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Employees] CREATE failed | Name={Name} | OrgId={OrgId}", req.Name, resolvedOrgId);
            return StatusCode(500, new { message = $"Failed to create employee: {ex.Message}" });
        }
    }

    // PUT /api/employees/{id} — update an employee
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateEmployee(int id, [FromBody] CreateEmployeeRequest req)
    {
        var orgId = GetOrgId();
        var resolvedOrgId = (req.OrganizationId.HasValue && req.OrganizationId > 0)
            ? req.OrganizationId.Value
            : orgId;

        _logger.LogInformation("[Employees] UPDATE | Id={Id} | Name={Name} | TargetOrgId={OrgId} | UserOrgId={UserOrgId}", id, req.Name, resolvedOrgId, orgId);
        
        try
        {
            using var conn = _db.CreateConnection();
            var rowsAffected = await conn.ExecuteAsync("sp_UpdateEmployee", new
            {
                Id                  = id,
                OrganizationId      = resolvedOrgId,
                EmployeeCode        = req.EmployeeCode,
                Salutation          = req.Salutation,
                Name                = req.Name,
                Email               = req.Email,
                Designation         = req.Designation,
                Gender              = req.Gender,
                Mobile              = req.Mobile,
                JoiningDate         = req.JoiningDate,
                DateOfBirth         = req.DateOfBirth,
                ProfilePictureUrl   = req.ProfilePictureUrl,

                // New Fields
                FatherOrSpouse      = req.FatherOrSpouse,
                PresentAddress      = req.PresentAddress,
                PermanentAddress    = req.PermanentAddress,
                EmployeePfNo        = req.EmployeePfNo,
                EmployeeEsicNo      = req.EmployeeEsicNo,
                EmployeeAadharNo    = req.EmployeeAadharNo,
                Days80ServiceCompletionDate = req.Days80ServiceCompletionDate,
                PermanentAppointmentDate    = req.PermanentAppointmentDate,
                PeriodOfSuspension  = req.PeriodOfSuspension,
                SignatureImageUrl   = req.SignatureImageUrl,
                ThumbImpressionImageUrl = req.ThumbImpressionImageUrl,
                DateOfExit          = req.DateOfExit,
                ReasonForExit       = req.ReasonForExit,
                Department          = req.Department,
                DepartmentId        = req.DepartmentId,
                DesignationId       = req.DesignationId,
                Remarks             = req.Remarks,
                CustomFieldsJson    = req.CustomFieldsJson,
                LastUpdatedBy       = GetUserId()
            }, commandType: CommandType.StoredProcedure);

            if (rowsAffected == 0)
            {
                _logger.LogWarning("[Employees] UPDATE failed | No rows affected or permission denied | Id={Id} | OrgId={OrgId}", id, resolvedOrgId);
                return NotFound(new { message = "Employee not found or you don't have permission to edit it in this organization." });
            }

            // SignalR Notification
            await _hubContext.Clients.Group($"Org_{resolvedOrgId}").SendAsync("EmployeeChanged", new { action = "Update", employeeId = id, name = req.Name });

            return Ok(new { message = "Employee updated successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Employees] UPDATE failed | Id={Id}", id);
            return StatusCode(500, "Failed to update employee");
        }
    }

    // POST /api/employees/{id}/photo — upload or replace profile picture
    [HttpPost("{id}/photo")]
    public async Task<IActionResult> UploadPhoto(int id, IFormFile file)
    {
        var userOrgId = GetOrgId();
        _logger.LogInformation("[Employees] Photo upload started | EmployeeId={Id} | UserOrgId={UserOrgId} | FileName={FileName} | FileSize={FileSize}", id, userOrgId, file?.FileName, file?.Length);

        if (file == null || file.Length == 0)
        {
            _logger.LogWarning("[Employees] Photo upload - no file provided | EmployeeId={Id}", id);
            return BadRequest(new { message = "No file provided." });
        }

        // Validate image type
        var allowed = new[] { "image/jpeg", "image/png", "image/webp", "image/gif" };
        if (!allowed.Contains(file.ContentType.ToLower()))
        {
            _logger.LogWarning("[Employees] Photo upload - invalid content type | EmployeeId={Id} | ContentType={ContentType}", id, file.ContentType);
            return BadRequest(new { message = "Only JPEG, PNG, WebP, or GIF images are allowed." });
        }

        // Max 5 MB
        if (file.Length > 5 * 1024 * 1024)
        {
            _logger.LogWarning("[Employees] Photo upload - file too large | EmployeeId={Id} | FileSize={FileSize}", id, file.Length);
            return BadRequest(new { message = "File size must be under 5 MB." });
        }

        try
        {
            using var conn = _db.CreateConnection();

            // Look up the employee to verify it exists and get its org_id
            var employee = await conn.QueryFirstOrDefaultAsync<Employee>(
                "sp_GetEmployeeById",
                new { Id = id },
                commandType: CommandType.StoredProcedure);

            if (employee == null)
            {
                _logger.LogWarning("[Employees] Photo upload - employee not found | EmployeeId={Id}", id);
                return NotFound(new { message = "Employee not found." });
            }
            var employeeOrgId = employee.OrganizationId;

            var ext       = Path.GetExtension(file.FileName).ToLower();
            var fileName  = $"emp-{id}{ext}";
            var folder    = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "employee-photos");
            
            _logger.LogInformation("[Employees] Creating directory | Path={Path}", folder);
            Directory.CreateDirectory(folder);

            // Cleanup existing files for this employee to prevent duplicates with different extensions
            try
            {
                foreach (var existingFile in Directory.GetFiles(folder, $"emp-{id}.*"))
                {
                    System.IO.File.Delete(existingFile);
                    _logger.LogInformation("[Employees] Cleaned up old photo | Path={Path}", existingFile);
                }
            }
            catch (Exception exCleanup)
            {
                _logger.LogWarning(exCleanup, "[Employees] Cleanup of old photo files failed | EmployeeId={Id}", id);
            }
            
            var fullPath  = Path.Combine(folder, fileName);
            _logger.LogInformation("[Employees] Saving file | FullPath={FullPath}", fullPath);

            using (var stream = new FileStream(fullPath, FileMode.Create))
                await file.CopyToAsync(stream);

            _logger.LogInformation("[Employees] File saved successfully | FullPath={FullPath}", fullPath);

            // Verify file exists before updating database
            if (!System.IO.File.Exists(fullPath))
            {
                _logger.LogError("[Employees] File was not saved | FullPath={FullPath}", fullPath);
                return StatusCode(500, new { message = "File was saved but cannot be verified. Please try again." });
            }

            var url = $"/uploads/employee-photos/{fileName}";

            // Update the employee row with the saved image URL
            var rowsAffected = await conn.ExecuteAsync("sp_UpdateEmployeePhoto", new { Id = id, Url = url }, commandType: CommandType.StoredProcedure);

            if (rowsAffected == 0)
            {
                _logger.LogWarning("[Employees] Photo update - database update failed | EmployeeId={Id}", id);
                return StatusCode(500, new { message = "Photo saved but failed to update employee record." });
            }

            _logger.LogInformation("[Employees] Photo uploaded successfully | EmployeeId={Id} | Url={Url} | FileSize={FileSize}", id, url, file.Length);

            // SignalR Notification
            await _hubContext.Clients.Group($"Org_{employeeOrgId}").SendAsync("EmployeeChanged", new { action = "UpdatePhoto", employeeId = id, url });

            return Ok(new { url });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Employees] Photo upload failed | EmployeeId={Id} | UserOrgId={UserOrgId}", id, userOrgId);
            return StatusCode(500, new { message = $"Failed to upload photo: {ex.Message}" });
        }
    }

    // DELETE /api/employees/{id}/photo — remove profile picture
    [HttpDelete("{id}/photo")]
    public async Task<IActionResult> DeletePhoto(int id)
    {
        var userOrgId = GetOrgId();
        _logger.LogInformation("[Employees] Photo delete started | EmployeeId={Id} | UserOrgId={UserOrgId}", id, userOrgId);

        try
        {
            using var conn = _db.CreateConnection();

            // Verify employee exists and get org
            var employee = await conn.QueryFirstOrDefaultAsync<Employee>(
                "sp_GetEmployeeById",
                new { Id = id },
                commandType: CommandType.StoredProcedure);

            if (employee == null) return NotFound(new { message = "Employee not found." });
            var employeeOrgId = employee.OrganizationId;

            // Remove file from disk
            var folder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "employee-photos");
            var pattern = $"emp-{id}.*";
            if (Directory.Exists(folder))
            {
                foreach (var file in Directory.GetFiles(folder, pattern))
                {
                    System.IO.File.Delete(file);
                    _logger.LogInformation("[Employees] Deleted photo file | Path={Path}", file);
                }
            }

            // Update database
            await conn.ExecuteAsync("sp_UpdateEmployeePhoto", new { Id = id, Url = (string?)null }, commandType: CommandType.StoredProcedure);

            // SignalR Notification
            await _hubContext.Clients.Group($"Org_{employeeOrgId}").SendAsync("EmployeeChanged", new { action = "UpdatePhoto", employeeId = id, url = (string?)null });

            return Ok(new { message = "Photo removed successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Employees] Photo delete failed | EmployeeId={Id}", id);
            return StatusCode(500, new { message = $"Failed to remove photo: {ex.Message}" });
        }
    }

    // GET /api/employees/{id}/bank-details
    [HttpGet("{id}/bank-details")]
    public async Task<IActionResult> GetBankDetails(int id)
    {
        try
        {
            using var conn = _db.CreateConnection();
            var details = await conn.QueryFirstOrDefaultAsync<EmployeeAccountDetails>(
                "sp_GetEmployeeAccountDetails",
                // Stored procedure expects @EmployeeId; align parameter name to avoid silent empty results.
                new { EmployeeId = id },
                commandType: CommandType.StoredProcedure);
            _logger.LogInformation("[Employees] GET bank-details returned {@Details} for EmployeeId={Id}", details, id);
            return Ok(details);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Employees] GET bank-details failed | EmployeeId={Id}", id);
            return StatusCode(500, $"Failed to fetch bank details: {ex.Message}");
        }
    }

    // POST /api/employees/{id}/bank-details — create or update bank details
    [HttpPost("{id}/bank-details")]
    public async Task<IActionResult> SaveBankDetails(int id, [FromBody] BankDetailsRequest req)
    {
        var orgId = GetOrgId();
        var userId = GetUserId();
        try
        {
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_UpsertEmployeeAccountDetails", new
            {
                EmployeeId = id,
                OrganizationId = req.OrganizationId ?? orgId,
                AccountNumber = req.AccountNumber,
                AccountHolderName = req.AccountHolderName,
                Branch = req.Branch,
                Ifsc = req.Ifsc,
                CreatedBy = userId,
                LastUpdatedBy = userId
            }, commandType: CommandType.StoredProcedure);

            return Ok(new { message = "Bank details saved successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Employees] POST bank-details failed | EmployeeId={Id}", id);
            return StatusCode(500, $"Failed to save bank details: {ex.Message}");
        }
    }

    // POST /api/employees/{id}/signature — upload signature / thumb impression
    [HttpPost("{id}/signature")]
    public async Task<IActionResult> UploadSignature(int id, IFormFile file)
    {
        if (file == null || file.Length == 0) return BadRequest(new { message = "No file provided." });

        var allowed = new[] { "image/jpeg", "image/png", "image/webp", "image/gif" };
        if (!allowed.Contains(file.ContentType.ToLower()))
            return BadRequest(new { message = "Only JPEG, PNG, WebP, or GIF images are allowed." });

        if (file.Length > 5 * 1024 * 1024)
            return BadRequest(new { message = "File size must be under 5 MB." });

        try
        {
            using var conn = _db.CreateConnection();
            var employee = await conn.QueryFirstOrDefaultAsync<Employee>(
                "sp_GetEmployeeById",
                new { Id = id },
                commandType: CommandType.StoredProcedure);

            if (employee == null) return NotFound(new { message = "Employee not found." });
            var employeeOrgId = employee.OrganizationId;

            var ext = Path.GetExtension(file.FileName).ToLower();
            var fileName = $"sig-{id}{ext}";
            var folder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "employee-signatures");
            Directory.CreateDirectory(folder);

            // Cleanup existing files for this employee
            try
            {
                foreach (var existingFile in Directory.GetFiles(folder, $"sig-{id}.*"))
                {
                    System.IO.File.Delete(existingFile);
                }
            }
            catch (Exception exCleanup)
            {
                _logger.LogWarning(exCleanup, "[Employees] Cleanup of old signature files failed | EmployeeId={Id}", id);
            }

            var fullPath = Path.Combine(folder, fileName);

            using (var stream = new FileStream(fullPath, FileMode.Create))
                await file.CopyToAsync(stream);

            var relUrl = $"/uploads/employee-signatures/{fileName}";
            await conn.ExecuteAsync("sp_UpdateEmployeeSignature", new { Id = id, Url = relUrl }, commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{employeeOrgId}").SendAsync("EmployeeChanged",
                new { action = "UpdateSignature", employeeId = id, url = relUrl });

            return Ok(new { message = "Signature uploaded.", url = relUrl });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Employees] Signature upload failed | EmployeeId={Id}", id);
            return StatusCode(500, $"Failed to upload signature: {ex.Message}");
        }
    }

    // DELETE /api/employees/{id}/signature
    [HttpDelete("{id}/signature")]
    public async Task<IActionResult> DeleteSignature(int id)
    {
        try
        {
            using var conn = _db.CreateConnection();
            var employee = await conn.QueryFirstOrDefaultAsync<Employee>(
                "sp_GetEmployeeById",
                new { Id = id },
                commandType: CommandType.StoredProcedure);
            if (employee == null) return NotFound(new { message = "Employee not found." });
            int employeeOrgId = employee.OrganizationId;

            var folder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "employee-signatures");
            var pattern = $"sig-{id}.*";
            if (Directory.Exists(folder))
            {
                foreach (var f in Directory.GetFiles(folder, pattern))
                    System.IO.File.Delete(f);
            }

            await conn.ExecuteAsync("sp_UpdateEmployeeSignature", new { Id = id, Url = (string?)null }, commandType: CommandType.StoredProcedure);
            await _hubContext.Clients.Group($"Org_{employeeOrgId}").SendAsync("EmployeeChanged",
                new { action = "UpdateSignature", employeeId = id, url = (string?)null });

            return Ok(new { message = "Signature removed." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Employees] Signature delete failed | EmployeeId={Id}", id);
            return StatusCode(500, $"Failed to remove signature: {ex.Message}");
        }
    }

    // DELETE /api/employees/{id}
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteEmployee(int id)
    {
        var userOrgId = GetOrgId();
        _logger.LogInformation("[Employees] DELETE | Id={Id} | UserOrgId={UserOrgId}", id, userOrgId);
        try
        {
            using var conn = _db.CreateConnection();

            // Look up the employee first to verify it exists
            var employee = await conn.QueryFirstOrDefaultAsync<Employee>(
                "sp_GetEmployeeById",
                new { Id = id },
                commandType: CommandType.StoredProcedure);

            if (employee == null)
            {
                _logger.LogWarning("[Employees] DELETE - employee not found | Id={Id}", id);
                return NotFound(new { message = "Employee not found." });
            }

            // Optional: Verify the employee belongs to the user's organization
            // For now, allowing any authenticated user to delete any employee
            // Uncomment below for stricter access control:
            // if (employee.OrganizationId != userOrgId)
            // {
            //     _logger.LogWarning("[Employees] DELETE - employee not in user's org | Id={Id} | EmployeeOrgId={OrgId} | UserOrgId={UserOrgId}", id, employee.OrganizationId, userOrgId);
            //     return Forbid();
            // }

            var rows = await conn.ExecuteAsync(
                "sp_DeleteEmployee",
                new { Id = id, OrganizationId = employee.OrganizationId },
                commandType: CommandType.StoredProcedure);

            if (rows == 0)
            {
                _logger.LogWarning("[Employees] DELETE - sp failed | Id={Id} | OrgId={OrgId}", id, employee.OrganizationId);
                return StatusCode(500, new { message = "Failed to delete employee. Please try again." });
            }

            // Also remove profile picture and signature files if they exist
        try
        {
            // Delete photo
            var photoFolder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "employee-photos");
            if (Directory.Exists(photoFolder))
            {
                foreach (var file in Directory.GetFiles(photoFolder, $"emp-{id}.*"))
                {
                    System.IO.File.Delete(file);
                    _logger.LogInformation("[Employees] Deleted photo file | Path={Path}", file);
                }
            }

            // Delete signature
            var sigFolder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "employee-signatures");
            if (Directory.Exists(sigFolder))
            {
                foreach (var file in Directory.GetFiles(sigFolder, $"sig-{id}.*"))
                {
                    System.IO.File.Delete(file);
                    _logger.LogInformation("[Employees] Deleted signature file | Path={Path}", file);
                }
            }
        }
        catch (Exception exFile)
        {
            _logger.LogWarning(exFile, "[Employees] Failed to delete media files for EmployeeId={Id}", id);
        }

        _logger.LogInformation("[Employees] DELETE success | Id={Id} | OrgId={OrgId}", id, employee.OrganizationId);

        // SignalR Notification
        await _hubContext.Clients.Group($"Org_{employee.OrganizationId}").SendAsync("EmployeeChanged", new { action = "Delete", employeeId = id });

        return Ok(new { message = "Employee deleted successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Employees] DELETE failed | Id={Id} | UserOrgId={UserOrgId}", id, userOrgId);
            return StatusCode(500, new { message = $"Error deleting employee: {ex.Message}" });
        }
    }

    [HttpGet("export-excel")]
    public async Task<IActionResult> ExportExcel([FromQuery] int organizationId, [FromQuery] string? employeeIds)
    {
        try
        {
            using var conn = _db.CreateConnection();
            var ids = !string.IsNullOrEmpty(employeeIds) ? employeeIds.Split(',').Select(int.Parse).ToList() : null;
            
            var sql = @"
                SELECT e.*, b.id as BankSplitId, b.* 
                FROM employees e 
                LEFT JOIN employee_account_details b ON e.id = b.employee_id 
                WHERE e.organization_id = @OrgId";

            var employees = (await conn.QueryAsync<Employee, EmployeeAccountDetails, Employee>(
                sql,
                (e, b) => { e.BankDetails = b; return e; },
                new { OrgId = organizationId },
                splitOn: "BankSplitId"
            )).ToList();

            if (ids != null && ids.Any()) employees = employees.Where(e => ids.Contains(e.Id)).ToList();

            var org = await conn.QueryFirstOrDefaultAsync<Organization>("SELECT * FROM organizations WHERE id = @Id", new { Id = organizationId });
            var fields = (await conn.QueryAsync<OrganizationFieldAccess, EmployeeDataField, OrganizationFieldAccess>(
                "SELECT ofa.*, f.* FROM emp_data_use_fields ofa JOIN employee_data_fields f ON ofa.field_id = f.id WHERE ofa.organization_id = @OrgId",
                (ofa, f) => { ofa.FieldMetadata = f; return ofa; },
                new { OrgId = organizationId }
            )).ToList();

            var excelData = _exportService.GenerateEmployeesExcel(employees, fields, org?.Name ?? "Organization");
            return File(excelData, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", $"Employees_{DateTime.Now:yyyyMMdd}.xlsx");
        }
        catch (Exception ex) { _logger.LogError(ex, "Excel export failed"); return StatusCode(500, new { message = ex.Message }); }
    }

    [HttpGet("export-pdf")]
    public async Task<IActionResult> ExportPdf([FromQuery] int organizationId, [FromQuery] string? employeeIds, [FromQuery] string? form)
    {
        try
        {
            using var conn = _db.CreateConnection();
            var ids = !string.IsNullOrEmpty(employeeIds) ? employeeIds.Split(',').Select(int.Parse).ToList() : null;

            var sql = @"
                SELECT e.*, b.id as BankSplitId, b.* 
                FROM employees e 
                LEFT JOIN employee_account_details b ON e.id = b.employee_id 
                WHERE e.organization_id = @OrgId";

            var employees = (await conn.QueryAsync<Employee, EmployeeAccountDetails, Employee>(
                sql,
                (e, b) => { e.BankDetails = b; return e; },
                new { OrgId = organizationId },
                splitOn: "BankSplitId"
            )).ToList();

            if (ids != null && ids.Any()) employees = employees.Where(e => ids.Contains(e.Id)).ToList();

            var org = await conn.QueryFirstOrDefaultAsync<Organization>("SELECT * FROM organizations WHERE id = @Id", new { Id = organizationId });
            if (org == null) return NotFound(new { message = "Organization not found" });

            var fields = (await conn.QueryAsync<OrganizationFieldAccess, EmployeeDataField, OrganizationFieldAccess>(
                "SELECT ofa.*, f.* FROM emp_data_use_fields ofa JOIN employee_data_fields f ON ofa.field_id = f.id WHERE ofa.organization_id = @OrgId",
                (ofa, f) => { ofa.FieldMetadata = f; return ofa; },
                new { OrgId = organizationId }
            )).ToList();

            var pdfData = _exportService.GenerateEmployeesPdf(employees, org, fields, form);
            return File(pdfData, "application/pdf", $"Employees_{DateTime.Now:yyyyMMdd}.pdf");
        }
        catch (Exception ex) { _logger.LogError(ex, "PDF export failed"); return StatusCode(500, new { message = ex.Message }); }
    }
}
