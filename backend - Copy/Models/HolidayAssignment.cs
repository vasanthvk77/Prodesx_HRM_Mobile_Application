namespace backend.Models
{
    public class HolidayAssignment
    {
        public int Id { get; set; }
        public int HolidayId { get; set; }
        public string TargetType { get; set; } = string.Empty; // "Department", "Designation", "Employee"
        public int TargetId { get; set; }
        public int OrganizationId { get; set; }
        public DateTime CreatedAt { get; set; }
        public int? CreatedBy { get; set; }
    }

    public class HolidayWithAssignments : Holiday
    {
        public List<HolidayAssignment> Assignments { get; set; } = new List<HolidayAssignment>();
    }
}
