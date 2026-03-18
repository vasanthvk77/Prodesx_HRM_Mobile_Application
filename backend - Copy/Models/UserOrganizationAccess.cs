namespace backend.Models;

public class UserOrganizationAccess
{
    public int AccessID { get; set; }
    public int UserID { get; set; }
    public int OrganizationID { get; set; }
    public int RoleID { get; set; }
    public int? GrantedByID { get; set; }
    public DateTime GrantedDate { get; set; } = DateTime.Now;
    public DateTime CreatedAt { get; set; } = DateTime.Now;
    public DateTime UpdatedAt { get; set; } = DateTime.Now;
    public bool IsActive { get; set; } = true;

    // Joined/read-only display fields (from vw_UserAccess / sp_GetUserOrganizations)
    public string? UserName { get; set; }
    public string? Email { get; set; }
    public string? OrganizationName { get; set; }
    public string? OrganizationEmail { get; set; }
    public string? Role { get; set; }
    public string? GrantedByName { get; set; }
    public string? OrganizationLogo { get; set; }
}
