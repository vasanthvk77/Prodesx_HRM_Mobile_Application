using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Dapper;
using System.Data;
using backend.Models;
using backend.Data;
using Microsoft.AspNetCore.SignalR;

namespace backend.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class LeaveTypeController : BaseController<LeaveTypeController>
{
    private readonly DataBaseConnection _dataBaseConnection;
    private readonly IHubContext<backend.Hubs.AttendanceHub> _hubContext;

    public LeaveTypeController(DataBaseConnection dataBaseConnection, IHubContext<backend.Hubs.AttendanceHub> hubContext, ILogger<LeaveTypeController> logger)
        : base(logger)
    {
        _dataBaseConnection = dataBaseConnection;
        _hubContext = hubContext;
    }

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
            var is_exist = await conn.QueryFirstOrDefaultAsync<int?>(
                @"select 1 from LeaveType 
                  where (FullName = @FullName or ShortName = @ShortName)
                  and (@LeaveTypeId is null or LeaveTypeId != @LeaveTypeId)",
                new { 
                    FullName = request.FullName, 
                    ShortName = request.ShortName,
                    OrganizationId = request.OrganizationId,
                    LeaveTypeId = request.LeaveTypeId
                });

            if (is_exist.HasValue)
            {
                _logger.LogWarning("Leave type '{FullName}' or '{ShortName}' already exists", request.FullName, request.ShortName);
                return BadRequest(new { message = "Leave type name or short name already exists in your organization" });
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
    public async Task<IActionResult> DeleteLeaveType(byte id)
    {
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            await conn.ExecuteAsync(
                "sp_DeleteLeaveType",
                new { LeaveTypeId = id, OrganizationId = CurrentOrgId },
                commandType: CommandType.StoredProcedure
            );
            await _hubContext.Clients.Group($"Org_{CurrentOrgId}").SendAsync("LeaveTypeChanged");
            return Ok(new { message = "Deleted from your organization" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting leave type");
            return StatusCode(500, ex.Message);
        }
    }
}


