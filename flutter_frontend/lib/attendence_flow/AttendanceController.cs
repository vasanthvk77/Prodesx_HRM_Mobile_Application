using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Dapper;
using System.Data;
using System.Linq;
using System.Collections.Generic;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Configuration;
using System.Text;
using System.Security.Claims;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using backend.Models;
using backend.Data;
using backend.Hubs;

namespace backend.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class AttendanceController : BaseController<AttendanceController>
{
    private readonly DataBaseConnection _dataBaseConnection;
    private readonly IHubContext<EmployeesHub> _hubContext;
    private readonly IConfiguration _config;
    private readonly backend.Services.ExportService _exportService;

    public AttendanceController(DataBaseConnection dataBaseConnection, IHubContext<EmployeesHub> hubContext, ILogger<AttendanceController> logger, IConfiguration config, backend.Services.ExportService exportService)
        : base(logger)
    {
        _dataBaseConnection = dataBaseConnection;
        _hubContext = hubContext;
        _config = config;
        _exportService = exportService;
    }

    [HttpGet("export-register")]
    public async Task<IActionResult> ExportAttendanceRegister([FromQuery] int month, [FromQuery] int year, [FromQuery] string? department, [FromQuery] string? designation, [FromQuery] string? search, [FromQuery] string type = "excel")
    {
        var orgId = CurrentOrgId;
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            
            // 1. Fetch Organization Info (use SP same as rest of codebase for correct column mapping)
            var org = await conn.QueryFirstOrDefaultAsync<Organization>(
                "sp_GetOrganizationById",
                new { Id = orgId },
                commandType: CommandType.StoredProcedure
            );
            if (org == null) return NotFound("Organization not found");

            // 2. Fetch Employees (Apply filters if present)
            var empSql = new StringBuilder("SELECT * FROM employees WHERE organization_id = @OrgId AND status = 'Active'");
            
            if (!string.IsNullOrEmpty(department)) empSql.Append(" AND department = @DeptName");
            if (!string.IsNullOrEmpty(designation)) empSql.Append(" AND designation = @DesigName");
            
            if (!string.IsNullOrEmpty(search)) {
                empSql.Append(" AND (name LIKE @Search OR employee_code LIKE @Search)");
            }

            var employees = (await conn.QueryAsync<Employee>(empSql.ToString(), new { 
                OrgId = orgId, 
                DeptName = department, 
                DesigName = designation,
                Search = $"%{search}%"
            })).ToList();

            // 3. Fetch Monthly Attendance for the register (Same logic as sp_GetStaffAttendance)
            var attendanceSql = @"
                SELECT 
                    sa.EmployeeId,
                    am.Date,
                    ltf.ShortName AS FN,
                    lts.ShortName AS AN
                FROM StaffAttendance sa
                JOIN AttendanceMaster am ON sa.AttendanceSettingId = am.AttendanceSettingId
                LEFT JOIN LeaveType ltf ON sa.FH = ltf.LeaveTypeId
                LEFT JOIN LeaveType lts ON sa.SH = lts.LeaveTypeId
                WHERE am.OrganizationId = @OrgId 
                  AND MONTH(am.Date) = @Month 
                  AND YEAR(am.Date) = @Year";

            var attendance = (await conn.QueryAsync<EmpAttendanceRecord>(attendanceSql, new { OrgId = orgId, Month = month, Year = year })).ToList();

            // 4. Generate Data based on type
            byte[] fileData;
            string contentType;
            string fileName;

            if (type.ToLower() == "pdf")
            {
                fileData = _exportService.GenerateAttendanceRegisterPdf(employees, attendance, org, month, year);
                contentType = "application/pdf";
                fileName = $"Attendance_Register_{new DateTime(year, month, 1):MMM_yyyy}.pdf";
            }
            else
            {
                fileData = _exportService.GenerateAttendanceRegisterExcel(employees, attendance, org, month, year);
                contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
                fileName = $"Attendance_Register_{new DateTime(year, month, 1):MMM_yyyy}.xlsx";
            }

            return File(fileData, contentType, fileName);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Export attendance register failed");
            return StatusCode(500, new { message = "Export failed", details = ex.Message });
        }
    }



    // Note: Leave types management (Fetch/Settings/Toggle) has been moved to LeaveTypeController.cs


    // Note: The UI grid uses AttendanceMasterController, which calls sp_GetStaffAttendance.
    // The following methods are and remained strictly as legacy placeholders or for specific auxiliary needs.

    [HttpPost]
    public async Task<IActionResult> UpsertAttendance([FromBody] DailyAttendance attendance)
    {
        var resolvedOrgId = CurrentOrgId;
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            var parameters = new
            {
                EmployeeId = attendance.EmployeeId,
                OrganizationId = resolvedOrgId,
                Date = attendance.Date,
                attendance.PunchIn,
                attendance.PunchOut,
                attendance.CalculatedStatus,
                attendance.IsProcessed
            };

            await conn.ExecuteAsync(
                "sp_UpsertDailyAttendance",
                parameters,
                commandType: CommandType.StoredProcedure
            );

            // SignalR Notification
            await _hubContext.Clients.Group($"Org_{resolvedOrgId}").SendAsync("AttendanceChanged", new { 
                action = "Update", 
                employeeId = attendance.EmployeeId, 
                date = attendance.Date 
            });

            return Ok(new { Message = "Attendance record saved" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving attendance");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpPost("bulk")]
    public async Task<IActionResult> BulkUpsertAttendance([FromBody] List<DailyAttendance> records)
    {
        var resolvedOrgId = CurrentOrgId;
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            foreach (var record in records)
            {
                var parameters = new
                {
                    EmployeeId = record.EmployeeId,
                    OrganizationId = resolvedOrgId,
                    Date = record.Date,
                    record.PunchIn,
                    record.PunchOut,
                    record.CalculatedStatus,
                    record.IsProcessed
                };
                await conn.ExecuteAsync("sp_UpsertDailyAttendance", parameters, commandType: CommandType.StoredProcedure);
            }
            // SignalR Notification for bulk
            await _hubContext.Clients.Group($"Org_{resolvedOrgId}").SendAsync("AttendanceChanged", new { 
                action = "BulkUpdate"
            });

            return Ok(new { Message = "Bulk attendance updated" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in bulk attendance update");
            return StatusCode(500, ex.Message);
        }
    }

    [Authorize(Roles = "Admin,SuperAdmin")]
    [HttpGet("generate-qr-token")]
    public IActionResult GenerateQRToken([FromQuery] int? orgId)
    {
        // Enforce access control: Admin can only generate for their own org; SuperAdmin can override.
        var targetOrgId = (IsSuperAdmin && orgId.HasValue && orgId.Value > 0) ? orgId.Value : CurrentOrgId;
        
        _logger.LogInformation("[Attendance] Generating QR Token for TargetOrgId={OrgId} (Requested={ReqOrgId}, IsSuperAdmin={IsSA})", targetOrgId, orgId, IsSuperAdmin);
        
        try
        {
            var jwtSettings = _config.GetSection("Jwt");
            var jwtKey = jwtSettings["Key"] ?? throw new InvalidOperationException("'Jwt:Key' is missing in configuration.");
            var jwtIssuer = jwtSettings["Issuer"] ?? "ProDesX-Backend";
            var jwtAudience = jwtSettings["Audience"] ?? "ProDesX-Frontend";
            
            var key = Encoding.ASCII.GetBytes(jwtKey);
            var tokenHandler = new JwtSecurityTokenHandler();
            var expiryTime = DateTime.UtcNow.AddSeconds(30);
            
            var tokenDescriptor = new SecurityTokenDescriptor
            {
                Subject = new ClaimsIdentity(new[]
                {
                    new Claim("OrganizationId", targetOrgId.ToString()),
                    new Claim("Type", "QRAttendance"),
                    new Claim("GeneratedAt", DateTime.UtcNow.ToString("O"))
                }),
                Expires = expiryTime,
                Issuer = jwtIssuer,
                Audience = jwtAudience,
                SigningCredentials = new SigningCredentials(new SymmetricSecurityKey(key), SecurityAlgorithms.HmacSha256Signature)
            };

            var token = tokenHandler.CreateToken(tokenDescriptor);
            var qrToken = tokenHandler.WriteToken(token);
            
            return Ok(new { qrToken, expiryTime });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error generating QR token");
            return StatusCode(500, "Failed to generate QR token");
        }
    }

    [Authorize]
    [HttpPost("punch-qr")]
    public async Task<IActionResult> PunchViaQR([FromBody] QRPunchRequest request)
    {
        var userId = CurrentUserId;
        var userOrgId = CurrentOrgId;
        _logger.LogInformation("[Attendance] QR Punch attempt | UserId={UserId} | OrgId={OrgId}", userId, userOrgId);

        if (string.IsNullOrEmpty(request.QRToken))
            return BadRequest(new { message = "QR Token is required." });

        // 1. Validate QR Token
        var tokenHandler = new JwtSecurityTokenHandler();
        var jwtSettings = _config.GetSection("Jwt");
        var jwtKey = jwtSettings["Key"] ?? "";
        var key = Encoding.ASCII.GetBytes(jwtKey);

        try
        {
            var principal = tokenHandler.ValidateToken(request.QRToken, new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = new SymmetricSecurityKey(key),
                ValidateIssuer = false,
                ValidateAudience = false,
                ClockSkew = TimeSpan.Zero
            }, out SecurityToken validatedToken);

            var qrOrgIdClaimValue = principal.FindFirst("OrganizationId")?.Value;
            var qrTypeClaim = principal.FindFirst("Type")?.Value;

            if (qrTypeClaim != "QRAttendance" || string.IsNullOrEmpty(qrOrgIdClaimValue))
            {
                _logger.LogWarning("[Attendance] QR Data mismatch | Claims: Type={Type}, OrgId={OrgId}", qrTypeClaim, qrOrgIdClaimValue);
                return BadRequest(new { message = "Malformed or incompatible QR code." });
            }

            if (!int.TryParse(qrOrgIdClaimValue, out var qrOrgId) || qrOrgId <= 0)
            {
                _logger.LogWarning("[Attendance] QR Data mismatch | Claims: Type={Type}, OrgId={OrgId}", qrTypeClaim, qrOrgIdClaimValue);
                return BadRequest(new { message = "Malformed or incompatible QR code." });
            }

            using var conn = _dataBaseConnection.CreateConnection();

            // 2. Validate Access to THE ORGANIZATION SPECIFIED BY THE QR CODE
            // SuperAdmins have global access; everyone else must have an active entry in UserOrganizationAccess
            var userRole = UserRole;
            bool hasAccess = userRole == "SuperAdmin";
            
            if (!hasAccess)
            {
                var accessCount = await conn.ExecuteScalarAsync<int>(
                    "SELECT COUNT(1) FROM UserOrganizationAccess WHERE UserID = @UserId AND OrganizationID = @OrgId AND IsActive = 1",
                    new { UserId = userId, OrgId = qrOrgId }
                );
                hasAccess = accessCount > 0;
            }

            if (!hasAccess)
            {
                _logger.LogWarning("[Attendance] QR Punch denied — user {UserId} has no access to org {OrgId}", userId, qrOrgId);
                return BadRequest(new { message = "You are not registered with this organization." });
            }

            // 3. Find Employee ID for recording (must still be an employee of THAT org)
            // FEATURE: Auto-healing link — if we can't find by user_id, we check by Email to 'repair' a dangling employee record (e.g. from a previous deletion)
            var userEmail = UserEmail;
            var employeeId = await conn.ExecuteScalarAsync<int>(
                "SELECT id FROM employees WHERE user_id = @UserId AND organization_id = @OrgId",
                new { UserId = userId, OrgId = qrOrgId }
            );

            if (employeeId == 0)
            {
                _logger.LogInformation("[Attendance] No direct user_id link for user {UserId} in org {OrgId}. Searching by Email: {Email}", userId, qrOrgId, userEmail);
                employeeId = await conn.ExecuteScalarAsync<int>(
                    "SELECT id FROM employees WHERE email = @Email AND organization_id = @OrgId AND (user_id IS NULL OR user_id = @UserId)",
                    new { Email = userEmail, OrgId = qrOrgId, UserId = userId }
                );

                if (employeeId > 0)
                {
                    _logger.LogInformation("[Attendance] Auto-Healing Link: Linking User {UserId} to Employee {EmpId} for Org {OrgId} via Email match", userId, employeeId, qrOrgId);
                    await conn.ExecuteAsync("UPDATE employees SET user_id = @UserId WHERE id = @EmpId", new { UserId = userId, EmpId = employeeId });
                }
            }

            if (employeeId == 0)
            {
                _logger.LogWarning("[Attendance] QR Punch failed — user {UserId} has access but no employee record for org {OrgId}", userId, qrOrgId);
                return BadRequest(new { message = "You are not registered as an employee in this organization." });
            }

            // If the user's current session doesn't match the scanned QR, we still allow the punch 
            // but we use the QR's organization ID for recording to ensure data integrity.
            if (qrOrgId != userOrgId)
            {
                _logger.LogInformation("[Attendance] QR Org Session Mismatch | User Session={UserOrg} | QR Org={QROrg} | Proceeding with QR Org", userOrgId, qrOrgId);
            }

            var org = await conn.QueryFirstOrDefaultAsync<Organization>(
                "sp_GetOrganizationById",
                new { Id = qrOrgId },
                commandType: CommandType.StoredProcedure
            );

            // 3. Validate Geofencing (If configured)
            // 3. Validate Geofencing
            // We load geofencing settings for the ORGANIZATION SPECIFIED IN THE QR CODE (must match userOrgId per above check)
            if (org != null && org.Latitude.HasValue && org.Longitude.HasValue && (org.Latitude.Value != 0 || org.Longitude.Value != 0))
            {
                if (request.Latitude == null || request.Longitude == null)
                    return BadRequest(new { message = "Location access (GPS) is required to scan this office's QR code." });

                double distance = GetDistance(
                    (double)request.Latitude.Value, (double)request.Longitude.Value,
                    (double)org.Latitude.Value, (double)org.Longitude.Value
                );

                int allowedRadius = (int)(org.AllowedRadius ?? 0);

                _logger.LogInformation("[Attendance] Geofencing Check | User:({ULat},{ULon}) | Office:({OLat},{OLon}) | Distance={Distance}m | Allowed={Radius}m", 
                    request.Latitude, request.Longitude, org.Latitude, org.Longitude, Math.Round(distance), allowedRadius);

                if (distance > allowedRadius)
                {
                    _logger.LogWarning("[Attendance] Geofencing check failed | Distance={Distance}m | Allowed={Radius}m", Math.Round(distance), allowedRadius);
                    return BadRequest(new { message = $"Out of bounds! You are {Math.Round(distance)}m away from the office location. Please ensure you are standing within {allowedRadius}m of the office center." });
                }
            }
            else
            {
                _logger.LogInformation("[Attendance] Geofencing skipped: Organization {OrgId} does not have coordinates configured (Lat/Long are Null or 0).", userOrgId);
            }


            // 4. Get current attendance status for today
            var status = await conn.QueryFirstOrDefaultAsync<AttendanceStatusResponse>(
                "sp_GetEmployeeAttendanceStatus",
                new { EmployeeId = employeeId, OrganizationId = qrOrgId, Date = DateTime.Today },
                commandType: CommandType.StoredProcedure
            );

            // 5. Determine Punch Type (In or Out)
            DateTime? punchIn = null;
            DateTime? punchOut = null;
            string action = "";

            if (status == null || status.PunchInTime == null)
            {
                punchIn = DateTime.Now;
                action = "Punch In";
            }
            else if (status.PunchOutTime == null)
            {
                punchOut = DateTime.Now;
                action = "Punch Out";
            }
            else
            {
                return BadRequest(new { message = "You have already completed punch in and punch out for today." });
            }

            // 6. Save Attendance
            await conn.ExecuteAsync(
                "sp_UpsertDailyAttendance",
                new
                {
                    EmployeeId = employeeId,
                    OrganizationId = qrOrgId,
                    Date = DateTime.Today.Date,
                    PunchIn = punchIn,
                    PunchOut = punchOut,
                    CalculatedStatus = (string?)null,
                    IsProcessed = false
                },
                commandType: CommandType.StoredProcedure
            );

            _logger.LogInformation("[Attendance] QR Punch SUCCESS | UserId={UserId} | EmployeeId={Id} | Action={Action}", userId, employeeId, action);

            // 7. Notify via SignalR
            await _hubContext.Clients.Group($"Org_{qrOrgId}").SendAsync("AttendanceChanged", new { 
                action = "Update", 
                employeeId = employeeId, 
                date = DateTime.Today 
            });

            return Ok(new { message = $"Successfully Recorded {action}", action, punchTime = DateTime.Now });
        }
        catch (SecurityTokenExpiredException)
        {
            return BadRequest(new { message = "QR code has expired. Please refresh the QR code on the admin screen." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Attendance] QR Punch failed");
            return StatusCode(500, new { message = "An error occurred during QR punch." });
        }
    }

    private double GetDistance(double lat1, double lon1, double lat2, double lon2)
    {
        double R = 6371e3; // Earth radius in meters
        double phi1 = lat1 * Math.PI / 180;
        double phi2 = lat2 * Math.PI / 180;
        double deltaPhi = (lat2 - lat1) * Math.PI / 180;
        double deltaLambda = (lon2 - lon1) * Math.PI / 180;

        double a = Math.Sin(deltaPhi / 2) * Math.Sin(deltaPhi / 2) +
                   Math.Cos(phi1) * Math.Cos(phi2) *
                   Math.Sin(deltaLambda / 2) * Math.Sin(deltaLambda / 2);
        double c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));

        return R * c;
    }
}
