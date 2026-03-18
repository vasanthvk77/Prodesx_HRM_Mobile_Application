namespace backend.Models;

public class Lead
{
    public int Id { get; set; }
    public int OrganizationId { get; set; }
    public string? Salutation { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Email { get; set; }
    public string? LeadSource { get; set; }
    public string? AddedBy { get; set; }
    public string? LeadOwner { get; set; }
    public bool CreateDeal { get; set; }
    public bool AutoConvert { get; set; }
    public string? DealName { get; set; }
    public string? Pipeline { get; set; }
    public string? DealStages { get; set; }
    public decimal? DealValue { get; set; }
    public DateTime? CloseDate { get; set; }
    public string? DealCategory { get; set; }
    public string? DealAgent { get; set; }
    public string? Products { get; set; }
    public string? DealWatcher { get; set; }
    public string? Company { get; set; }
    public string? Website { get; set; }
    public string? Address { get; set; }
    public string? City { get; set; }
    public string? State { get; set; }
    public string? Country { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.Now;
    public DateTime UpdatedAt { get; set; } = DateTime.Now;
    public int? CreatedBy { get; set; }
    public int? LastUpdatedBy { get; set; }
}
