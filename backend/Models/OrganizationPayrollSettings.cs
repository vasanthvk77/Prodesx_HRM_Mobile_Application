using System;

namespace backend.Models;

public class OrganizationPayrollSettings
{
    public int OrganizationId { get; set; }
    public bool IsPFActive { get; set; }
    public bool IsESIActive { get; set; }
    public decimal PFPercentage { get; set; } = 12.00m;
    public decimal PFCapAmount { get; set; } = 15000.00m;
    public decimal ESIPercentage { get; set; } = 0.75m;
}

public class UpsertPayrollSettingsRequest
{
    public bool IsPFActive { get; set; }
    public bool IsESIActive { get; set; }
    public decimal? PFPercentage { get; set; }
    public decimal? PFCapAmount { get; set; }
    public decimal? ESIPercentage { get; set; }
}
