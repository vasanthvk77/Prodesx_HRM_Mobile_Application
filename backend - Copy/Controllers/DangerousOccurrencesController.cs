// using backend.Hubs;
// using Microsoft.AspNetCore.SignalR;
// using Microsoft.AspNetCore.Mvc;
// using Dapper;
// using backend.Models;
// using backend.Data;
// using System.Data;
// using Microsoft.AspNetCore.Authorization;
// using System.Security.Claims;

// namespace backend.Controllers
// {
//     [Authorize]
//     [ApiController]
//     [Route("api/[controller]")]
//     public class DangerousOccurrencesController : ControllerBase
//     {
//         private readonly DataBaseConnection _db;
//         private readonly Hubs.DangerousOccurrencesHub _dangerousHub;
//         private readonly IHubContext<DangerousOccurrencesHub> _hubContext;
//         private readonly ILogger<DangerousOccurrencesController> _logger;
//         private readonly Services.ExportService _exportService;

//         public DangerousOccurrencesController(
//             DataBaseConnection db, 
//             IHubContext<DangerousOccurrencesHub> hubContext, 
//             ILogger<DangerousOccurrencesController> logger,
//             Services.ExportService exportService)
//         {
//             _db = db;
//             _hubContext = hubContext;
//             _logger = logger;
//             _exportService = exportService;
//         }

//         private string GetUserName()
//         {
//             return User.FindFirst(ClaimTypes.Name)?.Value ?? "Unknown User";
//         }

//         private int GetOrgId()
//         {
//             var claim = User.FindFirst("OrganizationId")?.Value;
//             return int.TryParse(claim, out var id) ? id : 0;
//         }

//         private async Task<Organization> GetOrganization(int orgId)
//         {
//             using var conn = _db.CreateConnection();
//             return await conn.QueryFirstOrDefaultAsync<Organization>("SELECT * FROM Organizations WHERE Id = @Id", new { Id = orgId }) 
//                    ?? new Organization { Name = "Organization" };
//         }

//         [HttpGet]
//         public async Task<IActionResult> GetAllOccurrences([FromQuery] int? orgId, [FromQuery] int? year, [FromQuery] DateTime? fromDate, [FromQuery] DateTime? toDate)
//         {
//             var targetOrgId = (orgId.HasValue && orgId > 0) ? orgId.Value : GetOrgId();
//             _logger.LogInformation("[DangerousOccurrences] GET all | OrgId={OrgId} | Year={Year} | From={FromDate} | To={ToDate}", targetOrgId, year, fromDate, toDate);
//             try
//             {
//                 using var conn = _db.CreateConnection();
//                 var sql = "SELECT * FROM Dangerous_Occurrences_Register WHERE org_id = @OrgId";
                
//                 if (fromDate.HasValue) sql += " AND occurrence_datetime >= @FromDate";
//                 if (toDate.HasValue) sql += " AND occurrence_datetime <= @ToDate";
                
//                 if (!fromDate.HasValue && !toDate.HasValue && year.HasValue) 
//                     sql += " AND calendar_year = @Year";

//                 sql += " ORDER BY calendar_year DESC, dangerous_occurrence_serial_no DESC";
                
//                 var occurrences = await conn.QueryAsync<DangerousOccurrence>(sql, new { 
//                     OrgId = targetOrgId, 
//                     Year = year, 
//                     FromDate = fromDate, 
//                     ToDate = toDate?.Date.AddDays(1).AddTicks(-1) 
//                 });
//                 return Ok(occurrences);
//             }
//             catch (Exception ex)
//             {
//                 _logger.LogError(ex, "[DangerousOccurrences] GET all failed | OrgId={OrgId}", targetOrgId);
//                 return StatusCode(500, "Failed to fetch dangerous occurrences");
//             }
//         }

