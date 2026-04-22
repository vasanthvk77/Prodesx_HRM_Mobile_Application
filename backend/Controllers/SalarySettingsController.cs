using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Data;
using backend.Models;
using backend.Data;
using backend.Hubs;
using System.Security.Claims;
using Microsoft.AspNetCore.SignalR;

namespace backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class SalarySettingsController : ControllerBase
{
    private readonly DataBaseConnection _db;
    private readonly IHubContext<SalarySettingsHub> _hubContext;
    private readonly IHubContext<StaffSalaryHub> _hubContextSalary;
    private readonly ILogger<SalarySettingsController> _logger;

    public SalarySettingsController(DataBaseConnection db, ILogger<SalarySettingsController> logger, IHubContext<SalarySettingsHub> hubContext, IHubContext<StaffSalaryHub> hubContextSalary)
    {
        _db = db;
        _hubContext = hubContext;
        _hubContextSalary = hubContextSalary;
        _logger = logger;
    }

    private int? GetUserId() => int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var id) ? id : null;
    private int? GetOrganizationId() => int.TryParse(User.FindFirst("OrganizationId")?.Value, out var id) ? id : null;

    private async Task<bool> ValidateEmployeeOrganization(IDbConnection conn, int employeeId, int orgId)
    {
        return await conn.ExecuteScalarAsync<bool>(
            "SELECT 1 FROM employees WHERE id = @Id AND organization_id = @OrgId",
            new { Id = employeeId, OrgId = orgId }
        );
    }

    private async Task<bool> ValidateSalaryYearOrganization(IDbConnection conn, int salaryYearId, int orgId)
    {
        return await conn.ExecuteScalarAsync<bool>(
            "SELECT 1 FROM SalaryYear WHERE SalaryYearId = @Id AND OrganizationID = @OrgId",
            new { Id = salaryYearId, OrgId = orgId }
        );
    }

    [HttpPost("SaveSalarySettings")]
    public async Task<IActionResult> SaveSalarySettings([FromQuery] string? orgId, [FromBody] SalarySettings settings)
    {
        try
        {
            var userId = GetUserId();
            var finalOrgId = GetOrganizationId() ?? 0;
            if (!string.IsNullOrEmpty(orgId) && int.TryParse(orgId, out int parsed))
                finalOrgId = parsed;

            using var conn = _db.CreateConnection();
            
            if (!await ValidateEmployeeOrganization(conn, settings.EmployeeId, finalOrgId))
                return BadRequest(new { message = "The specified employee does not belong to your organization." });

            if (!await ValidateSalaryYearOrganization(conn, settings.SalaryYearId, finalOrgId))
                return BadRequest(new { message = "The specified salary year is invalid for your organization." });

            await conn.ExecuteAsync("sp_InsertSalarySettings", new
            {
                OrganizationId = finalOrgId,
                settings.SalaryYearId,
                settings.EmployeeId,
                settings.BasicPay,
                CreatedBy = userId ?? 0,
                CreatedDateTime = DateTime.Now
            }, commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{finalOrgId}").SendAsync("ReceiveSalarySettingsUpdate", "Added");
            await _hubContextSalary.Clients.Group($"Org_{finalOrgId}").SendAsync("ReceiveAttendanceUpdate");

            return Ok(new { message = "Salary settings saved successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving Salary Settings");
            return StatusCode(500, new { message = ex.Message });
        }
    }

    [HttpPut("UpdateSalarySettings")]
    public async Task<IActionResult> UpdateSalarySettings([FromQuery] string? orgId, [FromBody] SalarySettings settings)
    {
        try
        {
            var userId = GetUserId();
            var finalOrgId = GetOrganizationId() ?? 0;
            if (!string.IsNullOrEmpty(orgId) && int.TryParse(orgId, out int parsed))
                finalOrgId = parsed;

            using var conn = _db.CreateConnection();
            
            if (!await ValidateEmployeeOrganization(conn, settings.EmployeeId, finalOrgId))
                return BadRequest(new { message = "The specified employee does not belong to your organization." });

            if (!await ValidateSalaryYearOrganization(conn, settings.SalaryYearId, finalOrgId))
                return BadRequest(new { message = "The specified salary year is invalid for your organization." });

            await conn.ExecuteAsync("sp_UpdateSalarySettings", new
            {
                settings.SSId,
                OrganizationId = finalOrgId,
                settings.SalaryYearId,
                settings.EmployeeId,
                settings.BasicPay,
                UpdatedBy = userId ?? 0,
                UpdatedDateTime = DateTime.Now
            }, commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{finalOrgId}").SendAsync("ReceiveSalarySettingsUpdate", "Updated");
            await _hubContextSalary.Clients.Group($"Org_{finalOrgId}").SendAsync("ReceiveAttendanceUpdate");

            return Ok(new { message = "Salary settings updated successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating Salary Settings");
            return StatusCode(500, new { message = ex.Message });
        }
    }

    [HttpGet("GetSalarySettings")]
    public async Task<IActionResult> GetSalarySettings([FromQuery] string orgId, [FromQuery] string salaryYearId)
    {
        try
        {
            int finalOrgId = GetOrganizationId() ?? 0;
            if (!string.IsNullOrEmpty(orgId) && int.TryParse(orgId, out int parsedOrgBase))
                finalOrgId = parsedOrgBase;

            int finalSalaryYearId = 0;
            if (!string.IsNullOrEmpty(salaryYearId) && int.TryParse(salaryYearId, out int parsedYearBase))
                finalSalaryYearId = parsedYearBase;

            using var conn = _db.CreateConnection();
            var results = await conn.QueryAsync<SalarySettings>("sp_GetSalarySettings", new 
            { 
                OrganizationId = finalOrgId, 
                SalaryYearId = finalSalaryYearId 
            }, commandType: CommandType.StoredProcedure);
            
            return Ok(results);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching Salary Settings");
            return StatusCode(500, new { message = ex.Message });
        }
    }

    [HttpDelete("DeleteSalarySettings")]
    public async Task<IActionResult> DeleteSalarySettings([FromQuery] string ssid, [FromQuery] string orgId)
    {
        try
        {
            var finalOrgId = GetOrganizationId() ?? 0;
            if (!string.IsNullOrEmpty(orgId) && int.TryParse(orgId, out int parsedOrgBase))
                finalOrgId = parsedOrgBase;

            int finalSSId = 0;
            if (!string.IsNullOrEmpty(ssid) && int.TryParse(ssid, out int parsedSSId))
                finalSSId = parsedSSId;

            using var conn = _db.CreateConnection();
            
            var recordExists = await conn.ExecuteScalarAsync<bool>(
                "SELECT 1 FROM SalarySettings WHERE SSId = @SSId AND OrganizationId = @OrgId",
                new { SSId = finalSSId, OrgId = finalOrgId });

            if (!recordExists)
                return BadRequest(new { message = "The salary record either does not exist or does not belong to the specified organization." });

            await conn.ExecuteAsync("sp_DeleteSalarySettings", new { SSId = finalSSId }, commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{finalOrgId}").SendAsync("ReceiveSalarySettingsUpdate", "Deleted");
            await _hubContextSalary.Clients.Group($"Org_{finalOrgId}").SendAsync("ReceiveAttendanceUpdate");

            return Ok(new { message = "Salary settings deleted successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting Salary Settings");
            return StatusCode(500, new { message = ex.Message });
        }
    }
}
