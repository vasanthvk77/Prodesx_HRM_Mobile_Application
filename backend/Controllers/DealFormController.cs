using backend.Hubs;
using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.Mvc;
using Dapper;
using backend.Models;
using backend.Data;
using System.Data;
using Microsoft.AspNetCore.Authorization;

namespace backend.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class DealFormController : ControllerBase
    {
        private readonly DataBaseConnection _db;
        private readonly IHubContext<DealsHub> _hubContext;
        private readonly ILogger<DealFormController> _logger;

        public DealFormController(DataBaseConnection db, IHubContext<DealsHub> hubContext, ILogger<DealFormController> logger)
        {
            _db = db;
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
        public async Task<IActionResult> GetAllDeals()
        {
            var orgId = GetOrgId();
            _logger.LogInformation("[Deals] GET all | OrgId={OrgId}", orgId);
            try
            {
                using var conn = _db.CreateConnection();
                var deals = await conn.QueryAsync<Deal>("sp_GetAllDeals", 
                    new { OrganizationId = orgId }, 
                    commandType: CommandType.StoredProcedure);
                return Ok(deals);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[Deals] GET all failed | OrgId={OrgId}", orgId);
                return StatusCode(500, "Failed to fetch deals");
            }
        }

        [HttpPost]
        public async Task<IActionResult> CreateDeal([FromBody] Deal deal)
        {
            if (deal == null) return BadRequest("Deal data is null");
            var orgId = GetOrgId();
            _logger.LogInformation("[Deals] CREATE requested | OrgId={OrgId} | DealName={DealName}", orgId, deal.DealName);
            try
            {
                using var conn = _db.CreateConnection();
                await conn.ExecuteAsync("sp_insert_deal", new {
                    OrganizationId = orgId,
                    LeadName = deal.LeadContactName,
                    LeadEmail = deal.LeadEmail,
                    LeadPhone = deal.LeadPhone,
                    deal.DealName,
                    deal.Pipeline,
                    Stage = deal.DealStage,
                    Value = deal.DealValue,
                    deal.CloseDate,
                    Category = deal.DealCategory,
                    deal.Products,
                    Agent = deal.DealAgent,
                    Watcher = deal.DealWatcher,
                    CreatedBy = GetUserId()
                }, commandType: CommandType.StoredProcedure);

                await _hubContext.Clients.All.SendAsync("ReceiveDealUpdate");
                return Ok(new { message = "Deal created successfully" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[Deals] CREATE failed | OrgId={OrgId}", orgId);
                return StatusCode(500, "Failed to create deal");
            }
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateDeal(int id, [FromBody] Deal deal)
        {
            if (deal == null) return BadRequest("Deal data is null");
            var orgId = GetOrgId();
            _logger.LogInformation("[Deals] UPDATE requested | OrgId={OrgId} | Id={Id}", orgId, id);
            try
            {
                using var conn = _db.CreateConnection();
                int rows = await conn.ExecuteAsync("sp_UpdateDeal", new {
                    Id = id,
                    OrganizationId = orgId,
                    LeadName = deal.LeadContactName,
                    LeadEmail = deal.LeadEmail,
                    LeadPhone = deal.LeadPhone,
                    deal.DealName,
                    deal.Pipeline,
                    Stage = deal.DealStage,
                    Value = deal.DealValue,
                    deal.CloseDate,
                    Category = deal.DealCategory,
                    deal.Products,
                    Agent = deal.DealAgent,
                    Watcher = deal.DealWatcher,
                    LastUpdatedBy = GetUserId()
                }, commandType: CommandType.StoredProcedure);

                if (rows == 0) return NotFound("Deal not found");

                await _hubContext.Clients.All.SendAsync("ReceiveDealUpdate");
                return Ok(new { message = "Deal updated successfully" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[Deals] UPDATE failed | OrgId={OrgId} | Id={Id}", orgId, id);
                return StatusCode(500, "Failed to update deal");
            }
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteDeal(int id)
        {
            var orgId = GetOrgId();
            _logger.LogInformation("[Deals] DELETE requested | OrgId={OrgId} | Id={Id}", orgId, id);
            try
            {
                using var conn = _db.CreateConnection();
                int rows = await conn.ExecuteAsync("sp_DeleteDeal", 
                    new { Id = id, OrganizationId = orgId }, 
                    commandType: CommandType.StoredProcedure);
                
                if (rows == 0) return NotFound("Deal not found");

                await _hubContext.Clients.All.SendAsync("ReceiveDealUpdate");
                return Ok(new { message = "Deal deleted successfully" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[Deals] DELETE failed | OrgId={OrgId} | Id={Id}", orgId, id);
                return StatusCode(500, "Failed to delete deal");
            }
        }
    }
}
