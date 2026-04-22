using System;

namespace backend.Models;

public class SalarySettings
{
    public int SSId { get; set; }
    public int OrganizationId { get; set; }
    public int SalaryYearId { get; set; }
    public int EmployeeId { get; set; }
    public decimal BasicPay { get; set; }
    public int CreatedBy { get; set; }
    public DateTime CreatedDateTime { get; set; }
    public int? UpdatedBy { get; set; }
    public DateTime? UpdatedDateTime { get; set; }

    // Joined fields from employees table (populated by sp_GetSalarySettings)
    public string? EmployeeName { get; set; }
    public string? EmployeeCode { get; set; }
}

public class UpsertSalarySettingsRequest
{
    // Use strings for automatic HashID decoding by the Model Binder
    public string? SSId { get; set; } 
    public string SalaryYearId { get; set; } = string.Empty;
    public string EmployeeId { get; set; } = string.Empty;
    public decimal BasicPay { get; set; }
}
