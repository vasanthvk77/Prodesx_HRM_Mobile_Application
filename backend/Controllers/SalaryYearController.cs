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
public class SalaryYearController : ControllerBase
{
    private readonly DataBaseConnection _db;
    private readonly IHubContext<SalaryYearHub> _hubContext;
    private readonly ILogger<SalaryYearController> _logger;

    public SalaryYearController(DataBaseConnection db, ILogger<SalaryYearController> logger, IHubContext<SalaryYearHub> hubContext)
    {
        _db = db;
        _hubContext = hubContext;
        _logger = logger;
    }

    private int? GetUserId() => int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var id) ? id : null;
    private int? GetOrganizationId() => int.TryParse(User.FindFirst("OrganizationId")?.Value, out var id) ? id : null;

    [HttpPost("SaveSalaryYear")]
    public async Task<IActionResult> SaveSalaryYear([FromQuery] string? orgId, [FromBody] SalaryYear salaryYear)
    {
        try
        {
            var userId = GetUserId();
            var finalOrgId = GetOrganizationId() ?? 0;
            if (!string.IsNullOrEmpty(orgId) && int.TryParse(orgId, out int parsed))
                finalOrgId = parsed;
                
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_AddSalaryYear", new
            {
                OrganizationID = finalOrgId,
                salaryYear.FromYear,
                salaryYear.ToYear,
                salaryYear.DateFrom,
                salaryYear.DateTo,
                CreatedBy = userId ?? 0
            }, commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{finalOrgId}").SendAsync("ReceiveSalaryYearUpdate", "Added");

            return Ok(new { message = "Salary year saved successfully." });
        }
        catch (Microsoft.Data.SqlClient.SqlException ex)
        {
            if (ex.Number == 2627 || ex.Number == 2601)
            {
                return BadRequest(new { message = $"A salary year for {salaryYear.FromYear} already exists for this organization." });
            }
            _logger.LogError(ex, "Database error saving Salary Year");
            return StatusCode(500, new { message = "A database error occurred." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving Salary Year");
            return StatusCode(500, new { message = ex.Message });
        }
    }

    [HttpPut("UpdateSalaryYear")]
    public async Task<IActionResult> UpdateSalaryYear([FromQuery] string? orgId, [FromBody] SalaryYear salaryYear)
    {
        try
        {
            var userId = GetUserId();
            var finalOrgId = GetOrganizationId() ?? 0;
            if (!string.IsNullOrEmpty(orgId) && int.TryParse(orgId, out int parsed))
                finalOrgId = parsed;
                
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_UpdateSalaryYear", new
            {
                salaryYear.SalaryYearId,
                OrganizationID = finalOrgId,
                salaryYear.FromYear,
                salaryYear.ToYear,
                salaryYear.DateFrom,
                salaryYear.DateTo,
                CreatedBy = userId ?? 0
            }, commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{finalOrgId}").SendAsync("ReceiveSalaryYearUpdate", "Updated");

            return Ok(new { message = "Salary year updated successfully." });
        }
        catch (Microsoft.Data.SqlClient.SqlException ex)
        {
            if (ex.Number == 2627 || ex.Number == 2601)
            {
                return BadRequest(new { message = $"A salary year for {salaryYear.FromYear} already exists for this organization." });
            }
            _logger.LogError(ex, "Database error updating Salary Year");
            return StatusCode(500, new { message = "A database error occurred." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating Salary Year");
            return StatusCode(500, new { message = ex.Message });
        }
    }

    [HttpGet("GetSalaryYearsByOrgId")]
    public async Task<IActionResult> GetSalaryYearsByOrgId([FromQuery] string orgId)
    {
        try
        {
            if (!int.TryParse(orgId, out int finalOrgId)) 
                finalOrgId = GetOrganizationId() ?? 0;

            using var conn = _db.CreateConnection();
            var results = await conn.QueryAsync<SalaryYear>("sp_GetSalaryYearByOrganizationID", new { OrganizationID = finalOrgId }, commandType: CommandType.StoredProcedure);
            return Ok(results);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching Salary Years by OrgId");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpGet("GetSalaryYearById")]
    public async Task<IActionResult> GetSalaryYearById(int salaryYearId)
    {
        try
        {
            using var conn = _db.CreateConnection();
            var result = await conn.QueryFirstOrDefaultAsync<SalaryYear>("sp_GetSalaryYearById", new { SalaryYearId = salaryYearId }, commandType: CommandType.StoredProcedure);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching Salary Year by Id");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpDelete("DeleteSalaryYear")]
    public async Task<IActionResult> DeleteSalaryYear(int salaryYearId, [FromQuery] string orgId)
    {
        try
        {
            if (!int.TryParse(orgId, out int finalOrgId)) 
                finalOrgId = GetOrganizationId() ?? 0;

            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_DeleteSalaryYear", new { SalaryYearId = salaryYearId }, commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{finalOrgId}").SendAsync("ReceiveSalaryYearUpdate", "Deleted");

            return Ok(new { message = "Salary year deleted successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting Salary Year");
            return StatusCode(500, ex.Message);
        }
    }
}
