using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Dapper;
using System.Data;
using System.Linq;
using System.Collections.Generic;
using Microsoft.AspNetCore.SignalR;
using backend.Models;
using backend.Data;
using backend.Hubs;
using System.Text;

namespace backend.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class AttendanceMasterController : BaseController<AttendanceMasterController>
{
    private readonly DataBaseConnection _db;
    private readonly IHubContext<AttendanceHub> _hubContext;
    private readonly backend.Services.IHashIdService _hashId;

    public AttendanceMasterController(DataBaseConnection db, IHubContext<AttendanceHub> hubContext, ILogger<AttendanceMasterController> logger, backend.Services.IHashIdService hashId)
        : base(logger)
    {
        _db = db;
        _hubContext = hubContext;
        _hashId = hashId;
    }

    [HttpGet]
    public async Task<IActionResult> GetAttendance([FromQuery] string date, [FromQuery] int? orgId)
    {
        var finalOrgId = orgId ?? CurrentOrgId;
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
            _logger.LogError(ex, "Error fetching attendance");
            return StatusCode(500, new { message = "Failed to fetch attendance.", details = ex.Message });
        }
    }

    [HttpPost]
    public async Task<IActionResult> SaveAttendanceRecord([FromQuery] int? orgId, [FromBody] UpsertEmpAttendanceRequest request)
    {
        var finalOrgId = orgId ?? CurrentOrgId;
        var userId = CurrentUserId;
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
            return Ok(new { message = "Attendance record updated." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving attendance record");
            return StatusCode(500, new { message = "Failed to save attendance.", details = ex.Message });
        }
    }

    [HttpPost("bulk")]
    public async Task<IActionResult> BulkSaveAttendance([FromQuery] int? orgId, [FromBody] BulkUpsertEmpAttendanceRequest request)
    {
        var finalOrgId = orgId ?? CurrentOrgId;
        var userId = CurrentUserId;
        
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
            
            // Broadcast real-time update (group name uses hash string to match frontend)
            var orgHashId = _hashId.Encode(finalOrgId);
            await _hubContext.Clients.Group($"Org_{orgHashId}").SendAsync("AttendanceChanged", new { 
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

    [HttpGet("status")]
    public async Task<IActionResult> GetAttendanceStatus([FromQuery] int employeeId)
    {
        var orgId = CurrentOrgId;
        try
        {
            using var conn = _db.CreateConnection();
            var status = await conn.QueryFirstOrDefaultAsync<dynamic>(
                @"SELECT sa.* FROM StaffAttendance sa 
                  JOIN AttendanceMaster am ON sa.AttendanceSettingId = am.AttendanceSettingId
                  WHERE sa.EmployeeId = @EmployeeId AND am.Date = @Today AND am.OrganizationId = @OrgId",
                new { EmployeeId = employeeId, Today = DateTime.Today, OrgId = orgId }
            );

            if (status == null)
                return Ok(new { isScheduled = true, status = "ReadyToPunchIn" });
            
            if (status.FH > 0 && status.SH > 0)
                return Ok(new { isScheduled = true, status = "ShiftCompleted" });
            
            if (status.FH > 0)
                return Ok(new { isScheduled = true, status = "ReadyToPunchOut" });

            return Ok(new { isScheduled = true, status = "ReadyToPunchIn" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching attendance status");
            return StatusCode(500, new { message = "Failed to fetch status." });
        }
    }

    // Leave Types removed from this controller as per cleaning request
}
