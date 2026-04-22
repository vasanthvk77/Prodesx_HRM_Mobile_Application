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
public class DeductionsController : ControllerBase
{
    private readonly DataBaseConnection _db;
    private readonly ILogger<DeductionsController> _logger;
    private readonly IHubContext<DeductionsHub> _hubContext;
    private readonly IHubContext<StaffDeductionHub> _staffHubContext;

    public DeductionsController(DataBaseConnection db, ILogger<DeductionsController> logger, IHubContext<DeductionsHub> hubContext, IHubContext<StaffDeductionHub> staffHubContext)
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

    [HttpPost("SaveDeduction")]
    public async Task<IActionResult> SaveDeduction([FromQuery] int? orgId, [FromBody] Deductions deductions)
    {
        try
        {
            int finalOrgId = orgId ?? GetOrgId();
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_SaveDeduction", new
            {
                OrganizationID = finalOrgId,
                deductions.FullName,
                deductions.ShortName
            }, commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{finalOrgId}").SendAsync("ReceiveDeductionUpdate", "Added");

            return Ok(new { message = "Deduction saved successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving Deduction");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpPut("UpdateDeduction")]
    public async Task<IActionResult> UpdateDeduction([FromQuery] int? orgId, [FromBody] Deductions deductions)
    {
        try
        {
            int finalOrgId = orgId ?? GetOrgId();
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_UpdateDeduction", new
            {
                deductions.DeductionsId,
                OrganizationID = finalOrgId,
                deductions.FullName,
                deductions.ShortName
            }, commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{finalOrgId}").SendAsync("ReceiveDeductionUpdate", "Updated");

            return Ok(new { message = "Deduction updated successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating Deduction");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpGet("GetDeductionsByOrgId")]
    public async Task<IActionResult> GetDeductionsByOrgId([FromQuery] int? orgId)
    {
        try
        {
            int finalOrgId = orgId ?? GetOrgId();
            using var conn = _db.CreateConnection();
            var deductions = await conn.QueryAsync<Deductions>("sp_GetDeductionsByOrgId", new { OrganizationID = finalOrgId }, commandType: CommandType.StoredProcedure);
            return Ok(deductions);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching Deductions by OrgId");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpGet("GetDeductionById")]
    public async Task<IActionResult> GetDeductionById(int deductionId)
    {
        try
        {
            using var conn = _db.CreateConnection();
            var deduction = await conn.QueryFirstOrDefaultAsync<Deductions>("sp_GetDeductionById", new { DeductionsId = deductionId }, commandType: CommandType.StoredProcedure);
            return Ok(deduction);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching Deduction by Id");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpDelete("DeleteDeduction")]
    public async Task<IActionResult> DeleteDeduction(int deductionId, [FromQuery] int? orgId)
    {
        try
        {
            int finalOrgId = orgId ?? GetOrgId();
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_DeleteDeduction", new { DeductionsId = deductionId }, commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{finalOrgId}").SendAsync("ReceiveDeductionUpdate", "Deleted");

            return Ok(new { message = "Deduction deleted successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting Deduction");
            return StatusCode(500, ex.Message);
        }
    }

    // ── STAFF DEDUCTION METHODS ──────────────────────────────────────────────

    [HttpPost("SaveStaffDeduction")]
    public async Task<IActionResult> SaveStaffDeduction([FromQuery] int? orgId, [FromBody] StaffDeduction staffDeduction)
    {
        try
        {
            int finalOrgId = orgId ?? GetOrgId();
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_SaveStaffDeduction", new
            {
                staffDeduction.DeductionId,
                staffDeduction.EmployeeID,
                staffDeduction.CalType,
                staffDeduction.Amount,
                CreatedBy = GetUserId()
            }, commandType: CommandType.StoredProcedure);

            await _staffHubContext.Clients.Group($"Org_{finalOrgId}").SendAsync("ReceiveStaffDeductionUpdate", "Added");

            return Ok(new { message = "Staff Deduction saved successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving Staff Deduction");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpPut("UpdateStaffDeduction")]
    public async Task<IActionResult> UpdateStaffDeduction([FromQuery] int? orgId, [FromBody] StaffDeduction staffDeduction)
    {
        try
        {
            int finalOrgId = orgId ?? GetOrgId();
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_UpdateStaffDeduction", new
            {
                staffDeduction.StaffDeductionId,
                staffDeduction.DeductionId,
                staffDeduction.EmployeeID,
                staffDeduction.CalType,
                staffDeduction.Amount
            }, commandType: CommandType.StoredProcedure);

            await _staffHubContext.Clients.Group($"Org_{finalOrgId}").SendAsync("ReceiveStaffDeductionUpdate", "Updated");

            return Ok(new { message = "Staff Deduction updated successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating Staff Deduction");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpGet("GetStaffDeductionsByOrgId")]
    public async Task<IActionResult> GetStaffDeductionsByOrgId([FromQuery] int? orgId)
    {
        try
        {
            int finalOrgId = orgId ?? GetOrgId();
            using var conn = _db.CreateConnection();
            var staffDeductions = await conn.QueryAsync<StaffDeduction>("sp_GetStaffDeductionsByOrgId", new { OrganizationID = finalOrgId }, commandType: CommandType.StoredProcedure);
            return Ok(staffDeductions);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching Staff Deduction by OrgId");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpGet("GetStaffDeductionById")]
    public async Task<IActionResult> GetStaffDeductionById(int staffDeductionId)
    {
        try
        {
            using var conn = _db.CreateConnection();
            var staffDeduction = await conn.QueryFirstOrDefaultAsync<StaffDeduction>("sp_GetStaffDeductionById", new { StaffDeductionId = staffDeductionId }, commandType: CommandType.StoredProcedure);
            return Ok(staffDeduction);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching Staff Deduction by Id");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpDelete("DeleteStaffDeduction")]
    public async Task<IActionResult> DeleteStaffDeduction(int staffDeductionId, [FromQuery] int? orgId)
    {
        try
        {
            int finalOrgId = orgId ?? GetOrgId();
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_DeleteStaffDeduction", new { StaffDeductionId = staffDeductionId }, commandType: CommandType.StoredProcedure);

            await _staffHubContext.Clients.Group($"Org_{finalOrgId}").SendAsync("ReceiveStaffDeductionUpdate", "Deleted");

            return Ok(new { message = "Staff Deduction deleted successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting Staff Deduction");
            return StatusCode(500, ex.Message);
        }
    }
}
