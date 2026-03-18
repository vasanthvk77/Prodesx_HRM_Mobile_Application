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
public class UsersController : ControllerBase
{
    private readonly DataBaseConnection _db;
    private readonly IHubContext<UserManagementHub> _hubContext;
    private readonly ILogger<UsersController> _logger;

    public UsersController(DataBaseConnection db, ILogger<UsersController> logger, IHubContext<UserManagementHub> hubContext)
    {
        _db = db;
        _logger = logger;
        _hubContext = hubContext;
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

    // GET /api/users — list all users with org access
    // SuperAdmin → all orgs | Admin → all orgs they have active access to
    [HttpGet]
    public async Task<IActionResult> GetUsers()
    {
        var role     = User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value;
        var callerId = GetUserId();
        _logger.LogInformation("[Users] GET all | Role={Role} | CallerId={Id}", role, callerId);

        try
        {
            using var conn = _db.CreateConnection();

            if (role == "SuperAdmin")
            {
                // SuperAdmin sees every user across every org
                var allUsers = await conn.QueryAsync<UserOrganizationAccess>(
                    "sp_GetAllUsersWithAccess",
                    new { OrganizationID = (int?)null },
                    commandType: CommandType.StoredProcedure);
                return Ok(allUsers);
            }
            else
            {
                // Admin: first get every org they have active access to
                var myOrgs = await conn.QueryAsync(
                    "sp_GetUserOrganizations",
                    new { UserID = callerId },
                    commandType: CommandType.StoredProcedure);

                // Then fetch users for each org and union the results
                var combined = new List<UserOrganizationAccess>();
                foreach (var org in myOrgs)
                {
                    var orgUsers = await conn.QueryAsync<UserOrganizationAccess>(
                        "sp_GetAllUsersWithAccess",
                        new { OrganizationID = (int)org.OrganizationID },
                        commandType: CommandType.StoredProcedure);
                    combined.AddRange(orgUsers);
                }
                return Ok(combined);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Users] GET all failed | CallerId={Id}", callerId);
            return StatusCode(500, "Failed to fetch users");
        }
    }


    // GET /api/users/roles — list all roles
    [HttpGet("roles")]
    public async Task<IActionResult> GetRoles()
    {
        try
        {
            using var conn = _db.CreateConnection();
            var roles = await conn.QueryAsync<Role>("sp_GetAllRoles", commandType: CommandType.StoredProcedure);
            return Ok(roles);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Users] GET roles failed");
            return StatusCode(500, "Failed to fetch roles");
        }
    }

    // GET /api/users/organizations — list organizations scoped to the caller's access
    [HttpGet("organizations")]
    public async Task<IActionResult> GetOrganizations()
    {
        var callerRole = User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value;
        var callerId   = GetUserId();
        _logger.LogInformation("[Users] GET organizations | Role={Role} | UserId={Id}", callerRole, callerId);
        try
        {
            using var conn = _db.CreateConnection();

            if (callerRole == "SuperAdmin")
            {
                // SuperAdmin sees every org
                var allOrgs = await conn.QueryAsync<Organization>("sp_GetAllOrganizations", commandType: CommandType.StoredProcedure);
                return Ok(allOrgs);
            }
            else
            {
                // Admin/User sees only orgs they have active access to.
                // sp_GetUserOrganizations returns OrganizationID/OrganizationName columns,
                // so we project them into the Organization model manually.
                var rows = await conn.QueryAsync(
                    "sp_GetUserOrganizations",
                    new { UserID = callerId },
                    commandType: CommandType.StoredProcedure);
                var myOrgs = rows.Select(r => new Organization
                {
                    Id   = (int)r.OrganizationID,
                    Name = (string)r.OrganizationName,
                    Email = (string?)r.OrganizationEmail,
                    LogoUrl = (string?)r.LogoUrl
                });
                return Ok(myOrgs);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Users] GET organizations failed");
            return StatusCode(500, "Failed to fetch organizations");
        }
    }


