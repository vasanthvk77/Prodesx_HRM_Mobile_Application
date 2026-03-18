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

namespace backend.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class AttendanceController : ControllerBase
{
    private readonly DataBaseConnection _dataBaseConnection;
    private readonly IHubContext<EmployeesHub> _hubContext;
    private readonly ILogger<AttendanceController> _logger;

    public AttendanceController(DataBaseConnection dataBaseConnection, IHubContext<EmployeesHub> hubContext, ILogger<AttendanceController> logger)
    {
        _dataBaseConnection = dataBaseConnection;
        _hubContext = hubContext;
        _logger = logger;
    }

    private int GetOrgId()
    {
        var orgClaim = User.FindFirst("OrganizationId")?.Value;
        return int.TryParse(orgClaim, out var id) ? id : 0;
    }

    private int ResolveOrgId(int? orgId) => (orgId.HasValue && orgId.Value > 0) ? orgId.Value : GetOrgId();

    [HttpGet("leavetypes")]
    public async Task<IActionResult> GetLeaveTypes([FromQuery] int? orgId)
    {
        var resolvedOrgId = ResolveOrgId(orgId);
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            var leaveTypes = await conn.QueryAsync<LeaveType>(
                "sp_GetLeaveTypes",
                new { OrganizationId = resolvedOrgId },
                commandType: CommandType.StoredProcedure
            );
            return Ok(leaveTypes);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching leave types");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpPost("leavetypes")]
    public async Task<IActionResult> UpsertLeaveType([FromBody] LeaveType leaveType, [FromQuery] int? orgId)
    {
        var resolvedOrgId = ResolveOrgId(orgId);
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            var parameters = new
            {
                Id = leaveType.Id > 0 ? (int?)leaveType.Id : null,
                OrganizationId = resolvedOrgId,
                leaveType.TypeName,
                leaveType.Category,
                leaveType.ShortName,
                leaveType.IsPaid,
                leaveType.ColorCode,
                leaveType.IsVisible,
                leaveType.IsMobileView
            };

            var id = await conn.ExecuteScalarAsync<int>(
                "sp_UpsertLeaveType",
                parameters,
                commandType: CommandType.StoredProcedure
            );
            leaveType.Id = id;
            leaveType.OrganizationId = resolvedOrgId;
            return Ok(leaveType);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving leave type");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpDelete("leavetypes/{id}")]
    public async Task<IActionResult> DeleteLeaveType(int id, [FromQuery] int? orgId)
    {
        var resolvedOrgId = ResolveOrgId(orgId);
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            await conn.ExecuteAsync(
                "sp_DeleteLeaveType",
                new { Id = id, OrganizationId = resolvedOrgId },
                commandType: CommandType.StoredProcedure
            );
            return Ok(new { Message = "Leave type deleted" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting leave type");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpGet]
    public async Task<IActionResult> GetAttendance([FromQuery] string start, [FromQuery] string end, [FromQuery] int? orgId)
    {
        var resolvedOrgId = ResolveOrgId(orgId);
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            var attendance = await conn.QueryAsync<DailyAttendance>(
                "sp_GetAttendanceByRange",
                new { OrganizationId = resolvedOrgId, StartDate = start, EndDate = end },
                commandType: CommandType.StoredProcedure
            );
            return Ok(attendance);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching attendance");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpGet("status")]
    public async Task<IActionResult> GetTodayStatus([FromQuery] int employeeId, [FromQuery] int? orgId)
    {
        var resolvedOrgId = ResolveOrgId(orgId);
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            var status = await conn.QueryFirstOrDefaultAsync<AttendanceStatusResponse>(
                "sp_GetEmployeeAttendanceStatus",
                new { EmployeeId = employeeId, OrganizationId = resolvedOrgId, Date = DateTime.Today },
                commandType: CommandType.StoredProcedure
            );
            return Ok(status ?? new AttendanceStatusResponse());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching attendance status");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpPost]
    public async Task<IActionResult> UpsertAttendance([FromBody] DailyAttendance attendance, [FromQuery] int? orgId)
    {
        var resolvedOrgId = ResolveOrgId(orgId);
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
                AttendanceTypeId = (attendance.AttendanceTypeId > 0) ? attendance.AttendanceTypeId : null,
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
    public async Task<IActionResult> BulkUpsertAttendance([FromBody] List<DailyAttendance> records, [FromQuery] int? orgId)
    {
        var resolvedOrgId = ResolveOrgId(orgId);
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
                    AttendanceTypeId = (record.AttendanceTypeId > 0) ? record.AttendanceTypeId : null,
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
}
