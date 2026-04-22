using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Data;
using backend.Models;
using backend.Data;

namespace backend.Controllers;

[Authorize(Roles = "SuperAdmin,Admin")]
[ApiController]
[Route("api/payroll-settings")]
public class PayrollSettingsController : BaseController<PayrollSettingsController>
{
    private readonly DataBaseConnection _db;

    public PayrollSettingsController(DataBaseConnection db, ILogger<PayrollSettingsController> logger)
        : base(logger)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<IActionResult> GetSettings()
    {
        try
        {
            using var conn = _db.CreateConnection();
            var rows = await conn.QueryAsync<dynamic>(
                "sp_GetStatutorySettingsByOrgId",
                new { OrganizationId = CurrentOrgId },
                commandType: CommandType.StoredProcedure
            );

            var pf = rows.FirstOrDefault(r => r.ShortCode == "PF");
            var esi = rows.FirstOrDefault(r => r.ShortCode == "ESI");

            var settings = new OrganizationPayrollSettings
            {
                OrganizationId = CurrentOrgId,
                IsPFActive = pf?.IsActive ?? false,
                IsESIActive = esi?.IsActive ?? false,
                PFPercentage = pf?.Percentage ?? 12.00m,
                PFCapAmount = pf?.CapAmount ?? 15000.00m,
                ESIPercentage = esi?.Percentage ?? 0.75m
            };

            return Ok(settings);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching payroll settings");
            return StatusCode(500, new { message = "Error fetching payroll settings", details = ex.Message });
        }
    }

    [HttpPost]
    public async Task<IActionResult> UpsertSettings([FromBody] UpsertPayrollSettingsRequest req)
    {
        try
        {
            using var conn = _db.CreateConnection();

            bool isSuperAdmin = User.IsInRole("SuperAdmin");
            
            decimal? finalPFPercent = req.PFPercentage;
            decimal? finalPFCap = req.PFCapAmount;
            decimal? finalESIPercent = req.ESIPercentage;

            if (!isSuperAdmin)
            {
                // Regular Admin - fetch master values to ensure no overrides are made accidentally
                var rows = await conn.QueryAsync<dynamic>(
                    "sp_GetStatutorySettingsByOrgId",
                    new { OrganizationId = CurrentOrgId },
                    commandType: CommandType.StoredProcedure
                );
                
                var pf = rows.FirstOrDefault(r => r.ShortCode == "PF");
                var esi = rows.FirstOrDefault(r => r.ShortCode == "ESI");

                finalPFPercent = pf?.Percentage;
                finalPFCap = pf?.CapAmount;
                finalESIPercent = esi?.Percentage;
            }

            await conn.ExecuteAsync(
                "sp_UpsertStatutorySettings",
                new
                {
                    OrganizationId = CurrentOrgId,
                    PFActive = req.IsPFActive,
                    PFPercentage = finalPFPercent,
                    PFCapAmount = finalPFCap,
                    ESIActive = req.IsESIActive,
                    ESIPercentage = finalESIPercent,
                    ModifiedBy = CurrentUserId
                },
                commandType: CommandType.StoredProcedure
            );

            return Ok(new { message = "Statutory settings updated successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating payroll settings");
            return StatusCode(500, new { message = "Error updating payroll settings", details = ex.Message });
        }
    }
}
