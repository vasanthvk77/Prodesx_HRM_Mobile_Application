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
    [Route("api/departments")]
    public class DepartmentController : ControllerBase
    {
        private readonly DataBaseConnection _db;
        private readonly IHubContext<DepartmentHub> _hubContext;
        private readonly ILogger<DepartmentController> _logger;

        public DepartmentController(DataBaseConnection db, IHubContext<DepartmentHub> hubContext, ILogger<DepartmentController> logger)
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
        public async Task<IActionResult> GetDepartments([FromQuery] int? organizationId)
        {
            var orgId = organizationId ?? GetOrgId();
            try
            {
                using var conn = _db.CreateConnection();
                var parametrs = new DynamicParameters();
                parametrs.Add("@OrgId", orgId);
                
                var departments = await conn.QueryAsync<Department>("sp_GetDepartmentsByOrganization", parametrs, commandType: CommandType.StoredProcedure);
                return Ok(departments);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching departments for OrgId: {OrgId}", orgId);
                return StatusCode(500, new { message = ex.Message });
            }
        }

        [HttpPost]
        public async Task<IActionResult> CreateDepartment([FromBody] CreateDepartmentRequest req)
        {
            try
            {
                using var conn = _db.CreateConnection();
               var parametrs = new DynamicParameters();
                parametrs.Add("@OrgId", req.OrganizationId);
                parametrs.Add("@Name", req.DepartmentName);
                parametrs.Add("@ParentId", req.ParentDepartmentId);
                parametrs.Add("@CreatedBy", GetUserId());
                
                await conn.ExecuteAsync("sp_InsertDepartment", parametrs, commandType: CommandType.StoredProcedure);

                await _hubContext.Clients.All.SendAsync("ReceiveDepartmentUpdate");
                return Ok(new { message = "Department added successfully" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating department");
                return StatusCode(500, new { message = ex.Message });
            }
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateDepartment(int id, [FromBody] CreateDepartmentRequest req)
        {
            try
            {
                using var conn = _db.CreateConnection();
                var parametrs = new DynamicParameters();
                parametrs.Add("@Id", id);
                parametrs.Add("@Name", req.DepartmentName);
                parametrs.Add("@ParentId", req.ParentDepartmentId);
                parametrs.Add("@LastUpdatedBy", GetUserId());
                
                await conn.ExecuteAsync("sp_UpdateDepartment", parametrs, commandType: CommandType.StoredProcedure);

                await _hubContext.Clients.All.SendAsync("ReceiveDepartmentUpdate");
                return Ok(new { message = "Department updated successfully" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error updating department {Id}", id);
                return StatusCode(500, new { message = ex.Message });
            }
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteDepartment(int id)
        {
            try
            {
                using var conn = _db.CreateConnection();
                var parametrs = new DynamicParameters();
                parametrs.Add("@Id", id);

                await conn.ExecuteAsync("sp_UpdateAndDeleteDepartment", parametrs, commandType: CommandType.StoredProcedure);

                await _hubContext.Clients.All.SendAsync("ReceiveDepartmentUpdate");
                return Ok(new { message = "Department deleted successfully" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error deleting department {Id}", id);
                return StatusCode(500, new { message = ex.Message });
            }
        }

        [HttpPost("bulk-delete")]
        public async Task<IActionResult> BulkDeleteDepartments([FromBody] List<int> ids)
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
                    await conn.ExecuteAsync("UPDATE Departments SET parent_department_id = NULL WHERE parent_department_id IN @Ids", new { Ids = ids }, transaction);

                    // 2. Delete
                    await conn.ExecuteAsync("DELETE FROM Departments WHERE id IN @Ids", new { Ids = ids }, transaction);

                    transaction.Commit();
                    await _hubContext.Clients.All.SendAsync("ReceiveDepartmentUpdate");
                    return Ok(new { message = $"{ids.Count} departments deleted successfully" });
                }
                catch (Exception)
                {
                    transaction.Rollback();
                    throw;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error bulk deleting departments");
                return StatusCode(500, new { message = ex.Message });
            }
        }
    }
}
