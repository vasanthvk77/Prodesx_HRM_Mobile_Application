using System;

namespace backend.Models
{
    public class ShiftTemplate
    {
        public int Id { get; set; }
        public int OrganizationId { get; set; }
        public string ShiftName { get; set; } = string.Empty;
        public string ShiftType { get; set; } = string.Empty;
        public string StartTime { get; set; } = string.Empty;
        public string EndTime { get; set; } = string.Empty;
        public int UnpaidBreak { get; set; }
        public string TotalShiftHours { get; set; } = string.Empty;
        public string? EarliestPunchIn { get; set; }
        public string? LatestPunchOut { get; set; }
        public int LateGracePeriod { get; set; }
        public int EarlyGracePeriod { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
    }

    public class ShiftAssignment
    {
        public int Id { get; set; }
        public int OrganizationId { get; set; }
        public int EmployeeId { get; set; }
        public int? TemplateId { get; set; }

        // Timing details (can be custom or copied from template)
        public string? ShiftName { get; set; }
        public string? ShiftType { get; set; }
        public string StartTime { get; set; } = string.Empty;
        public string EndTime { get; set; } = string.Empty;
        public int UnpaidBreak { get; set; }
        public string TotalShiftHours { get; set; } = string.Empty;
        public string? EarliestPunchIn { get; set; }
        public string? LatestPunchOut { get; set; }
        public int LateGracePeriod { get; set; }
        public int EarlyGracePeriod { get; set; }

        public string? WorkDays { get; set; }
        public DateTime? StartDate { get; set; }
        public DateTime? EndDate { get; set; }
        public int AssignmentType { get; set; } = 3;
        public string? SpecificDates { get; set; }
        public string? Remarks { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }

        // Optional: Join fields for UI
        public string? EmployeeName { get; set; }
        public string? EmployeeCode { get; set; }
    }

    public class EmployeeSchedule
    {
        public int Id { get; set; }
        public int OrganizationId { get; set; }
        public int EmployeeId { get; set; }
        public DateTime Date { get; set; }

        public string? ShiftName { get; set; }
        public string? ShiftType { get; set; }
        public string StartTime { get; set; } = string.Empty;
        public string EndTime { get; set; } = string.Empty;
        public int UnpaidBreak { get; set; }
        public string TotalShiftHours { get; set; } = string.Empty;
        public string? EarliestPunchIn { get; set; }
        public string? LatestPunchOut { get; set; }
        public int LateGracePeriod { get; set; }
        public int EarlyGracePeriod { get; set; }

        public bool IsOverride { get; set; }
        public int? SourceAssignmentId { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }

        // Join fields
        public string? EmployeeName { get; set; }
        public string? EmployeeCode { get; set; }
    }
}
