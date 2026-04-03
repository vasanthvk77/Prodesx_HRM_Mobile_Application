using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Data;
using backend.Models;
using backend.Data;
using backend.Hubs;
using Microsoft.AspNetCore.SignalR;

namespace backend.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class EmpOTController : BaseController<EmpOTController>
{
    private readonly DataBaseConnection _db;
    private readonly IHubContext<EmpOTHub> _hubContext;

    public EmpOTController(DataBaseConnection db, ILogger<EmpOTController> logger, IHubContext<EmpOTHub> hubContext)
        : base(logger)
    {
        _db = db;
        _hubContext = hubContext;
    }

    [HttpPost("SaveOT")]
    public async Task<IActionResult> SaveOT([FromBody] EmpOT empOT)
    {
        try
        {
            empOT.Remarks = HandleRemarks(empOT.Remarks);
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_SaveOT", new
            {
                empOT.OrganizationId,
                empOT.EmployeeId,
                empOT.OverDutyDate,
                empOT.Hours,
                empOT.RatePerHour,
                empOT.Remarks,
                CreatedBy = CurrentUserId
            }, commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{empOT.OrganizationId}").SendAsync("ReceiveOTUpdate", "Added");

            return Ok(new { message = "OT saved successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving OT");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpPut("UpdateOT")]
    public async Task<IActionResult> UpdateOT([FromBody] EmpOT empOT)
    {
        try
        {
            empOT.Remarks = HandleRemarks(empOT.Remarks);
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_UpdateOT", new
            {
                empOT.OverDutyId,
                empOT.OrganizationId,
                empOT.EmployeeId,
                empOT.OverDutyDate,
                empOT.Hours,
                empOT.RatePerHour,
                empOT.Remarks,
                CreatedBy = CurrentUserId
            }, commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{empOT.OrganizationId}").SendAsync("ReceiveOTUpdate", "Updated");

            return Ok(new { message = "OT updated successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating OT");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpGet("GetOTByOrgId")]
    public async Task<IActionResult> GetOTByOrgId(int orgId)
    {
        try
        {
            using var conn = _db.CreateConnection();
            var ot = await conn.QueryAsync<EmpOT>("sp_GetOTByOrgId", new { OrganizationId = orgId }, commandType: CommandType.StoredProcedure);
            return Ok(ot);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching OT by OrgId");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpGet("GetOTByEmpId")]
    public async Task<IActionResult> GetOTByEmpId(int empId)
    {
        try
        {
            using var conn = _db.CreateConnection();
            var ot = await conn.QueryAsync<EmpOT>("sp_GetOTByEmpId", new { EmployeeId = empId }, commandType: CommandType.StoredProcedure);
            return Ok(ot);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching OT by EmpId");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpDelete("DeleteOT")]
    public async Task<IActionResult> DeleteOT(int otId, int orgId)
    {
        try
        {
            using var conn = _db.CreateConnection();
            await conn.ExecuteAsync("sp_DeleteOT", new { OverDutyId = otId }, commandType: CommandType.StoredProcedure);

            await _hubContext.Clients.Group($"Org_{orgId}").SendAsync("ReceiveOTUpdate", "Deleted");

            return Ok(new { message = "OT deleted successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting OT");
            return StatusCode(500, ex.Message);
        }
    }

    private string HandleRemarks(string remarks)
    {
        if (string.IsNullOrEmpty(remarks)) return string.Empty;
        
        if (remarks.Length > 250)
        {
            return remarks.Substring(0, 250);
        }
        else
        {
            return remarks;
        }
    }
}
