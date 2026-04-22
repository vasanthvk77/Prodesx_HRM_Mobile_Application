using System;

namespace backend.Models;

public class Allowances
{
    public int AllowencesId { get; set; }
    public int OrganizationID { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string ShortName { get; set; } = string.Empty;
}

public class StaffAllowance
{
    public int StaffAllowanceId { get; set; }
    public int AllowenceId { get; set; }
    public int EmployeeID { get; set; }
    public bool CalType { get; set; } // 0 for Percentage, 1 for Fixed
    public decimal Amount { get; set; }
    public int CreatedBy { get; set; }
    public DateTime CreatedDate { get; set; }
    
    // Navigation/Joined properties
    public string? AllowanceName { get; set; }
    public string? AllowanceShortName { get; set; }
}
