using System;

namespace backend.Models;

public class SalaryYear
{
    public int SalaryYearId { get; set; }
    public int OrganizationID { get; set; }
    public string FromYear { get; set; } = string.Empty;
    public string ToYear { get; set; } = string.Empty;
    public DateTime DateFrom { get; set; }
    public DateTime DateTo { get; set; }
    public int CreatedBy { get; set; }
    public DateTime CreatedDate { get; set; }
}

public class UpsertSalaryYearRequest
{
    public string? SalaryYearId { get; set; } // Using string for HashID decoding
    public string FromYear { get; set; } = string.Empty;
    public string ToYear { get; set; } = string.Empty;
    public DateTime DateFrom { get; set; }
    public DateTime DateTo { get; set; }
}
