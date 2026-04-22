using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Data;
using backend.Models;
using backend.Data;
using backend.Hubs;
using Microsoft.AspNetCore.SignalR;

namespace backend.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class AllowancesController : ControllerBase
{
    private readonly DataBaseConnection _db;
    private readonly ILogger<AllowancesController> _logger;
    private readonly IHubContext<AllowancesHub> _hubContext;
    private readonly IHubContext<StaffAllowanceHub> _staffHubContext;

    public AllowancesController(DataBaseConnection db, ILogger<AllowancesController> logger, IHubContext<AllowancesHub> hubContext, IHubContext<StaffAllowanceHub> staffHubContext)
    {
        _db = db;
        _logger = logger;
        _hubContext = hubContext;
        _staffHubContext = staffHubContext;
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

    [HttpPost("SaveAllowance")]
    public async Task<IActionResult> SaveAllowance([FromQuery] int? orgId, [FromBody] Allowances allowances)
    {
        try
        {
            int finalOrgId = orgId ?? GetOrgId();
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_SaveAllowance", new
            {
                OrganizationID = finalOrgId,
                allowances.FullName,
                allowances.ShortName
            }, commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{finalOrgId}").SendAsync("ReceiveAllowanceUpdate", "Added");

            return Ok(new { message = "Allowance saved successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving Allowance");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpPut("UpdateAllowance")]
    public async Task<IActionResult> UpdateAllowance([FromQuery] int? orgId, [FromBody] Allowances allowances)
    {
        try
        {
            int finalOrgId = orgId ?? GetOrgId();
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_UpdateAllowance", new
            {
                allowances.AllowencesId,
                OrganizationID = finalOrgId,
                allowances.FullName,
                allowances.ShortName
            }, commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{finalOrgId}").SendAsync("ReceiveAllowanceUpdate", "Updated");

            return Ok(new { message = "Allowance updated successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating Allowance");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpGet("GetAllowanceByOrgId")]
    public async Task<IActionResult> GetAllowanceByOrgId([FromQuery] int? orgId)
    {
        try
        {
            int finalOrgId = orgId ?? GetOrgId();
            using var conn = _db.CreateConnection();
            var allowances = await conn.QueryAsync<Allowances>("sp_GetAllowanceByOrgId", new { OrganizationID = finalOrgId }, commandType: CommandType.StoredProcedure);
            return Ok(allowances);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching Allowance by OrgId");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpGet("GetAllowanceById")]
    public async Task<IActionResult> GetAllowanceById(int allowanceId)
    {
        try
        {
            using var conn = _db.CreateConnection();
            var allowances = await conn.QueryFirstOrDefaultAsync<Allowances>("sp_GetAllowanceById", new { AllowencesId = allowanceId }, commandType: CommandType.StoredProcedure);
            return Ok(allowances);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching Allowance by Id");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpDelete("DeleteAllowance")]
    public async Task<IActionResult> DeleteAllowance(int allowanceId, [FromQuery] int? orgId)
    {
        try
        {
            int finalOrgId = orgId ?? GetOrgId();
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_DeleteAllowance", new { AllowencesId = allowanceId }, commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{finalOrgId}").SendAsync("ReceiveAllowanceUpdate", "Deleted");

            return Ok(new { message = "Allowance deleted successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting Allowance");
            return StatusCode(500, ex.Message);
        }
    }

    // ── STAFF ALLOWANCE METHODS ──────────────────────────────────────────────

    [HttpPost("SaveStaffAllowance")]
    public async Task<IActionResult> SaveStaffAllowance([FromQuery] int? orgId, [FromBody] StaffAllowance staffAllowance)
    {
        try
        {
            int finalOrgId = orgId ?? GetOrgId();
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_SaveStaffAllowance", new
            {
                staffAllowance.AllowenceId,
                staffAllowance.EmployeeID,
                staffAllowance.CalType,
                staffAllowance.Amount,
                CreatedBy = GetUserId()
            }, commandType: CommandType.StoredProcedure);

            await _staffHubContext.Clients.Group($"Org_{finalOrgId}").SendAsync("ReceiveStaffAllowanceUpdate", "Added");

            return Ok(new { message = "Staff Allowance saved successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving Staff Allowance");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpPut("UpdateStaffAllowance")]
    public async Task<IActionResult> UpdateStaffAllowance([FromQuery] int? orgId, [FromBody] StaffAllowance staffAllowance)
    {
        try
        {
            int finalOrgId = orgId ?? GetOrgId();
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_UpdateStaffAllowance", new
            {
                staffAllowance.StaffAllowanceId,
                staffAllowance.AllowenceId,
                staffAllowance.EmployeeID,
                staffAllowance.CalType,
                staffAllowance.Amount
            }, commandType: CommandType.StoredProcedure);

            await _staffHubContext.Clients.Group($"Org_{finalOrgId}").SendAsync("ReceiveStaffAllowanceUpdate", "Updated");

            return Ok(new { message = "Staff Allowance updated successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating Staff Allowance");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpGet("GetStaffAllowanceByOrgId")]
    public async Task<IActionResult> GetStaffAllowanceByOrgId([FromQuery] int? orgId)
    {
        try
        {
            int finalOrgId = orgId ?? GetOrgId();
            using var conn = _db.CreateConnection();
            var staffAllowances = await conn.QueryAsync<StaffAllowance>("sp_GetStaffAllowanceByOrgId", new { OrganizationID = finalOrgId }, commandType: CommandType.StoredProcedure);
            return Ok(staffAllowances);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching Staff Allowance by OrgId");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpGet("GetStaffAllowanceById")]
    public async Task<IActionResult> GetStaffAllowanceById(int staffAllowanceId)
    {
        try
        {
            using var conn = _db.CreateConnection();
            var staffAllowance = await conn.QueryFirstOrDefaultAsync<StaffAllowance>("sp_GetStaffAllowanceById", new { StaffAllowanceId = staffAllowanceId }, commandType: CommandType.StoredProcedure);
            return Ok(staffAllowance);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching Staff Allowance by Id");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpDelete("DeleteStaffAllowance")]
    public async Task<IActionResult> DeleteStaffAllowance(int staffAllowanceId, [FromQuery] int? orgId)
    {
        try
        {
            int finalOrgId = orgId ?? GetOrgId();
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_DeleteStaffAllowance", new { StaffAllowanceId = staffAllowanceId }, commandType: CommandType.StoredProcedure);

            await _staffHubContext.Clients.Group($"Org_{finalOrgId}").SendAsync("ReceiveStaffAllowanceUpdate", "Deleted");

            return Ok(new { message = "Staff Allowance deleted successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting Staff Allowance");
            return StatusCode(500, ex.Message);
        }
    }
}
