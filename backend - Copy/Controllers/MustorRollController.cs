using System.Data;
using System.Text.Json;
using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using backend.Data;
using backend.Hubs;
using backend.Models;

namespace backend.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class MustorRollController : ControllerBase
{
    private readonly DataBaseConnection _db;
    private readonly ILogger<MustorRollController> _logger;
    private readonly IHubContext<MustorRollHub> _hubContext;
    private readonly backend.Services.ExportService _exportService;

    public MustorRollController(DataBaseConnection db, ILogger<MustorRollController> logger, IHubContext<MustorRollHub> hubContext, backend.Services.ExportService exportService)
    {
        _db = db;
        _logger = logger;
        _hubContext = hubContext;
        _exportService = exportService;
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

    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] int? organizationId)
    {
        var userOrgId = GetOrgId();
        var targetOrgId = (organizationId.HasValue && organizationId > 0) ? organizationId.Value : userOrgId;

        try
        {
            using var conn = _db.CreateConnection();
            var rows = await conn.QueryAsync<MustorRollRecord>(
                "sp_GetMustorRolls",
                new { OrganizationId = targetOrgId },
                commandType: CommandType.StoredProcedure);
            return Ok(rows);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[MustorRoll] GET failed | OrgId={OrgId}", targetOrgId);
            return StatusCode(500, "Failed to fetch muster roll records");
        }
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] UpsertMustorRollRequest req)
    {
        var userOrgId = GetOrgId();
        var targetOrgId = (req.OrganizationId.HasValue && req.OrganizationId > 0) ? req.OrganizationId.Value : userOrgId;

        if (req.EmployeeId <= 0) return BadRequest(new { message = "EmployeeId is required" });
        if (string.IsNullOrWhiteSpace(req.WomanName)) return BadRequest(new { message = "WomanName is required" });

        var attendanceJson = req.AttendanceRows != null ? JsonSerializer.Serialize(req.AttendanceRows, new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase }) : null;

        try
        {
            using var conn = _db.CreateConnection();
            var newId = await conn.ExecuteScalarAsync<int>(
                "sp_CreateMustorRoll",
                new
                {
                    OrganizationId = targetOrgId,
                    EmployeeId = req.EmployeeId,
                    WomanName = req.WomanName,
                    Age = req.Age,
                    HusbandOrFatherName = req.HusbandOrFatherName,
                    NatureOfWork = req.NatureOfWork,
                    DateOfEmployment = req.DateOfEmployment,
                    AttendanceJson = attendanceJson,
                    NoticePregnancyDate = req.NoticePregnancyDate,
                    NoticeDeliveryDate = req.NoticeDeliveryDate,
                    ProofBirthDate = req.ProofBirthDate,
                    ProofDeathDate = req.ProofDeathDate,
                    AdvanceAmount = req.AdvanceAmount,
                    AdvanceDate = req.AdvanceDate,
                    SubsequentAmount = req.SubsequentAmount,
                    SubsequentDate = req.SubsequentDate,
                    BonusAmount = req.BonusAmount,
                    LeaveWagesSec9 = req.LeaveWagesSec9,
                    LeaveWagesSec10 = req.LeaveWagesSec10,
                    Remarks = req.Remarks,
                    CreatedBy = GetUserId()
                },
                commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{targetOrgId}")
                .SendAsync("MustorRollChanged", new { action = "Create", id = newId });

            return Ok(new { message = "Muster Roll created", id = newId });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[MustorRoll] CREATE failed | OrgId={OrgId}", targetOrgId);
            return StatusCode(500, new { message = $"Failed to create muster roll: {ex.Message}" });
        }
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpsertMustorRollRequest req)
    {
        var userOrgId = GetOrgId();
        var targetOrgId = (req.OrganizationId.HasValue && req.OrganizationId > 0) ? req.OrganizationId.Value : userOrgId;

        if (id <= 0) return BadRequest(new { message = "Invalid id" });
        if (req.EmployeeId <= 0) return BadRequest(new { message = "EmployeeId is required" });
        if (string.IsNullOrWhiteSpace(req.WomanName)) return BadRequest(new { message = "WomanName is required" });

        var attendanceJson = req.AttendanceRows != null ? JsonSerializer.Serialize(req.AttendanceRows, new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase }) : null;

        try
        {
            using var conn = _db.CreateConnection();
            var rows = await conn.ExecuteAsync(
                "sp_UpdateMustorRoll",
                new
                {
                    Id = id,
                    OrganizationId = targetOrgId,
                    EmployeeId = req.EmployeeId,
                    WomanName = req.WomanName,
                    Age = req.Age,
                    HusbandOrFatherName = req.HusbandOrFatherName,
                    NatureOfWork = req.NatureOfWork,
                    DateOfEmployment = req.DateOfEmployment,
                    AttendanceJson = attendanceJson,
                    NoticePregnancyDate = req.NoticePregnancyDate,
                    NoticeDeliveryDate = req.NoticeDeliveryDate,
                    ProofBirthDate = req.ProofBirthDate,
                    ProofDeathDate = req.ProofDeathDate,
                    AdvanceAmount = req.AdvanceAmount,
                    AdvanceDate = req.AdvanceDate,
                    SubsequentAmount = req.SubsequentAmount,
                    SubsequentDate = req.SubsequentDate,
                    BonusAmount = req.BonusAmount,
                    LeaveWagesSec9 = req.LeaveWagesSec9,
                    LeaveWagesSec10 = req.LeaveWagesSec10,
                    Remarks = req.Remarks,
                    LastUpdatedBy = GetUserId()
                },
                commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{targetOrgId}")
                .SendAsync("MustorRollChanged", new { action = "Update", id });

            return Ok(new { message = "Muster Roll updated", rowsAffected = rows });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[MustorRoll] UPDATE failed | Id={Id} | OrgId={OrgId}", id, targetOrgId);
            return StatusCode(500, new { message = $"Failed to update muster roll: {ex.Message}" });
        }
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id, [FromQuery] int? organizationId)
    {
        var userOrgId = GetOrgId();
        var targetOrgId = (organizationId.HasValue && organizationId > 0) ? organizationId.Value : userOrgId;

        try
        {
            using var conn = _db.CreateConnection();
            var rows = await conn.ExecuteAsync(
                "sp_DeleteMustorRoll",
                new { Id = id, OrganizationId = targetOrgId },
                commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{targetOrgId}")
                .SendAsync("MustorRollChanged", new { action = "Delete", id });

            return Ok(new { message = "Muster Roll deleted", rowsAffected = rows });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[MustorRoll] DELETE failed | Id={Id} | OrgId={OrgId}", id, targetOrgId);
            return StatusCode(500, new { message = $"Failed to delete muster roll: {ex.Message}" });
        }
    }
    [HttpGet("export-excel")]
    public async Task<IActionResult> ExportExcel([FromQuery] int organizationId, [FromQuery] string? ids)
    {
        var userOrgId = GetOrgId();
        var targetOrgId = organizationId > 0 ? organizationId : userOrgId;
        try
        {
            var records = await GetMustorRollsForExport(targetOrgId, ids);
            var org = await GetOrganization(targetOrgId);
            var excelData = _exportService.GenerateMustorRollsExcel(records, org);
            return File(excelData, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", $"MustorRoll_{DateTime.Now:yyyyMMdd}.xlsx");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[MustorRoll] EXCEL EXPORT failed");
            return StatusCode(500, new { message = "Failed to export Excel" });
        }
    }

    [HttpGet("export-pdf")]
    public async Task<IActionResult> ExportPdf([FromQuery] int organizationId, [FromQuery] string? ids)
    {
        var userOrgId = GetOrgId();
        var targetOrgId = organizationId > 0 ? organizationId : userOrgId;
        try
        {
            var records = await GetMustorRollsForExport(targetOrgId, ids);
            var org = await GetOrganization(targetOrgId);
            var pdfData = _exportService.GenerateMustorRollsPdf(records, org);
            return File(pdfData, "application/pdf", $"MustorRoll_{DateTime.Now:yyyyMMdd}.pdf");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[MustorRoll] PDF EXPORT failed");
            return StatusCode(500, new { message = "Failed to export PDF", error = ex.Message, stack = ex.StackTrace, inner = ex.InnerException?.Message });
        }
    }

    private async Task<List<MustorRollRecord>> GetMustorRollsForExport(int orgId, string? ids)
    {
        using var conn = _db.CreateConnection();
        var records = await conn.QueryAsync<MustorRollRecord>("sp_GetMustorRolls", new { OrganizationId = orgId }, commandType: CommandType.StoredProcedure);
        var list = records.ToList();
        
        if (!string.IsNullOrEmpty(ids))
        {
            var selectedIds = ids.Split(',', StringSplitOptions.RemoveEmptyEntries).Select(int.Parse).ToList();
            if (selectedIds.Any())
            {
                list = list.Where(x => selectedIds.Contains(x.Id)).ToList();
            }
        }
        return list;
    }

    private async Task<Organization> GetOrganization(int orgId)
    {
        using var conn = _db.CreateConnection();
        return await conn.QueryFirstOrDefaultAsync<Organization>("SELECT * FROM Organizations WHERE Id = @Id", new { Id = orgId }) 
               ?? new Organization { Name = "Organization" };
    }
}