//         [HttpPost]
//         public async Task<IActionResult> CreateOccurrence([FromBody] DangerousOccurrence occ)
//         {
//             if (occ == null) return BadRequest("Data is null");
//             occ.OrgId = occ.OrgId > 0 ? occ.OrgId : GetOrgId();
//             _logger.LogInformation("[DangerousOccurrences] CREATE requested | OrgId={OrgId}", occ.OrgId);
//             try
//             {
//                 occ.CreatedBy = GetUserName();
//                 using var conn = _db.CreateConnection();
//                 var query = @"
//                     INSERT INTO Dangerous_Occurrences_Register (
//                         org_id, calendar_year, dangerous_occurrence_serial_no, occurrence_datetime, 
//                         form18A_despatch_date, dangerous_occurrence_place, occurrence_description_action_taken, 
//                         damage_details_damage_loss_repair_replacement_cost, manager_remarks_and_initials, 
//                         created_by, created_at
//                     ) VALUES (
//                         @OrgId, @CalendarYear, @DangerousOccurrenceSerialNo, @OccurrenceDatetime, 
//                         @Form18aDespatchDate, @DangerousOccurrencePlace, @OccurrenceDescriptionActionTaken, 
//                         @DamageDetailsDamageLossRepairReplacementCost, @ManagerRemarksAndInitials, 
//                         @CreatedBy, SYSDATETIME()
//                     )";
                
//                 await conn.ExecuteAsync(query, occ);

//                 await _hubContext.Clients.All.SendAsync("ReceiveDangerousOccurrenceUpdate");
//                 return Ok(new { message = "Dangerous occurrence created successfully" });
//             }
//             catch (Exception ex)
//             {
//                 _logger.LogError(ex, "[DangerousOccurrences] CREATE failed | OrgId={OrgId}", occ.OrgId);
//                 return StatusCode(500, $"Failed to create dangerous occurrence: {ex.Message}");
//             }
//         }

//         [HttpPut("{id}")]
//         public async Task<IActionResult> UpdateOccurrence(int id, [FromBody] DangerousOccurrence occ)
//         {
//             if (occ == null) return BadRequest("Data is null");
//             occ.OrgId = occ.OrgId > 0 ? occ.OrgId : GetOrgId();
//             _logger.LogInformation("[DangerousOccurrences] UPDATE requested | Id={Id}", id);
//             try
//             {
//                 occ.UpdatedBy = GetUserName();
//                 using var conn = _db.CreateConnection();
//                 var query = @"
//                     UPDATE Dangerous_Occurrences_Register SET
//                         calendar_year = @CalendarYear,
//                         dangerous_occurrence_serial_no = @DangerousOccurrenceSerialNo,
//                         occurrence_datetime = @OccurrenceDatetime,
//                         form18A_despatch_date = @Form18aDespatchDate,
//                         dangerous_occurrence_place = @DangerousOccurrencePlace,
//                         occurrence_description_action_taken = @OccurrenceDescriptionActionTaken,
//                         damage_details_damage_loss_repair_replacement_cost = @DamageDetailsDamageLossRepairReplacementCost,
//                         manager_remarks_and_initials = @ManagerRemarksAndInitials,
//                         updated_by = @UpdatedBy,
//                         updated_at = SYSDATETIME()
//                     WHERE id = @Id AND org_id = @OrgId";
                
//                 int rows = await conn.ExecuteAsync(query, occ);

//                 if (rows == 0) return NotFound("Occurrence not found");

//                 await _hubContext.Clients.All.SendAsync("ReceiveDangerousOccurrenceUpdate");
//                 return Ok(new { message = "Dangerous occurrence updated successfully" });
//             }
//             catch (Exception ex)
//             {
//                 _logger.LogError(ex, "[DangerousOccurrences] UPDATE failed | Id={Id}", id);
//                 return StatusCode(500, "Failed to update dangerous occurrence");
//             }
//         }

//         [HttpDelete("{id}")]
//         public async Task<IActionResult> DeleteOccurrence(int id, [FromQuery] int? orgId)
//         {
//             var targetOrgId = (orgId.HasValue && orgId > 0) ? orgId.Value : GetOrgId();
//             _logger.LogInformation("[DangerousOccurrences] DELETE requested | Id={Id} | OrgId={OrgId}", id, targetOrgId);
//             try
//             {
//                 using var conn = _db.CreateConnection();
//                 var query = "DELETE FROM Dangerous_Occurrences_Register WHERE id = @Id AND org_id = @OrgId";
//                 int rows = await conn.ExecuteAsync(query, new { Id = id, OrgId = targetOrgId });
                
