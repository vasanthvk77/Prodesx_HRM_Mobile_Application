using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Dapper;
using System.Data;
using backend.Models;
using backend.Data;
using backend.Hubs;
using Microsoft.AspNetCore.SignalR;

namespace backend.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class AttendanceMasterController : ControllerBase
{
    private readonly DataBaseConnection _db;
    private readonly IHubContext<AttendanceHub> _hubContext;
    private readonly ILogger<AttendanceMasterController> _logger;

    public AttendanceMasterController(DataBaseConnection db, IHubContext<AttendanceHub> hubContext, ILogger<AttendanceMasterController> logger)
    {
        _db = db;
        _hubContext = hubContext;
        _logger = logger;
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

    [HttpGet]
    public async Task<IActionResult> GetAttendance([FromQuery] string date, [FromQuery] int? orgId)
    {
        var finalOrgId = orgId ?? GetOrgId();
        if (!DateTime.TryParse(date, out var parsedDate))
            return BadRequest(new { message = "Invalid date format. Use YYYY-MM-DD." });

        try
        {
            using var conn = _db.CreateConnection();
            var attendanceList = await conn.QueryAsync<EmpAttendanceRecord>(
                "sp_GetStaffAttendance", 
                new { OrganizationId = finalOrgId, Date = parsedDate.Date },
                commandType: CommandType.StoredProcedure
            );
            return Ok(attendanceList);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching staff attendance");
            return StatusCode(500, new { message = "Failed to fetch attendance.", details = ex.Message });
        }
    }

    [HttpPost]
    public async Task<IActionResult> SaveAttendanceRecord([FromBody] UpsertEmpAttendanceRequest request, [FromQuery] int? orgId)
    {
        var finalOrgId = orgId ?? GetOrgId();
        var userId = GetUserId();
        try
        {
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync(
                "sp_UpsertStaffAttendance",
                new
                {
                    OrganizationId = finalOrgId,
                    Date = request.AttendanceDate.Date,
                    EmployeeId = request.EmployeeId,
                    FH = request.FN ?? "A",
                    SH = request.AN ?? "A",
                    UserId = userId
                },
                commandType: CommandType.StoredProcedure
            );

            // SignalR Notification
            await _hubContext.Clients.Group($"Org_{finalOrgId}").SendAsync("AttendanceChanged", new { 
                action = "Update", 
                employeeId = request.EmployeeId, 
                date = request.AttendanceDate.Date 
            });

            return Ok(new { message = "Attendance record updated." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving attendance record");
            return StatusCode(500, new { message = "Failed to save attendance.", details = ex.Message });
        }
    }

    [HttpPost("bulk")]
    public async Task<IActionResult> BulkSaveAttendance([FromBody] BulkUpsertEmpAttendanceRequest request, [FromQuery] int? orgId)
    {
        var finalOrgId = orgId ?? GetOrgId();
        var userId = GetUserId();
        
        if (request.Records == null || !request.Records.Any())
            return BadRequest(new { message = "No records to save." });

        try
        {
            using var conn = _db.CreateConnection();
            foreach (var record in request.Records)
            {
                await conn.ExecuteAsync(
                    "sp_UpsertStaffAttendance",
                    new
                    {
                        OrganizationId = finalOrgId,
                        Date = request.AttendanceDate.Date,
                        EmployeeId = record.EmployeeId,
                        FH = record.FN ?? "A",
                        SH = record.AN ?? "A",
                        UserId = userId
                    },
                    commandType: CommandType.StoredProcedure
                );
            }
            
            // Broadcast real-time update
            await _hubContext.Clients.Group($"Org_{finalOrgId}").SendAsync("AttendanceChanged", new { 
                action = "BulkUpdate",
                date = request.AttendanceDate.Date
            });

            return Ok(new { message = $"Bulk attendance saved successfully for {request.Records.Count} employees." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving bulk attendance");
            return StatusCode(500, new { message = "Failed to save bulk attendance.", details = ex.Message });
        }
    }
}
