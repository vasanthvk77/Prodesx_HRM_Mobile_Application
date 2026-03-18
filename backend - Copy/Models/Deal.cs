using System;

namespace backend.Models
{
    public class Deal
    {
        public int? DealId { get; set; }
        public int OrganizationId { get; set; }
        public string LeadContactName { get; set; } = string.Empty;
        public string? LeadEmail { get; set; }
        public string? LeadPhone { get; set; }
        public string DealName { get; set; } = string.Empty;
        public string Pipeline { get; set; } = string.Empty;
        public string DealStage { get; set; } = string.Empty;
        public decimal DealValue { get; set; }
        public DateTime CloseDate { get; set; }
        public string? DealCategory { get; set; }
        public string? Products { get; set; }
        public string? DealAgent { get; set; }
        public string? DealWatcher { get; set; }
        public DateTime? CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
        public int? CreatedBy { get; set; }
        public int? LastUpdatedBy { get; set; }
    }
}