//                 if (rows == 0) return NotFound("Occurrence not found");

//                 await _hubContext.Clients.All.SendAsync("ReceiveDangerousOccurrenceUpdate");
//                 return Ok(new { message = "Dangerous occurrence deleted successfully" });
//             }
//             catch (Exception ex)
//             {
//                 _logger.LogError(ex, "[DangerousOccurrences] DELETE failed | Id={Id}", id);
//                 return StatusCode(500, "Failed to delete dangerous occurrence");
//             }
//         }

//         [HttpGet("SerialNo")]
//         public async Task<IActionResult> GetNextSerialNo([FromQuery] int? orgId, [FromQuery] int calendarYear)
//         {
//             var targetOrgId = (orgId.HasValue && orgId > 0) ? orgId.Value : GetOrgId();
//             try
//             {
//                 using var conn = _db.CreateConnection();
//                 var query = "SELECT ISNULL(MAX(dangerous_occurrence_serial_no), 0) + 1 FROM Dangerous_Occurrences_Register WHERE org_id = @OrgId AND calendar_year = @CalendarYear";
//                 int nextSerial = await conn.ExecuteScalarAsync<int>(query, new { OrgId = targetOrgId, CalendarYear = calendarYear });
//                 return Ok(new { nextSerialNo = nextSerial });
//             }
//             catch (Exception ex)
//             {
//                 _logger.LogError(ex, "[DangerousOccurrences] GetNextSerialNo failed");
//                 return StatusCode(500, "Failed to fetch serial number");
//             }
//         }

//         [HttpGet("Export")]
//         public async Task<IActionResult> Export([FromQuery] int? orgId, [FromQuery] int? year, [FromQuery] DateTime? fromDate, [FromQuery] DateTime? toDate)
//         {
//             var targetOrgId = (orgId.HasValue && orgId > 0) ? orgId.Value : GetOrgId();
//             _logger.LogInformation("[DangerousOccurrences] Export PDF | OrgId={OrgId} | Year={Year} | From={FromDate} | To={ToDate}", targetOrgId, year, fromDate, toDate);
//             try
//             {
//                 using var conn = _db.CreateConnection();
                
//                 // Fetch occurrences
//                 var sql = "SELECT * FROM Dangerous_Occurrences_Register WHERE org_id = @OrgId";
//                 if (fromDate.HasValue) sql += " AND occurrence_datetime >= @FromDate";
//                 if (toDate.HasValue) sql += " AND occurrence_datetime <= @ToDate";
                
//                 // Fallback to year if no date range
//                 if (!fromDate.HasValue && !toDate.HasValue && year.HasValue) 
//                     sql += " AND calendar_year = @Year";

//                 sql += " ORDER BY calendar_year DESC, dangerous_occurrence_serial_no DESC";
                
//                 var occurrences = (await conn.QueryAsync<DangerousOccurrence>(sql, new { OrgId = targetOrgId, Year = year, FromDate = fromDate, ToDate = toDate?.Date.AddDays(1).AddTicks(-1) })).ToList();

//                 // Fetch Organization details
//                 var org = await GetOrganization(targetOrgId);

//                 var pdfBytes = _exportService.GenerateDangerousOccurrencesPdf(occurrences, org);
                
//                 var fileName = $"Form_26A_Dangerous_Occurrences_{org.Name.Replace(" ", "_")}_{DateTime.Now:yyyyMMdd}.pdf";
//                 return File(pdfBytes, "application/pdf", fileName);
//             }
//             catch (Exception ex)
//             {
//                 _logger.LogError(ex, "[DangerousOccurrences] Export failed | OrgId={OrgId}", targetOrgId);
//                 return StatusCode(500, "Failed to generate PDF report");
//             }
//         }
//     }
// }




using backend.Hubs;
using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.Mvc;
using Dapper;
using backend.Models;
using backend.Data;
using System.Data;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;

