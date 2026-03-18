using System;

namespace backend.Models;

public class LeaveType
{
    public int Id { get; set; }
    public int OrganizationId { get; set; }
    public string TypeName { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string ShortName { get; set; } = string.Empty;
    public bool IsVisible { get; set; } = true;
    public bool IsMobileView { get; set; } = true;
    public bool IsPaid { get; set; } = true;
    public string? ColorCode { get; set; }
}

public class DailyAttendance
{
    public int Id { get; set; }
    public int EmployeeId { get; set; }
    public int OrganizationId { get; set; }
    public DateTime Date { get; set; }
    public DateTime? PunchIn { get; set; }
    public DateTime? PunchOut { get; set; }
    public int? AttendanceTypeId { get; set; }
    public string? CalculatedStatus { get; set; }
    public bool IsProcessed { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation/Extended properties
    public string? EmployeeName { get; set; }
    public string? EmployeeCode { get; set; }
    public string? LeaveTypeName { get; set; }
    public string? ShortName { get; set; }
}

public class AttendanceStatusResponse
{
    public bool IsScheduled { get; set; }
    public bool IsHoliday { get; set; }
    public string Status { get; set; } = "NoShift";
    public string? ShiftName { get; set; }
    public string? ShiftTimings { get; set; }
    public DateTime? PunchInTime { get; set; }
    public DateTime? PunchOutTime { get; set; }
}
