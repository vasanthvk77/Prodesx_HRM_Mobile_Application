using System;

namespace backend.Models
{
    public class EmployeeHolidayStatus
    {
        public int Id { get; set; }
        public int OrganizationId { get; set; }
        public int EmployeeId { get; set; }
        public int HolidayId { get; set; }
        public string Status { get; set; } = "H"; // 'H', 'W/D', 'W/H', 'N/E'
        public string? Remarks { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
        public int? CreatedBy { get; set; }
        public int? LastUpdatedBy { get; set; }
    }

    public class BulkHolidayStatusUpdate
    {
        public List<int> EmployeeIds { get; set; } = new List<int>();
        public int HolidayId { get; set; }
        public string Status { get; set; } = "H";
        public string? Remarks { get; set; }
    }
}
