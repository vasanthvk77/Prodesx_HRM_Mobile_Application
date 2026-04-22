using System;

namespace backend.Models;

public class Deductions
{
    public int DeductionsId { get; set; }
    public int OrganizationID { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string ShortName { get; set; } = string.Empty;
}

public class StaffDeduction
{
    public int StaffDeductionId { get; set; }
    public int DeductionId { get; set; }
    public int EmployeeID { get; set; }
    public bool CalType { get; set; } // 0 for Percentage, 1 for Fixed
    public decimal Amount { get; set; }
    public int CreatedBy { get; set; }
    public DateTime CreatedDate { get; set; }
    
    // Navigation/Joined properties
    public string? DeductionName { get; set; }
    public string? DeductionShortName { get; set; }
    public string? EmployeeName { get; set; }
    public string? EmployeeCode { get; set; }
    public string? ProfilePictureUrl { get; set; }
}
