using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Dapper;
using System.Data;
using System.Security.Claims;
using backend.Models;
using backend.Data;
using Microsoft.AspNetCore.SignalR;
using backend.Hubs;

namespace backend.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class LeaveTypeController : ControllerBase
{
    private readonly DataBaseConnection _dataBaseConnection;
    private readonly IHubContext<AttendanceHub> _hubContext;
    private readonly ILogger<LeaveTypeController> _logger;

    public LeaveTypeController(DataBaseConnection dataBaseConnection, IHubContext<AttendanceHub> hubContext, ILogger<LeaveTypeController> logger)
    {
        _dataBaseConnection = dataBaseConnection;
        _hubContext = hubContext;
        _logger = logger;
    }

    private int CurrentOrgId
    {
        get
        {
            var orgClaim = User.FindFirst("OrganizationId")?.Value;
            return int.TryParse(orgClaim, out var id) ? id : 0;
        }
    }

    private int CurrentUserId
    {
        get
        {
            var userClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            return int.TryParse(userClaim, out var id) ? id : 0;
        }
    }

    private bool IsSuperAdmin => User.IsInRole("SuperAdmin");

    [HttpGet]
    public async Task<IActionResult> GetLeaveTypes([FromQuery] int? orgId)
    {
        var finalOrgId = (IsSuperAdmin && orgId.HasValue && orgId.Value > 0) ? orgId.Value : CurrentOrgId;
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            var leaveTypes = await conn.QueryAsync<LeaveType>(
                "sp_GetLeaveTypesForOrg",
                new { OrganizationId = finalOrgId },
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

    [Authorize(Roles = "SuperAdmin,Admin")]
    [HttpGet("settings")]
    public async Task<IActionResult> GetLeaveTypeSettings([FromQuery] int? orgId)
    {
        var finalOrgId = orgId ?? CurrentOrgId;
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            var settings = await conn.QueryAsync<LeaveType>(
                "sp_GetLeaveTypeSettings",
                new { OrganizationId = finalOrgId },
                commandType: CommandType.StoredProcedure
            );
            return Ok(settings);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching leave type settings");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpPost("toggle")]
    public async Task<IActionResult> ToggleLeaveType([FromBody] ToggleLeaveTypeRequest request)
    {
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            await conn.ExecuteAsync(
                "sp_ToggleLeaveTypeVisibility",
                new
                {
                    request.LeaveTypeId,
                    OrganizationId = request.OrganizationId,
                    request.IsShow,
                    CreatedBy = CurrentUserId
                },
                commandType: CommandType.StoredProcedure
            );
            await _hubContext.Clients.Group($"Org_{request.OrganizationId}").SendAsync("LeaveTypeChanged");
            return Ok(new { message = "Visibility updated" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error toggling leave type");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpPost]
    public async Task<IActionResult> UpsertLeaveType([FromBody] LeaveTypeUpsertRequest request)
    {
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            
            // Check for duplicate in master LeaveType table
            var is_exist = await conn.QueryFirstOrDefaultAsync<int?>(
                @"select 1 from LeaveType 
                  where (FullName = @FullName or ShortName = @ShortName)
                  and (@LeaveTypeId is null or LeaveTypeId != @LeaveTypeId)",
                new { 
                    FullName = request.FullName, 
                    ShortName = request.ShortName,
                    LeaveTypeId = request.LeaveTypeId
                });

            if (is_exist.HasValue)
            {
                return BadRequest(new { message = "Leave type name or short name already exists" });
            }

            var newId = await conn.ExecuteScalarAsync<byte>(
                "sp_UpsertLeaveType",
                new
                {
                    request.LeaveTypeId,
                    request.FullName,
                    request.ShortName,
                    request.IsPaid,
                    OrganizationId = request.OrganizationId,
                    CreatedBy = CurrentUserId
                },
                commandType: CommandType.StoredProcedure
            );
            await _hubContext.Clients.Group($"Org_{request.OrganizationId}").SendAsync("LeaveTypeChanged");
            return Ok(new { id = newId, message = "Saved successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error upserting leave type");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteLeaveType(byte id, [FromQuery] int? orgId)
    {
        var finalOrgId = orgId ?? CurrentOrgId;
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            await conn.ExecuteAsync(
                "sp_DeleteLeaveType",
                new { LeaveTypeId = id, OrganizationId = finalOrgId },
                commandType: CommandType.StoredProcedure
            );
            await _hubContext.Clients.Group($"Org_{finalOrgId}").SendAsync("LeaveTypeChanged");
            return Ok(new { message = "Deleted from your organization" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting leave type");
            return StatusCode(500, ex.Message);
        }
    }
}
