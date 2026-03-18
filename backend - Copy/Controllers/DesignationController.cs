using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using System.Data;
using backend.Models;
using backend.Data;
using backend.Hubs;

namespace backend.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/designations")]
    public class DesignationController : ControllerBase
    {
        private readonly DataBaseConnection _db;
        private readonly IHubContext<DesignationHub> _hubContext;
        private readonly ILogger<DesignationController> _logger;

        public DesignationController(DataBaseConnection db, IHubContext<DesignationHub> hubContext, ILogger<DesignationController> logger)
        {
            _db = db;
            _hubContext = hubContext;
            _logger = logger;
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
        public async Task<IActionResult> GetDesignations([FromQuery] int? organizationId)
        {
            var orgId = organizationId ?? GetOrgId();
            try
            {
                using var conn = _db.CreateConnection();
                var parametrs = new DynamicParameters();
                parametrs.Add("@OrgId", orgId);
                var designations = await conn.QueryAsync<Designation>("sp_GetDesignationsByOrganization", parametrs, commandType: CommandType.StoredProcedure);
                _logger.LogInformation("Fetched {Count} designations for OrgId {OrgId}", designations.Count(), orgId);
                return Ok(designations);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching designations for OrgId: {OrgId}", orgId);
                return StatusCode(500, new { message = ex.Message });
            }
        }

        [HttpPost]
        public async Task<IActionResult> CreateDesignation([FromBody] CreateDesignationRequest req)
        {
            try
            {
                using var conn = _db.CreateConnection();
                var parametrs = new DynamicParameters();
                parametrs.Add("@OrganizationId", req.OrganizationId);
                parametrs.Add("@DesignationName", req.DesignationName);
                parametrs.Add("@ParentDesignationId", req.ParentDesignationId);
                parametrs.Add("@CreatedBy", GetUserId());
                
                await conn.ExecuteAsync("sp_InsertDesignation", parametrs, commandType: CommandType.StoredProcedure);

                await _hubContext.Clients.All.SendAsync("ReceiveDesignationUpdate");
                return Ok(new { message = "Designation added successfully" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating designation");
                return StatusCode(500, new { message = ex.Message });
            }
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateDesignation(int id, [FromBody] CreateDesignationRequest req)
        {
            try
            {
                using var conn = _db.CreateConnection();
                var parametrs = new DynamicParameters();
                parametrs.Add("@Id", id);
                parametrs.Add("@DesignationName", req.DesignationName);
                parametrs.Add("@ParentDesignationId", req.ParentDesignationId);
                parametrs.Add("@LastUpdatedBy", GetUserId());
                
                await conn.ExecuteAsync("sp_UpdateDesignation", parametrs, commandType: CommandType.StoredProcedure);

                await _hubContext.Clients.All.SendAsync("ReceiveDesignationUpdate");
                return Ok(new { message = "Designation updated successfully" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error updating designation {Id}", id);
                return StatusCode(500, new { message = ex.Message });
            }
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteDesignation(int id)
        {
            try
            {
                using var conn = _db.CreateConnection();
                var parametrs = new DynamicParameters();
                parametrs.Add("@Id", id);

                await conn.ExecuteAsync("sp_UpdateAndDeleteDesignation", parametrs, commandType: CommandType.StoredProcedure);

                await _hubContext.Clients.All.SendAsync("ReceiveDesignationUpdate");
                return Ok(new { message = "Designation deleted successfully" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error deleting designation {Id}", id);
                return StatusCode(500, new { message = ex.Message });
            }
        }

        [HttpPost("bulk-delete")]
        public async Task<IActionResult> BulkDeleteDesignations([FromBody] List<int> ids)
        {
            if (ids == null || !ids.Any()) return BadRequest("No IDs provided");

            try
            {
                using var conn = _db.CreateConnection();
                if (conn.State == ConnectionState.Closed) conn.Open();
                using var transaction = conn.BeginTransaction();

                try
                {
                    // 1. Update children
                    await conn.ExecuteAsync("UPDATE Designations SET parent_designation_id = NULL WHERE parent_designation_id IN @Ids", new { Ids = ids }, transaction);
                    
                    // 2. Bulk delete
                    await conn.ExecuteAsync("DELETE FROM Designations WHERE id IN @Ids", new { Ids = ids }, transaction);

                    transaction.Commit();
                    await _hubContext.Clients.All.SendAsync("ReceiveDesignationUpdate");
                    return Ok(new { message = $"{ids.Count} designations deleted successfully" });
                }
                catch (Exception)
                {
                    transaction.Rollback();
                    throw;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error bulk deleting designations");
                return StatusCode(500, new { message = ex.Message });
            }
        }
    }
}