namespace backend.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class DangerousOccurrencesController : ControllerBase
    {
        private readonly DataBaseConnection _db;
        private readonly IHubContext<DangerousOccurrencesHub> _hubContext;
        private readonly ILogger<DangerousOccurrencesController> _logger;
        private readonly Services.ExportService _exportService;

        public DangerousOccurrencesController(
            DataBaseConnection db, 
            IHubContext<DangerousOccurrencesHub> hubContext, 
            ILogger<DangerousOccurrencesController> logger,
            Services.ExportService exportService)
        {
            _db = db;
            _hubContext = hubContext;
            _logger = logger;
            _exportService = exportService;
        }

        private int GetUserId()
        {
            var claim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            return int.TryParse(claim, out var id) ? id : 0;
        }

        private int GetOrgId()
        {
            var claim = User.FindFirst("OrganizationId")?.Value;
            return int.TryParse(claim, out var id) ? id : 0;
        }

        private async Task<Organization> GetOrganization(int orgId)
        {
            using var conn = _db.CreateConnection();
            return await conn.QueryFirstOrDefaultAsync<Organization>("SELECT * FROM Organizations WHERE Id = @Id", new { Id = orgId }) 
                   ?? new Organization { Name = "Organization" };
        }

        [HttpGet]
        public async Task<IActionResult> GetAllOccurrences([FromQuery] int? orgId, [FromQuery] int? year, [FromQuery] DateTime? fromDate, [FromQuery] DateTime? toDate)
        {
            var targetOrgId = (orgId.HasValue && orgId > 0) ? orgId.Value : GetOrgId();
            _logger.LogInformation("[DangerousOccurrences] GET all | OrgId={OrgId} | Year={Year} | From={FromDate} | To={ToDate}", targetOrgId, year, fromDate, toDate);
            try
            {
                using var conn = _db.CreateConnection();
                var occurrences = await conn.QueryAsync<DangerousOccurrence>(
                    "sp_GetDangerousOccurrences",
                    new { 
                        OrgId = targetOrgId, 
                        CalendarYear = year, 
                        FromDate = fromDate, 
                        ToDate = toDate?.Date.AddDays(1).AddTicks(-1) 
                    },
                    commandType: CommandType.StoredProcedure
                );
                return Ok(occurrences);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[DangerousOccurrences] GET all failed | OrgId={OrgId}", targetOrgId);
                return StatusCode(500, "Failed to fetch dangerous occurrences");
            }
        }

        [HttpPost]
        public async Task<IActionResult> CreateOccurrence([FromBody] DangerousOccurrence occ)
        {
            if (occ == null) return BadRequest("Data is null");
            occ.OrgId = occ.OrgId > 0 ? occ.OrgId : GetOrgId();
            _logger.LogInformation("[DangerousOccurrences] CREATE requested | OrgId={OrgId}", occ.OrgId);
            try
            {
                occ.CreatedBy = GetUserId();
                using var conn = _db.CreateConnection();
                await conn.ExecuteAsync(
                    "sp_CreateDangerousOccurrence",
                    new {
                        OrgId = occ.OrgId,
                        CalendarYear = occ.CalendarYear,
                        DangerousOccurrenceSerialNo = occ.DangerousOccurrenceSerialNo,
                        OccurrenceDatetime = occ.OccurrenceDatetime,
                        Form18aDespatchDate = occ.Form18aDespatchDate,
                        DangerousOccurrencePlace = occ.DangerousOccurrencePlace,
                        OccurrenceDescriptionActionTaken = occ.OccurrenceDescriptionActionTaken,
                        DamageDetailsDamageLossRepairReplacementCost = occ.DamageDetailsDamageLossRepairReplacementCost,
                        ManagerRemarksAndInitials = occ.ManagerRemarksAndInitials,
                        CreatedBy = occ.CreatedBy
                    },
                    commandType: CommandType.StoredProcedure
                );

                await _hubContext.Clients.Group($"Org_{occ.OrgId}").SendAsync("ReceiveDangerousOccurrenceUpdate");
                return Ok(new { message = "Occurrence recorded successfully" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[DangerousOccurrences] CREATE failed | OrgId={OrgId}", occ.OrgId);
                return StatusCode(500, $"Failed to create dangerous occurrence: {ex.Message}");
            }
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateOccurrence(int id, [FromBody] DangerousOccurrence occ)
        {
            if (occ == null) return BadRequest("Data is null");
            occ.OrgId = occ.OrgId > 0 ? occ.OrgId : GetOrgId();
            _logger.LogInformation("[DangerousOccurrences] UPDATE requested | Id={Id}", id);
            try
            {
                occ.LastUpdatedBy = GetUserId();
                using var conn = _db.CreateConnection();
                int rows = await conn.ExecuteAsync(
                    "sp_UpdateDangerousOccurrence",
                    new {
                        Id = id,
                        OrgId = occ.OrgId,
                        CalendarYear = occ.CalendarYear,
                        DangerousOccurrenceSerialNo = occ.DangerousOccurrenceSerialNo,
                        OccurrenceDatetime = occ.OccurrenceDatetime,
                        Form18aDespatchDate = occ.Form18aDespatchDate,
                        DangerousOccurrencePlace = occ.DangerousOccurrencePlace,
                        OccurrenceDescriptionActionTaken = occ.OccurrenceDescriptionActionTaken,
                        DamageDetailsDamageLossRepairReplacementCost = occ.DamageDetailsDamageLossRepairReplacementCost,
                        ManagerRemarksAndInitials = occ.ManagerRemarksAndInitials,
                        UpdatedBy = occ.LastUpdatedBy
                    },
                    commandType: CommandType.StoredProcedure
                );

                if (rows == 0) return NotFound("Occurrence not found");

                await _hubContext.Clients.Group($"Org_{occ.OrgId}").SendAsync("ReceiveDangerousOccurrenceUpdate");
                return Ok(new { message = "Occurrence updated successfully" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[DangerousOccurrences] UPDATE failed | Id={Id}", id);
                return StatusCode(500, "Failed to update dangerous occurrence");
            }
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteOccurrence(int id, [FromQuery] int? orgId)
        {
            var targetOrgId = (orgId.HasValue && orgId > 0) ? orgId.Value : GetOrgId();
            _logger.LogInformation("[DangerousOccurrences] DELETE requested | Id={Id} | OrgId={OrgId}", id, targetOrgId);
            try
            {
                using var conn = _db.CreateConnection();
                int rows = await conn.ExecuteAsync(
                    "sp_DeleteDangerousOccurrence",
                    new { Id = id, OrgId = targetOrgId },
                    commandType: CommandType.StoredProcedure
                );
                
                if (rows == 0) return NotFound("Occurrence not found");

                await _hubContext.Clients.Group($"Org_{targetOrgId}").SendAsync("ReceiveDangerousOccurrenceUpdate");
                return Ok(new { message = "Occurrence deleted successfully" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[DangerousOccurrences] DELETE failed | Id={Id}", id);
                return StatusCode(500, "Failed to delete dangerous occurrence");
            }
        }

        [HttpGet("SerialNo")]
        public async Task<IActionResult> GetNextSerialNo([FromQuery] int? orgId, [FromQuery] int calendarYear)
        {
            var targetOrgId = (orgId.HasValue && orgId > 0) ? orgId.Value : GetOrgId();
            try
            {
                using var conn = _db.CreateConnection();
                int nextSerial = await conn.ExecuteScalarAsync<int>(
                    "sp_GetNextDangerousOccurrenceSerialNo",
                    new { OrgId = targetOrgId, CalendarYear = calendarYear },
                    commandType: CommandType.StoredProcedure
                );
                return Ok(new { nextSerialNo = nextSerial });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[DangerousOccurrences] GetNextSerialNo failed");
                return StatusCode(500, "Failed to fetch serial number");
            }
        }

        [HttpGet("export-pdf")]
        public async Task<IActionResult> ExportPdf([FromQuery] int? orgId, [FromQuery] int? year, [FromQuery] DateTime? fromDate, [FromQuery] DateTime? toDate, [FromQuery] string? searchQuery)
        {
            var targetOrgId = (orgId.HasValue && orgId > 0) ? orgId.Value : GetOrgId();
            _logger.LogInformation("[DangerousOccurrences] Export PDF | OrgId={OrgId} | Year={Year} | From={FromDate} | To={ToDate} | Search={Search}", targetOrgId, year, fromDate, toDate, searchQuery);
            try
            {
                var occurrences = await GetFilteredOccurrences(targetOrgId, year, fromDate, toDate, searchQuery);
                var org = await GetOrganization(targetOrgId);
                var pdfBytes = _exportService.GenerateDangerousOccurrencesPdf(occurrences, org);
                var fileName = $"Form_26A_Dangerous_Occurrences_{org.Name.Replace(" ", "_")}_{DateTime.Now:yyyyMMdd}.pdf";
                return File(pdfBytes, "application/pdf", fileName);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[DangerousOccurrences] Export PDF failed | OrgId={OrgId}", targetOrgId);
                return StatusCode(500, "Failed to generate PDF report");
            }
        }

        [HttpGet("export-excel")]
        public async Task<IActionResult> ExportExcel([FromQuery] int? orgId, [FromQuery] int? year, [FromQuery] DateTime? fromDate, [FromQuery] DateTime? toDate, [FromQuery] string? searchQuery)
        {
            var targetOrgId = (orgId.HasValue && orgId > 0) ? orgId.Value : GetOrgId();
            _logger.LogInformation("[DangerousOccurrences] Export Excel | OrgId={OrgId} | Year={Year} | From={FromDate} | To={ToDate} | Search={Search}", targetOrgId, year, fromDate, toDate, searchQuery);
            try
            {
                var occurrences = await GetFilteredOccurrences(targetOrgId, year, fromDate, toDate, searchQuery);
                var org = await GetOrganization(targetOrgId);
                var excelBytes = _exportService.GenerateDangerousOccurrencesExcel(occurrences, org);
                var fileName = $"Form_26A_Dangerous_Occurrences_{org.Name.Replace(" ", "_")}_{DateTime.Now:yyyyMMdd}.xlsx";
                return File(excelBytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", fileName);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[DangerousOccurrences] Export Excel failed | OrgId={OrgId}", targetOrgId);
                return StatusCode(500, "Failed to generate Excel report");
            }
        }

        private async Task<List<DangerousOccurrence>> GetFilteredOccurrences(int targetOrgId, int? year, DateTime? fromDate, DateTime? toDate, string? searchQuery)
        {
            using var conn = _db.CreateConnection();
            var occurrences = (await conn.QueryAsync<DangerousOccurrence>(
                "sp_GetDangerousOccurrences",
                new { 
                    OrgId = targetOrgId, 
                    CalendarYear = year, 
                    FromDate = fromDate, 
                    ToDate = toDate?.Date.AddDays(1).AddTicks(-1) 
                },
                commandType: CommandType.StoredProcedure
            )).OrderBy(o => o.DangerousOccurrenceSerialNo).ToList();

            if (!string.IsNullOrEmpty(searchQuery))
            {
                occurrences = occurrences.Where(item => 
                    (item.DangerousOccurrencePlace?.Contains(searchQuery, StringComparison.OrdinalIgnoreCase) ?? false) || 
                    (item.DangerousOccurrenceSerialNo.ToString().Contains(searchQuery))
                ).ToList();
            }

            if (occurrences.Count == 0)
            {
                var displayYear = year ?? (fromDate.HasValue ? fromDate.Value.Year : DateTime.Now.Year);
                occurrences.Add(new DangerousOccurrence
                {
                    CalendarYear = displayYear,
                    DangerousOccurrenceSerialNo = 0,
                    OccurrenceDatetime = null,
                    Form18aDespatchDate = null,
                    DangerousOccurrencePlace = $"No Dangerous Occurrences happened during the Year {displayYear}",
                    OccurrenceDescriptionActionTaken = "---------",
                    DamageDetailsDamageLossRepairReplacementCost = "---------",
                    ManagerRemarksAndInitials = "---------"
                });
            }
            return occurrences;
        }
    }
}

