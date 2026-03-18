namespace backend.Models
{
    public class Holiday
    {
        public int HolidayID { get; set; }
        public int OrganizationID { get; set; }
        public string HolidayName { get; set; } = string.Empty;
        public DateTime? HolidayDate { get; set; }
        public string AssignmentType { get; set; } = "All"; // "All", "Custom"
        public bool January { get; set; }
        public bool February { get; set; }
        public bool March { get; set; }
        public bool April { get; set; }
        public bool May { get; set; }
        public bool June { get; set; }
        public bool July { get; set; }
        public bool August { get; set; }
        public bool September { get; set; }
        public bool October { get; set; }
        public bool November { get; set; }
        public bool December { get; set; }
        public DateTime CreatedDate { get; set; }
        public int? CreatedBy { get; set; }
        public int? LastUpdatedBy { get; set; }
    }
}