    // Removed Redundant Organization Creation method (Now in OrganizationsController)


    // POST /api/users — create a new user and grant them org access
    [HttpPost]
    public async Task<IActionResult> CreateUser([FromBody] CreateUserRequest request)
    {
        var callerRole  = User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value;
        var grantedByID = GetUserId();
        _logger.LogInformation("[Users] CREATE requested | CallerRole={CallerRole} | Email={Email} | Role={Role} | OrgId={OrgId}",
            callerRole, request.Email, request.RoleName, request.OrganizationId);
        try
        {
            using var conn = _db.CreateConnection();

            // Admins can only create User-role accounts, not Admin or SuperAdmin
            if (callerRole == "Admin" && (request.RoleName == "Admin" || request.RoleName == "SuperAdmin"))
            {
                _logger.LogWarning("[Users] CREATE blocked — Admin tried to create {Role} account", request.RoleName);
                return StatusCode(403, new { message = "Admins can only create User-role accounts." });
            }

            // SuperAdmin-role accounts can only be created by SuperAdmins
            if (request.RoleName == "SuperAdmin" && callerRole != "SuperAdmin")
                return StatusCode(403, new { message = "Only SuperAdmins can create SuperAdmin accounts." });

            // Check if email already exists
            var exists = await conn.ExecuteScalarAsync<int>(
                "sp_CheckUserEmailExists", new { request.Email }, commandType: CommandType.StoredProcedure);
            if (exists > 0)
            {
                _logger.LogWarning("[Users] CREATE failed — email already exists | Email={Email}", request.Email);
                return Conflict(new { message = "A user with this email already exists." });
            }

            // Hash the password
            string hash = BCrypt.Net.BCrypt.HashPassword(request.Password);

            // Insert user via SP
            var newUserId = await conn.ExecuteScalarAsync<int>("sp_CreateUser",
                new { Name = request.Name, Email = request.Email, Hash = hash, Role = request.RoleName, OrgId = request.OrganizationId, CreatedBy = grantedByID },
                commandType: CommandType.StoredProcedure);

            // Resolve RoleID from Roles table
            var roleId = await conn.ExecuteScalarAsync<int>(
                "sp_GetRoleIdByName", new { request.RoleName }, commandType: CommandType.StoredProcedure);

            // Grant org access
            await conn.ExecuteAsync("sp_GrantOrgAccess",
                new { UserID = newUserId, OrganizationID = request.OrganizationId, RoleID = roleId, GrantedByID = grantedByID },
                commandType: CommandType.StoredProcedure);
            await _hubContext.Clients.All.SendAsync("UserManagementUpdate", new { Action = $"New User Created {request.Name}"});

            _logger.LogInformation("[Users] CREATE success | UserId={UserId} | Email={Email}", newUserId, request.Email);
            return Ok(new { message = "User created successfully", userId = newUserId });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Users] CREATE failed | Email={Email}", request.Email);
            return StatusCode(500, "Failed to create user");
        }
    }

    // PUT /api/users/{userId}/access — grant or update a user's org access
    [HttpPut("{userId}/access")]
    public async Task<IActionResult> GrantAccess(int userId, [FromBody] GrantAccessRequest request)
    {
        var callerRole = User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value;
        var grantedBy  = GetUserId();

        _logger.LogInformation("[Users] GRANT ACCESS | CallerRole={CallerRole} | TargetUserId={UserId} | OrgId={OrgId} | RoleId={RoleId}",
            callerRole, userId, request.OrganizationId, request.RoleId);
        try
        {
            using var conn = _db.CreateConnection();

            // Determine what role the target user currently has
            var targetUser = await conn.QueryFirstOrDefaultAsync<User>(
                "sp_GetUserById", new { Id = userId }, commandType: CommandType.StoredProcedure);
 
            if (targetUser == null)
                return NotFound(new { message = "User not found." });
 
            var targetRole = targetUser.Role;

            // Determine the role name corresponding to the requested RoleId
            var requestedRoleName = await conn.ExecuteScalarAsync<string>(
                "SELECT RoleName FROM Roles WHERE RoleID = @RoleId",
                new { request.RoleId });

            if (string.IsNullOrEmpty(requestedRoleName))
                return BadRequest(new { message = "Invalid role selected." });

            // Admin cannot modify SuperAdmin or other Admin accounts
            if (callerRole == "Admin" && (targetRole == "SuperAdmin" || targetRole == "Admin"))
                return StatusCode(403, new { message = "Admins cannot modify SuperAdmin or other Admin accounts." });

            // Additionally, Admins are not allowed to assign Admin or SuperAdmin roles to anyone
            if (callerRole == "Admin" && (requestedRoleName == "SuperAdmin" || requestedRoleName == "Admin"))
                return StatusCode(403, new { message = "Admins can only assign User-level access." });

            await conn.ExecuteAsync("sp_GrantOrgAccess",
                new { UserID = userId, OrganizationID = request.OrganizationId, RoleID = request.RoleId, GrantedByID = grantedBy },
                commandType: CommandType.StoredProcedure);
            await _hubContext.Clients.All.SendAsync("UserManagementUpdate", new { Action = $"User Access Granted (ID: {userId})"});

            _logger.LogInformation("[Users] GRANT ACCESS success | UserId={UserId}", userId);
            return Ok(new { message = "Access granted successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Users] GRANT ACCESS failed | UserId={UserId}", userId);
            return StatusCode(500, "Failed to grant access");
        }
    }

    // DELETE /api/users/{userId}/access/{orgId} — revoke access
    [HttpDelete("{userId}/access/{orgId}")]
    public async Task<IActionResult> RevokeAccess(int userId, int orgId)
    {
        var callerRole = User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value;
        _logger.LogInformation("[Users] REVOKE ACCESS | CallerRole={CallerRole} | UserId={UserId} | OrgId={OrgId}", callerRole, userId, orgId);
        try
        {
            using var conn = _db.CreateConnection();

            var targetUser = await conn.QueryFirstOrDefaultAsync<User>(
                "sp_GetUserById", new { Id = userId }, commandType: CommandType.StoredProcedure);

            if (targetUser == null)
                return NotFound(new { message = "User not found." });

            var targetRole = targetUser.Role;

            // Admin cannot revoke access for SuperAdmin or other Admins
            if (callerRole == "Admin" && (targetRole == "SuperAdmin" || targetRole == "Admin"))
                return StatusCode(403, new { message = "Admins cannot revoke access for SuperAdmin or other Admin accounts." });

            await conn.ExecuteAsync("sp_RevokeOrgAccess",
                new { UserID = userId, OrganizationID = orgId },
                commandType: CommandType.StoredProcedure);
            await _hubContext.Clients.All.SendAsync("UserManagementUpdate", new { Action = $"User Access Revoked (ID: {userId})"});

            _logger.LogInformation("[Users] REVOKE ACCESS success | UserId={UserId} | OrgId={OrgId}", userId, orgId);
            return Ok(new { message = "Access revoked successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Users] REVOKE ACCESS failed | UserId={UserId}", userId);
            return StatusCode(500, "Failed to revoke access");
        }
    }

    // DELETE /api/users/{userId} — permanently delete a user account
    [HttpDelete("{userId}")]
    public async Task<IActionResult> DeleteUser(int userId)
    {
        var callerRole = User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value;
        _logger.LogInformation("[Users] DELETE requested | CallerRole={CallerRole} | UserId={UserId}", callerRole, userId);
        try
        {
            using var conn = _db.CreateConnection();

            // Cannot delete yourself
            if (userId == GetUserId())
                return BadRequest(new { message = "You cannot delete your own account." });

            var targetUser = await conn.QueryFirstOrDefaultAsync<User>(
                "sp_GetUserById", new { Id = userId }, commandType: CommandType.StoredProcedure);

            if (targetUser == null)
                return NotFound(new { message = "User not found." });

            var targetRole = targetUser.Role;

            // Admin cannot delete SuperAdmin or other Admin accounts
            if (callerRole == "Admin" && (targetRole == "SuperAdmin" || targetRole == "Admin"))
                return StatusCode(403, new { message = "Admins cannot delete SuperAdmin or other Admin accounts." });

            var rows = await conn.ExecuteAsync(
                "sp_DeleteUser", new { Id = userId }, commandType: CommandType.StoredProcedure);

            if (rows == 0)
                return NotFound(new { message = "User not found." });
            await _hubContext.Clients.All.SendAsync("UserManagementUpdate", new { Action = $"User Deleted (ID: {userId})"});
            _logger.LogInformation("[Users] DELETE success | UserId={UserId}", userId);
            return Ok(new { message = "User deleted successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Users] DELETE failed | UserId={UserId}", userId);
            return StatusCode(500, "Failed to delete user");
        }
    }

    // GET /api/users/login-sessions — get all active user login sessions
    [HttpGet("login-sessions")]
    public async Task<IActionResult> GetLoginSessions()
    {
        var orgId = GetOrgId();
        var callerId = GetUserId();
        var callerRole = User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value;

        _logger.LogInformation("[Users] GET login sessions | OrgId={OrgId} | CallerId={Id} | Role={Role}", orgId, callerId, callerRole);

        try
        {
            using var conn = _db.CreateConnection();

            // Only Admin and SuperAdmin can view login sessions
            if (callerRole != "Admin" && callerRole != "SuperAdmin")
                return StatusCode(403, new { message = "Only Admin and SuperAdmin can view login sessions." });

            var sessions = await conn.QueryAsync<dynamic>(
                "sp_GetUserLoginSessions",
                new { OrganizationId = (object?)(callerRole == "SuperAdmin" ? null : orgId) },
                commandType: CommandType.StoredProcedure);

            _logger.LogInformation("[Users] GET login sessions success | Count={Count}", sessions.Count());
            return Ok(sessions);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Users] GET login sessions failed");
            return StatusCode(500, "Failed to retrieve login sessions");
        }
    }

    // POST /api/users/check-expired-sessions — mark expired sessions as inactive
    [HttpPost("check-expired-sessions")]
    public async Task<IActionResult> CheckExpiredSessions()
    {
        var callerId = GetUserId();
        var callerRole = User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value;

        _logger.LogInformation("[Users] CHECK expired sessions | CallerId={Id} | Role={Role}", callerId, callerRole);

        try
        {
            // Only Admin and SuperAdmin can trigger this
            if (callerRole != "Admin" && callerRole != "SuperAdmin")
                return StatusCode(403, new { message = "Only Admin and SuperAdmin can check expired sessions." });

            using var conn = _db.CreateConnection();

            var result = await conn.QueryFirstOrDefaultAsync<dynamic>(
                "sp_CheckAndUpdateExpiredSessions",
                commandType: CommandType.StoredProcedure);

            int expiredCount = 0;
            if (result != null)
            {
                expiredCount = (int)result.ExpiredSessionsMarked;
            }
            
            _logger.LogInformation("[Users] CHECK expired sessions success | ExpiredCount={Count}", expiredCount);
            return Ok(new { message = $"{expiredCount} expired sessions marked as inactive" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[Users] CHECK expired sessions failed");
            return StatusCode(500, "Failed to check expired sessions");
        }
    }
}

// ── Request DTOs ─────────────────────────────────────────────────────────────

public class CreateUserRequest
{
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string RoleName { get; set; } = "User";
    public int OrganizationId { get; set; }
}

public class GrantAccessRequest
{
    public int OrganizationId { get; set; }
    public int RoleId { get; set; }
}

public class CreateOrganizationRequest
{
    public string Name { get; set; } = string.Empty;
    public string? Email { get; set; }
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public IFormFile? Logo { get; set; }
}
