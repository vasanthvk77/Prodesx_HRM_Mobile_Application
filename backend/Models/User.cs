namespace backend.Models;

public class User
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string Role { get; set; } = "User";
    public int? OrganizationId { get; set; }
    public string? OrganizationLogo { get; set; }
}

public class LoginRequest 
{ 
    public string Email { get; set; } = ""; 
    public string Password { get; set; } = ""; 
}
