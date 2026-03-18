using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.Authorization;
using Dapper;
using System.Data;
using backend.Models;
using backend.Data;
using backend.Hubs;

namespace backend.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class LeadsController : ControllerBase
{
    private readonly DataBaseConnection _dataBaseConnection;
    private readonly IHubContext<LeadsHub> _hubContext;
    private readonly ILogger<LeadsController> _logger;

    public LeadsController(DataBaseConnection dataBaseConnection, IHubContext<LeadsHub> hubContext, ILogger<LeadsController> logger)
    {
        _dataBaseConnection = dataBaseConnection;
        _hubContext = hubContext;
        _logger = logger;
    }

    private int GetOrgId() 
    {
        var orgClaim = User.FindFirst("OrganizationId")?.Value;
        return int.TryParse(orgClaim, out var id) ? id : 0;
    }

    private int GetUserId()
    {
        var claim = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        return int.TryParse(claim, out var id) ? id : 0;
    }

    [HttpGet]
    public async Task<IEnumerable<Lead>> GetLeads()
    {
        using var conn = _dataBaseConnection.CreateConnection();
        return await conn.QueryAsync<Lead>("sp_GetLeads", new { OrganizationId = GetOrgId() }, commandType: CommandType.StoredProcedure);
    }

    [HttpPost]
    public async Task<IActionResult> AddLead(Lead lead)
    {
        var orgId = GetOrgId();
        _logger.LogInformation("[Leads] ADD requested | OrgId={OrgId} | Name={Name}", orgId, lead.Name);
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            var parameters = new
            {
                OrganizationId = orgId,
                lead.Salutation, lead.Name, lead.Email, lead.LeadSource, lead.AddedBy, lead.LeadOwner,
                lead.CreateDeal, lead.AutoConvert, lead.DealName, lead.Pipeline, lead.DealStages,
                lead.DealValue, lead.CloseDate, lead.DealCategory, lead.DealAgent, lead.Products,
                lead.DealWatcher, lead.Company, lead.Website, lead.Address, lead.City, lead.State, lead.Country,
                CreatedBy = GetUserId()
            };
            var results = await conn.QueryAsync<Lead>("sp_AddLead", parameters, commandType: CommandType.StoredProcedure);
            var refreshedLeads = results.ToList();
            await _hubContext.Clients.All.SendAsync("LeadListUpdated", new { Action = "Add", LeadName = lead.Name, Data = refreshedLeads });
            _logger.LogInformation("[Leads] ADD success | OrgId={OrgId} | Name={Name}", orgId, lead.Name);
            return Ok(refreshedLeads);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Leads] ADD failed | OrgId={OrgId} | Name={Name}", orgId, lead.Name);
            return StatusCode(500, "Failed to add lead");
        }
    }

    [HttpPut]
    public async Task<IActionResult> UpdateLead(Lead lead)
    {
        var orgId = GetOrgId();
        _logger.LogInformation("[Leads] UPDATE requested | OrgId={OrgId} | Id={Id} | Name={Name}", orgId, lead.Id, lead.Name);
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            var parameters = new
            {
                lead.Id, OrganizationId = orgId,
                lead.Salutation, lead.Name, lead.Email, lead.LeadSource, lead.AddedBy, lead.LeadOwner,
                lead.CreateDeal, lead.AutoConvert, lead.DealName, lead.Pipeline, lead.DealStages,
                lead.DealValue, lead.CloseDate, lead.DealCategory, lead.DealAgent, lead.Products,
                lead.DealWatcher, lead.Company, lead.Website, lead.Address, lead.City, lead.State, lead.Country,
                LastUpdatedBy = GetUserId()
            };
            var results = await conn.QueryAsync<Lead>("sp_UpdateLead", parameters, commandType: CommandType.StoredProcedure);
            var refreshedLeads = results.ToList();
            await _hubContext.Clients.All.SendAsync("LeadListUpdated", new { Action = "Update", LeadName = lead.Name, Data = refreshedLeads });
            _logger.LogInformation("[Leads] UPDATE success | OrgId={OrgId} | Id={Id}", orgId, lead.Id);
            return Ok(refreshedLeads);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Leads] UPDATE failed | OrgId={OrgId} | Id={Id}", orgId, lead.Id);
            return StatusCode(500, "Failed to update lead");
        }
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteLead(int id)
    {
        var orgId = GetOrgId();
        _logger.LogInformation("[Leads] DELETE requested | OrgId={OrgId} | Id={Id}", orgId, id);
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            var results = await conn.QueryAsync<Lead>("sp_DeleteLead", new { Id = id, OrganizationId = orgId }, commandType: CommandType.StoredProcedure);
            var refreshedLeads = results.ToList();
            await _hubContext.Clients.All.SendAsync("LeadListUpdated", new { Action = "Delete", Id = id, Data = refreshedLeads });
            _logger.LogInformation("[Leads] DELETE success | OrgId={OrgId} | Id={Id}", orgId, id);
            return Ok(refreshedLeads);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Leads] DELETE failed | OrgId={OrgId} | Id={Id}", orgId, id);
            return StatusCode(500, "Failed to delete lead");
        }
    }
}
