using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Data;
using backend.Models;
using backend.Data;
using backend.Hubs;
using Microsoft.AspNetCore.SignalR;

namespace backend.Controllers;

[Authorize(Roles = "SuperAdmin")]
[ApiController]
[Route("api/[controller]")]
public class ProfessionalTaxController : ControllerBase
{
    private readonly DataBaseConnection _db;
    private readonly IHubContext<ProfessionalTaxHub> _hubContext;
    private readonly ILogger<ProfessionalTaxController> _logger;

    public ProfessionalTaxController(DataBaseConnection db, ILogger<ProfessionalTaxController> logger, IHubContext<ProfessionalTaxHub> hubContext)
    {
        _db = db;
        _logger = logger;
        _hubContext = hubContext;
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

    [HttpPost("SaveProfessionalTax")]
    public async Task<IActionResult> SaveProfessionalTax([FromBody] ProfessionalTax pt)
    {
        try
        {
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_CreateProfessionalTax", new
            {
                pt.TaxName,
                pt.FromAmount,
                pt.ToAmount,
                pt.TaxAmount,
                pt.OrganizationId,
                pt.IsActive,
                CreatedBy = GetUserId()
            }, commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{pt.OrganizationId}").SendAsync("ProfessionalTaxChanged", new { action = "Create" });

            return Ok(new { message = "Professional Tax saved successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving Professional Tax");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpPut("UpdateProfessionalTax")]
    public async Task<IActionResult> UpdateProfessionalTax([FromBody] ProfessionalTax pt)
    {
        try
        {
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_UpdateProfessionalTax", new
            {
                pt.PTId,
                pt.TaxName,
                pt.FromAmount,
                pt.ToAmount,
                pt.TaxAmount,
                pt.OrganizationId,
                pt.IsActive,
                CreatedBy = GetUserId()
            }, commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{pt.OrganizationId}").SendAsync("ProfessionalTaxChanged", new { action = "Update" });

            return Ok(new { message = "Professional Tax updated successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating Professional Tax");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpGet("GetProfessionalTax")]
    public async Task<IActionResult> GetProfessionalTax()
    {
        try
        {
            using var conn = _db.CreateConnection();
            var result = await conn.QueryAsync<ProfessionalTax>("sp_GetProfessionalTaxByOrgId", new { OrganizationId = GetOrgId() }, commandType: CommandType.StoredProcedure);
            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching Professional Tax");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpDelete("DeleteProfessionalTax")]
    public async Task<IActionResult> DeleteProfessionalTax(int ptId)
    {
        try
        {
            using var conn = _db.CreateConnection();
            // Since we don't have the orgId conveniently here but we have it in PTId,
            // we could fetch it first for SignalR or just use CurrentOrgId if we assume the requester belongs to that org.
            // For now, use CurrentOrgId for broadcast group as per the OT model.
            
            await conn.ExecuteAsync("sp_DeleteProfessionalTax", new { PTId = ptId }, commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{GetOrgId()}").SendAsync("ProfessionalTaxChanged", new { action = "Delete" });

            return Ok(new { message = "Professional Tax deleted successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting Professional Tax");
            return StatusCode(500, ex.Message);
        }
    }
}
