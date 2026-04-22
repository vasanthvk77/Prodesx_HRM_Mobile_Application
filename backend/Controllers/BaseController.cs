using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public abstract class BaseController<T> : ControllerBase 
{
    protected readonly ILogger<T> _logger;

    protected BaseController(ILogger<T> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// Gets the OrganizationId from the JWT claim.
    /// This is the MOST efficient and secure way since it cannot be spoofed in the URL.
    /// </summary>
    protected int CurrentOrgId
    {
        get
        {
            var claim = User.FindFirst("OrganizationId")?.Value;
            return int.TryParse(claim, out var id) ? id : 0;
        }
    }

    protected int CurrentUserId
    {
        get
        {
            var claim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            return int.TryParse(claim, out var id) ? id : 0;
        }
    }

    protected string UserRole
    {
        get
        {
            return User.FindFirst(ClaimTypes.Role)?.Value ?? "User";
        }
    }

    protected string UserEmail
    {
        get
        {
            return User.FindFirst(ClaimTypes.Email)?.Value ?? "";
        }
    }

    protected bool IsSuperAdmin => UserRole == "SuperAdmin";
}
