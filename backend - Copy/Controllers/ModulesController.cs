using System.Data;
using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using backend.Data;
using backend.Models;

namespace backend.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class ModulesController : ControllerBase
{
    private readonly DataBaseConnection _db;
    private readonly ILogger<ModulesController> _logger;

    public ModulesController(DataBaseConnection db, ILogger<ModulesController> logger)
    {
        _db = db;
        _logger = logger;
    }

    private int GetOrgId()
    {
        var claim = User.FindFirst("OrganizationId")?.Value;
        return int.TryParse(claim, out var id) ? id : 0;
    }

    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] int? organizationId)
    {
        var userOrgId = GetOrgId();
        var targetOrgId = (organizationId.HasValue && organizationId > 0) ? organizationId.Value : userOrgId;

        try
        {
            using var conn = _db.CreateConnection();
            var modules = await conn.QueryAsync<ModuleInfo>(
                "sp_GetOrganizationModules",
                new { OrganizationId = targetOrgId },
                commandType: CommandType.StoredProcedure);
            return Ok(modules);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Modules] GET failed | OrgId={OrgId}", targetOrgId);
            return StatusCode(500, "Failed to fetch organization modules");
        }
    }

    [HttpPost("toggle")]
    public async Task<IActionResult> Toggle([FromBody] ToggleModuleRequest req)
    {
        var userOrgId = GetOrgId();
        var targetOrgId = (req.OrganizationId.HasValue && req.OrganizationId > 0) ? req.OrganizationId.Value : userOrgId;

        // Security check: Only Admins or SuperAdmins can toggle modules
        var userRole = User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value;
        if (userRole != "SuperAdmin" && userRole != "Admin")
        {
            return Forbid();
        }

        try
        {
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync(
                "sp_ToggleOrganizationModule",
                new
                {
                    OrganizationId = targetOrgId,
                    ModuleId = req.ModuleID,
                    IsEnabled = req.IsEnabled
                },
                commandType: CommandType.StoredProcedure);

            _logger.LogInformation("[Modules] Toggled module | OrgId={OrgId} | ModuleId={ModuleId} | Enabled={Enabled}", targetOrgId, req.ModuleID, req.IsEnabled);
            return Ok(new { message = "Module updated successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Modules] TOGGLE failed | OrgId={OrgId} | ModuleId={ModuleId}", targetOrgId, req.ModuleID);
            return StatusCode(500, "Failed to toggle module");
        }
    }
}
