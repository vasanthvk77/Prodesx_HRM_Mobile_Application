using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using System.Data;
using backend.Models;
using backend.Data;
using backend.Hubs;
using backend.Services;

namespace backend.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/holidays")]
    public class HolidaysController : ControllerBase
    {
        private readonly DataBaseConnection _db;
        private readonly ILogger<HolidaysController> _logger;
        private readonly IHubContext<HolidaysHub> _hubContext;
        private readonly ExportService _exportService;

        public HolidaysController(DataBaseConnection db, ILogger<HolidaysController> logger, IHubContext<HolidaysHub> hubContext, ExportService exportService)
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
        public async Task<IActionResult> GetHolidays([FromQuery] int? organizationId)
        {
            var orgId = organizationId ?? GetOrgId();
            try
            {
                using var conn = _db.CreateConnection();
                var holidays = await conn.QueryAsync<Holiday>(
                    "sp_GetHolidays",
                    new { OrgId = orgId },
                    commandType: CommandType.StoredProcedure
                );
                return Ok(holidays);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching holidays for OrgId: {OrgId}", orgId);
                return StatusCode(500, new { message = ex.Message });
            }
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetHolidayById(int id)
        {
            var orgId = GetOrgId();
            try
            {
                using var conn = _db.CreateConnection();
                using var multi = await conn.QueryMultipleAsync(
                    "sp_GetHolidayById",
                    new { Id = id, OrgId = orgId },
                    commandType: CommandType.StoredProcedure
                );

                var holiday = await multi.ReadFirstOrDefaultAsync<HolidayWithAssignments>();
                if (holiday == null)
                    return NotFound();

                holiday.Assignments = (await multi.ReadAsync<HolidayAssignment>()).ToList();
                return Ok(holiday);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching holiday {Id}", id);
                return StatusCode(500, new { message = ex.Message });
            }
        }

        [HttpPost]
        [Authorize(Roles = "Admin,SuperAdmin")]
        public async Task<IActionResult> CreateHoliday([FromBody] HolidayWithAssignments holiday)
        {
            return await UpsertHoliday(0, holiday);
        }

        [HttpPut("{id}")]
        [Authorize(Roles = "Admin,SuperAdmin")]
        public async Task<IActionResult> UpdateHoliday(int id, [FromBody] HolidayWithAssignments holiday)
        {
            return await UpsertHoliday(id, holiday);
        }

        private async Task<IActionResult> UpsertHoliday(int id, HolidayWithAssignments holiday)
        {
            var orgId = GetOrgId();
            var userId = GetUserId();
            
            if (string.IsNullOrWhiteSpace(holiday.HolidayName))
                return BadRequest(new { message = "Holiday name is required" });

            try
            {
                using var conn = _db.CreateConnection();
                var assignmentsJson = holiday.AssignmentType == "Custom" && holiday.Assignments != null
                    ? System.Text.Json.JsonSerializer.Serialize(holiday.Assignments.Select(a => new { target_type = a.TargetType, target_id = a.TargetId }))
                    : null;

                var parameters = new
                {
                    HolidayID = id,
                    OrgId = orgId,
                    HolidayName = holiday.HolidayName,
                    HolidayDate = holiday.HolidayDate,
                    AssignmentType = holiday.AssignmentType,
                    UserId = userId,
                    AssignmentsJson = assignmentsJson
                };

                var holidayId = await conn.ExecuteScalarAsync<int>(
                    "sp_UpsertHoliday",
                    parameters,
                    commandType: CommandType.StoredProcedure
                );

                holiday.HolidayID = holidayId;
                holiday.OrganizationID = orgId;

                // SignalR Notification
                await _hubContext.Clients.Group($"Org_{orgId}").SendAsync("HolidayChanged", new { action = id == 0 ? "Create" : "Update", holidayId = holidayId });

                _logger.LogInformation("Holiday {HolidayName} upserted with ID {HolidayId}", holiday.HolidayName, holidayId);
                return Ok(holiday);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error upserting holiday");
                return StatusCode(500, new { message = ex.Message });
            }
        }

        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin,SuperAdmin")]
        public async Task<IActionResult> DeleteHoliday(int id)
        {
            var orgId = GetOrgId();
            try
            {
                using var conn = _db.CreateConnection();
                var sql = "DELETE FROM Holidays WHERE HolidayID = @Id AND OrganizationID = @OrgId";
                var rowsAffected = await conn.ExecuteAsync(sql, new { Id = id, OrgId = orgId });
                
                if (rowsAffected == 0)
                    return NotFound(new { message = "Holiday not found" });

                // SignalR Notification
                await _hubContext.Clients.Group($"Org_{orgId}").SendAsync("HolidayChanged", new { action = "Delete", holidayId = id });

                _logger.LogInformation("Holiday {Id} deleted", id);
                return Ok(new { message = "Holiday deleted successfully" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error deleting holiday {Id}", id);
                return StatusCode(500, new { message = ex.Message });
            }
        }

        [HttpGet("export-excel")]
        public async Task<IActionResult> ExportToExcel([FromQuery] int? organizationId, [FromQuery] string? form, [FromQuery] int? year, [FromQuery] DateTime? startDate, [FromQuery] DateTime? endDate)
        {
            var orgId = organizationId ?? GetOrgId();
            try
            {
                using var conn = _db.CreateConnection();
                var org = await conn.QueryFirstOrDefaultAsync<Organization>("SELECT * FROM organizations WHERE id = @Id", new { Id = orgId });
                if (org == null) return NotFound("Organization not found");

                var employees = await conn.QueryAsync<Employee>("SELECT * FROM employees WHERE organization_id = @OrgId AND status = 'Active'", new { OrgId = orgId });
                
                // Fetch all holidays with their assignments for eligibility check
                var holidays = await conn.QueryAsync<HolidayWithAssignments>("sp_GetHolidays", new { OrgId = orgId }, commandType: CommandType.StoredProcedure);
                foreach (var h in holidays)
                {
                    using var multi = await conn.QueryMultipleAsync("sp_GetHolidayById", new { Id = h.HolidayID, OrgId = orgId }, commandType: CommandType.StoredProcedure);
                    await multi.ReadFirstOrDefaultAsync(); // skip main holiday record
                    h.Assignments = (await multi.ReadAsync<HolidayAssignment>()).ToList();
                }

                var excelBytes = _exportService.GenerateFormVIExcel(employees.ToList(), holidays.ToList(), org, year, startDate, endDate);
                var fileName = $"Form_VI_Holidays_{org.Name.Replace(" ", "_")}_{DateTime.Now:yyyyMMdd}.xlsx";
                return File(excelBytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", fileName);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error exporting holidays to Excel");
                return StatusCode(500, new { message = ex.Message });
            }
        }

        [HttpGet("export-pdf")]
        public async Task<IActionResult> ExportToPdf([FromQuery] int? organizationId, [FromQuery] string? form, [FromQuery] int? year, [FromQuery] DateTime? startDate, [FromQuery] DateTime? endDate)
        {
            var orgId = organizationId ?? GetOrgId();
            try
            {
                using var conn = _db.CreateConnection();
                var org = await conn.QueryFirstOrDefaultAsync<Organization>("SELECT * FROM organizations WHERE id = @Id", new { Id = orgId });
                if (org == null) return NotFound("Organization not found");

                var employees = await conn.QueryAsync<Employee>("SELECT * FROM employees WHERE organization_id = @OrgId AND status = 'Active'", new { OrgId = orgId });
                
                var holidays = await conn.QueryAsync<HolidayWithAssignments>("sp_GetHolidays", new { OrgId = orgId }, commandType: CommandType.StoredProcedure);
                foreach (var h in holidays)
                {
                    using var multi = await conn.QueryMultipleAsync("sp_GetHolidayById", new { Id = h.HolidayID, OrgId = orgId }, commandType: CommandType.StoredProcedure);
                    await multi.ReadFirstOrDefaultAsync();
                    h.Assignments = (await multi.ReadAsync<HolidayAssignment>()).ToList();
                }

                var pdfBytes = _exportService.GenerateFormVIPdf(employees.ToList(), holidays.ToList(), org, year, startDate, endDate);
                var fileName = $"Form_VI_Holidays_{org.Name.Replace(" ", "_")}_{DateTime.Now:yyyyMMdd}.pdf";
                return File(pdfBytes, "application/pdf", fileName);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error exporting holidays to PDF");
                return StatusCode(500, new { message = ex.Message });
            }
        }
    }
}
