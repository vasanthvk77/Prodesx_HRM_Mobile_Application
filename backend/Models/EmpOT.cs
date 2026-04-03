using System;

namespace backend.Models;

public class EmpOT
{
    public int OverDutyId { get; set; }
    public int OrganizationId { get; set; }
    public int EmployeeId { get; set; }
    public DateTime OverDutyDate { get; set; }
    public decimal Hours { get; set; }
    public decimal? RatePerHour { get; set; }
    public decimal Amount { get; set; }
    public string? Remarks { get; set; }
    public DateTime CreatedDateTime { get; set; }
    public int? CreatedBy { get; set; }
}
