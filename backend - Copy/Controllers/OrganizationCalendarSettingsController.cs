using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Data;
using backend.Models;
using backend.Data;
using System.Security.Claims;

namespace backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Admin,SuperAdmin")]
public class OrganizationCalendarSettingsController : ControllerBase
{
    private readonly DataBaseConnection _db;
    private readonly ILogger<OrganizationCalendarSettingsController> _logger;

    public OrganizationCalendarSettingsController(DataBaseConnection db, ILogger<OrganizationCalendarSettingsController> logger)
    {
        _db = db;
        _logger = logger;
    }

    private int? GetUserId() => int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var id) ? id : null;
    private string? GetUserName() => User.FindFirst(ClaimTypes.Name)?.Value;
    private int? GetOrganizationId() => int.TryParse(User.FindFirst("OrganizationId")?.Value, out var id) ? id : null;

    [HttpGet]
    public async Task<IActionResult> GetSettings([FromQuery] int organizationId)
    {
        var userId = GetUserId();
        if (userId == null) return BadRequest(new { message = "User ID not found in token" });

        _logger.LogInformation("[CalendarSettings] GET requested for Org={OrgId} by User={UserId}", organizationId, userId);

        using var conn = _db.CreateConnection();
        var settings = await conn.QueryFirstOrDefaultAsync<OrganizationCalendarSettings>(
            "sp_GetOrganizationCalendarSettings",
            new { OrganizationID = organizationId },
            commandType: CommandType.StoredProcedure);

        return Ok(settings);
    }

    [HttpPost]
    public async Task<IActionResult> SaveSettings([FromBody] UpsertCalendarSettingsRequest request)
    {
        var orgId = GetOrganizationId();
        var userId = GetUserId();
        var userName = GetUserName();

        if (orgId == null || userId == null) 
            return BadRequest(new { message = "Missing authentication context" });

        _logger.LogInformation("[CalendarSettings] SAVE requested for Org={OrgId} by User={UserId}", orgId, userId);

        try
        {
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_UpsertOrganizationCalendarSettings",
                new { 
                    OrganizationID = request.OrganizationId,
                    request.AcademicStartMonth,
                    request.AcademicStartDay,
                    request.AcademicEndMonth,
                    request.AcademicEndDay,
                    request.SalaryStartDay,
                    request.SalaryEndDay,
                    UserID = userId,
                    UserName = userName ?? "Unknown"
                },
                commandType: CommandType.StoredProcedure);

            return Ok(new { message = "Calendar settings saved successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[CalendarSettings] SAVE failed | Org={OrgId}", orgId);
            return StatusCode(500, "Failed to save calendar settings");
        }
    }
}
