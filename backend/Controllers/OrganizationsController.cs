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
[Authorize]
public class OrganizationsController : ControllerBase
{
    private readonly DataBaseConnection _db;
    private readonly ILogger<OrganizationsController> _logger;

    public OrganizationsController(DataBaseConnection db, ILogger<OrganizationsController> logger)
    {
        _db = db;
        _logger = logger;
    }

    private string? GetUserRole() => User.FindFirst(ClaimTypes.Role)?.Value;
    private int? GetUserId() => int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var id) ? id : null;

    // GET /api/organizations - List organizations
    [HttpGet]
    public async Task<IActionResult> GetOrganizations()
    {
        var role = GetUserRole();
        var userId = GetUserId();
        
        _logger.LogInformation("[Orgs] GET all requested | Role={Role} | UserId={UserId}", role, userId);

        using var conn = _db.CreateConnection();
        if (role == "SuperAdmin")
        {
            var allOrgs = await conn.QueryAsync<Organization>(
                "sp_GetAllOrganizations",
                commandType: CommandType.StoredProcedure);
            return Ok(allOrgs);
        }
        else
        {
            // For Admin/User, return only organizations they have active access to.
            // sp_GetUserOrganizations does not return columns that map 1:1 to the
            // Organization model, so we project manually just like UsersController.
            var rows = await conn.QueryAsync(
                "sp_GetUserOrganizations",
                new { UserID = userId },
                commandType: CommandType.StoredProcedure);

            var myOrgs = rows.Select(r => new Organization
            {
                Id    = (int)r.OrganizationID,
                Name  = (string)r.OrganizationName,
                Email = (string?)r.OrganizationEmail,
                // Stored procedure exposes logo_url as OrganizationLogo; if that changes,
                // this will simply remain null rather than breaking.
                LogoUrl = (string?)r.OrganizationLogo
            });

            return Ok(myOrgs);
        }
    }

    // GET /api/organizations/{id} - Get specific organization
    [HttpGet("{id}")]
    public async Task<IActionResult> GetOrganization(int id)
    {
        _logger.LogInformation("[Orgs] GET by ID={Id}", id);
        using var conn = _db.CreateConnection();
        var org = await conn.QueryFirstOrDefaultAsync<Organization>("sp_GetOrganizationById", 
            new { Id = id }, 
            commandType: CommandType.StoredProcedure);

        if (org == null) return NotFound(new { message = "Organization not found" });

        return Ok(org);
    }

    // POST /api/organizations - Create new organization
    [HttpPost]
    [Authorize(Roles = "SuperAdmin")]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> CreateOrganization([FromForm] CreateOrganizationRequest request)
    {
        _logger.LogInformation("[Orgs] CREATE requested | Name={Name}", request.Name);
        try
        {
            using var conn = _db.CreateConnection();

            var exists = await conn.ExecuteScalarAsync<int>(
                "sp_CheckOrganizationExists", new { Name = request.Name }, commandType: CommandType.StoredProcedure);
            if (exists > 0)
                return Conflict(new { message = "An organization with this name already exists." });

            string? logoUrl = null;
            if (request.Logo != null && request.Logo.Length > 0)
            {
                logoUrl = await SaveLogo(request.Logo);
            }

            var newId = await conn.ExecuteScalarAsync<int>("sp_CreateOrganization",
                new { request.Name, request.Email, request.Phone, request.Address, LogoUrl = logoUrl },
                commandType: CommandType.StoredProcedure);


            _logger.LogInformation("[Orgs] CREATE success | Id={Id} | Name={Name}", newId, request.Name);
            return Ok(new { id = newId, name = request.Name, logoUrl, message = "Organization created successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Orgs] CREATE failed | Name={Name}", request.Name);
            return StatusCode(500, "Failed to create organization");
        }
    }

    // PUT /api/organizations/{id} - Update organization
    [HttpPut("{id}")]
    [Authorize(Roles = "SuperAdmin")]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> UpdateOrganization(int id, [FromForm] UpdateOrganizationRequest request)
    {
        _logger.LogInformation("[Orgs] UPDATE requested | Id={Id} | Name={Name}", id, request.Name);
        try
        {
            using var conn = _db.CreateConnection();

            var exists = await conn.QueryFirstOrDefaultAsync<Organization>("sp_GetOrganizationById", 
                new { Id = id }, 
                commandType: CommandType.StoredProcedure);
            if (exists == null) return NotFound(new { message = "Organization not found" });

            string? logoUrl = null;
            if (request.Logo != null && request.Logo.Length > 0)
            {
                logoUrl = await SaveLogo(request.Logo);
            }

            await conn.ExecuteAsync("sp_UpdateOrganization",
                new { 
                    Id = id, 
                    Name = request.Name, 
                    request.Email, 
                    request.Phone, 
                    request.Address, 
                    LogoUrl = logoUrl
                },
                commandType: CommandType.StoredProcedure);


            _logger.LogInformation("[Orgs] UPDATE success | Id={Id}", id);
            return Ok(new { message = "Organization updated successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Orgs] UPDATE failed | Id={Id}", id);
            return StatusCode(500, "Failed to update organization");
        }
    }

    // DELETE /api/organizations/{id} - Delete organization
    [HttpDelete("{id}")]
    [Authorize(Roles = "SuperAdmin")]
    public async Task<IActionResult> DeleteOrganization(int id)
    {
        _logger.LogInformation("[Orgs] DELETE requested | Id={Id}", id);
        try
        {
            using var conn = _db.CreateConnection();
            
            var exists = await conn.QueryFirstOrDefaultAsync<Organization>("sp_GetOrganizationById", 
                new { Id = id }, 
                commandType: CommandType.StoredProcedure);
            if (exists == null) return NotFound(new { message = "Organization not found" });

            // Delete organization
            await conn.ExecuteAsync("sp_DeleteOrganization", 
                new { Id = id }, 
                commandType: CommandType.StoredProcedure);

            _logger.LogInformation("[Orgs] DELETE success | Id={Id}", id);
            return Ok(new { message = "Organization deleted successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Orgs] DELETE failed | Id={Id}", id);
            return StatusCode(500, "Failed to delete organization");
        }
    }

    private async Task<string> SaveLogo(IFormFile logo)
    {
        var allowed = new[] { "image/jpeg", "image/png", "image/webp", "image/gif" };
        if (!allowed.Contains(logo.ContentType.ToLower()))
            throw new Exception("Only JPEG, PNG, WebP, or GIF images are allowed.");

        if (logo.Length > 2 * 1024 * 1024)
            throw new Exception("Logo file size must be under 2 MB.");

        var ext = Path.GetExtension(logo.FileName).ToLower();
        var fileName = $"org-logo-{Guid.NewGuid():N}{ext}";
        var folder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads", "org-logos");
        Directory.CreateDirectory(folder);

        var fullPath = Path.Combine(folder, fileName);
        using (var stream = new FileStream(fullPath, FileMode.Create))
            await logo.CopyToAsync(stream);

        return $"/uploads/org-logos/{fileName}";
    }
}

public class UpdateOrganizationRequest
{
    public string Name { get; set; } = "";
    public string? Email { get; set; }
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public IFormFile? Logo { get; set; }
}
