using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Dapper;
using System.Text;
using System.Security.Claims;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using backend.Models;
using backend.Data;
using System.Data;

namespace backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly DataBaseConnection _db;
    private readonly IConfiguration _config;
    private readonly ILogger<AuthController> _logger;

    public AuthController(DataBaseConnection db, IConfiguration config, ILogger<AuthController> logger)
    {
        _db = db;
        _config = config;
        _logger = logger;
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        _logger.LogInformation("[Auth] Login attempt | Email={Email}", request.Email);
        using var conn = _db.CreateConnection();
        var user = await conn.QueryFirstOrDefaultAsync<User>(@"
            SELECT u.*, o.logo_url as OrganizationLogo 
            FROM users u 
            LEFT JOIN organizations o ON u.organization_id = o.id 
            WHERE u.email = @Email", new { request.Email });

        if (user == null || !BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
        {
            _logger.LogWarning("[Auth] Login FAILED — invalid credentials | Email={Email}", request.Email);
            return Unauthorized(new { message = "Invalid email or password" });
        }

        // Get the specific role for the user's current organization
        var effectiveRole = user.Role; // Fallback
        
        // If not a global SuperAdmin, find the role from UserOrganizationAccess
        if (user.Role != "SuperAdmin") 
        {
            var orgAccess = await conn.QueryFirstOrDefaultAsync<dynamic>(@"
                SELECT r.RoleName 
                FROM UserOrganizationAccess a
                JOIN Roles r ON r.RoleID = a.RoleID
                WHERE a.UserID = @UserId AND a.OrganizationID = @OrgId AND a.IsActive = 1",
                new { UserId = user.Id, OrgId = user.OrganizationId });
            
            if (orgAccess != null) 
            {
                effectiveRole = orgAccess.RoleName;
            }
        }

        var (token, tokenExpiry) = GenerateJwtToken(user, effectiveRole);
        
        // Track user login session
        try
        {
            await conn.ExecuteAsync("sp_UpsertUserLoginSession",
                new
                {
                    UserId = user.Id,
                    OrganizationId = user.OrganizationId,
                    UserName = user.Name,
                    TokenExpiryAt = tokenExpiry
                },
                commandType: CommandType.StoredProcedure);
            _logger.LogInformation("[Auth] User login session recorded | UserId={UserId} | TokenExpiry={Expiry}", user.Id, tokenExpiry);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Auth] Failed to record user login session | UserId={UserId}", user.Id);
        }
        
        _logger.LogInformation("[Auth] Login SUCCESS | Email={Email} | EffectiveRole={Role} | OrgId={OrgId}", user.Email, effectiveRole, user.OrganizationId);
        
        return Ok(new { 
            token, 
            user = new { 
                user.Id, 
                user.Name, 
                user.Email, 
                role = effectiveRole, // Use effective role
                user.OrganizationId, 
                OrganizationLogo = user.OrganizationLogo 
            } 
        });
    }

    [Authorize]
    [HttpPost("switch-organization")]
    public async Task<IActionResult> SwitchOrganization([FromQuery] int organizationId)
    {
        var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (!int.TryParse(userIdStr, out int userId)) return Unauthorized();

        _logger.LogInformation("[Auth] Switch organization attempt | UserId={UserId} | TargetOrgId={OrgId}", userId, organizationId);

        using var conn = _db.CreateConnection();

        // Verify user has access to this organization
        // We'll use the same logic as UsersController/GetOrganizations
        var user = await conn.QueryFirstOrDefaultAsync<User>("SELECT * FROM users WHERE id = @Id", new { Id = userId });
        if (user == null) return NotFound();

        bool hasAccess = false;
        if (user.Role == "SuperAdmin")
        {
            hasAccess = await conn.ExecuteScalarAsync<bool>("SELECT CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END FROM organizations WHERE id = @Id", new { Id = organizationId });
        }
        else
        {
            // For Admin/User roles, check UserOrganizationAccess
            hasAccess = await conn.ExecuteScalarAsync<bool>(@"
                SELECT CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END 
                FROM UserOrganizationAccess 
                WHERE UserID = @UserId AND OrganizationID = @OrgId",
                new { UserId = userId, OrgId = organizationId });
        }

        if (!hasAccess)
        {
            _logger.LogWarning("[Auth] Switch organization FAILED — no access | UserId={UserId} | TargetOrgId={OrgId}", userId, organizationId);
            return Forbid();
        }

        // Determine the role for THIS specific organization
        string effectiveRole = user.Role; // Fallback to primary role
        if (user.Role != "SuperAdmin")
        {
            var accessRole = await conn.ExecuteScalarAsync<string>(@"
                SELECT r.RoleName 
                FROM UserOrganizationAccess a
                JOIN Roles r ON r.RoleID = a.RoleID
                WHERE a.UserID = @UserId AND a.OrganizationID = @OrgId AND a.IsActive = 1",
                new { UserId = userId, OrgId = organizationId });
            
            if (!string.IsNullOrEmpty(accessRole))
            {
                effectiveRole = accessRole;
            }
        }

        // Re-issue a token with the new OrganizationId and the CORRECT Role for that Org
        user.OrganizationId = organizationId;
        user.OrganizationLogo = await conn.ExecuteScalarAsync<string>("SELECT logo_url FROM organizations WHERE id = @Id", new { Id = organizationId });
        var (token, tokenExpiry) = GenerateJwtToken(user, effectiveRole); // Pass effectiveRole
        
        // Update session with new token expiry
        try
        {
            await conn.ExecuteAsync("sp_UpsertUserLoginSession",
                new
                {
                    UserId = userId,
                    OrganizationId = organizationId,
                    UserName = user.Name,
                    TokenExpiryAt = tokenExpiry
                },
                commandType: CommandType.StoredProcedure);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Auth] Failed to update login session on org switch | UserId={UserId}", userId);
        }

        _logger.LogInformation("[Auth] Switch organization SUCCESS | UserId={UserId} | TargetOrgId={OrgId} | EffectiveRole={Role}", userId, organizationId, effectiveRole);
        return Ok(new { token });
    }

    [Authorize]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout()
    {
        var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (!int.TryParse(userIdStr, out int userId)) return Unauthorized();

        _logger.LogInformation("[Auth] Logout attempt | UserId={UserId}", userId);

        using var conn = _db.CreateConnection();
        try
        {
            await conn.ExecuteAsync("sp_LogoutUserSession",
                new { UserId = userId },
                commandType: CommandType.StoredProcedure);
            _logger.LogInformation("[Auth] Logout SUCCESS | UserId={UserId}", userId);
            return Ok(new { message = "Logged out successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Auth] Logout FAILED | UserId={UserId}", userId);
            return StatusCode(500, new { message = "Logout failed" });
        }
    }

    private (string token, DateTime expiryTime) GenerateJwtToken(User user, string? effectiveRole = null)
    {
        var roleToUse = effectiveRole ?? user.Role ?? "User";
        var jwtSettings = _config.GetSection("Jwt");
        var jwtKey    = jwtSettings["Key"]        ?? throw new InvalidOperationException("'Jwt:Key' is missing in configuration.");
        var jwtIssuer  = jwtSettings["Issuer"]     ?? throw new InvalidOperationException("'Jwt:Issuer' is missing in configuration.");
        var jwtAudnce  = jwtSettings["Audience"]   ?? throw new InvalidOperationException("'Jwt:Audience' is missing in configuration.");
        var jwtExpiry  = jwtSettings["ExpiryInMinutes"] ?? throw new InvalidOperationException("'Jwt:ExpiryInMinutes' is missing in configuration.");
        var key = Encoding.ASCII.GetBytes(jwtKey);
        var tokenHandler = new JwtSecurityTokenHandler();
        var expiryTime = DateTime.UtcNow.AddMinutes(double.Parse(jwtExpiry));
        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new Claim(ClaimTypes.Name, user.Name ?? ""),
                new Claim(ClaimTypes.Email, user.Email),
                new Claim(ClaimTypes.Role, roleToUse),
                new Claim("OrganizationId", user.OrganizationId?.ToString() ?? ""),
                new Claim("OrganizationLogo", user.OrganizationLogo ?? "")
            }),
            Expires = expiryTime,
            Issuer = jwtIssuer,
            Audience = jwtAudnce,
            SigningCredentials = new SigningCredentials(new SymmetricSecurityKey(key), SecurityAlgorithms.HmacSha256Signature)
        };

        var token = tokenHandler.CreateToken(tokenDescriptor);
        return (tokenHandler.WriteToken(token), expiryTime);
    }
}
