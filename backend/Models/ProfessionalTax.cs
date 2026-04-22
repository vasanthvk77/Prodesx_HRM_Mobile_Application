using System;

namespace backend.Models;

public class ProfessionalTax
{
    public int PTId { get; set; }
    public string TaxName { get; set; } = string.Empty;
    public decimal FromAmount { get; set; }
    public decimal ToAmount { get; set; }
    public decimal TaxAmount { get; set; }
    public int OrganizationId { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedDateTime { get; set; }
    public int? CreatedBy { get; set; }
}
