using System;

namespace backend.Models
{
    public class DangerousOccurrence
    {
        public int? Id { get; set; }
        public int OrgId { get; set; }
        public int CalendarYear { get; set; }
        public int DangerousOccurrenceSerialNo { get; set; }
        public DateTime? OccurrenceDatetime { get; set; }
        public DateTime? Form18aDespatchDate { get; set; }
        public string? DangerousOccurrencePlace { get; set; }
        public string? OccurrenceDescriptionActionTaken { get; set; }
        public string? DamageDetailsDamageLossRepairReplacementCost { get; set; }
        public string? ManagerRemarksAndInitials { get; set; }
        public int? CreatedBy { get; set; }
        public DateTime? CreatedAt { get; set; }
        public int? LastUpdatedBy { get; set; }
        public DateTime? UpdatedAt { get; set; }
    }
}
