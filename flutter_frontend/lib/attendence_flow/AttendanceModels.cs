using System;

namespace backend.Models;

// Leave Management Models
public class LeaveType
{
    public byte LeaveTypeId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string ShortName { get; set; } = string.Empty;
    public bool IsShow { get; set; } = true;
    public bool IsPaid { get; set; } = true;
}

public class LeaveTypeUpsertRequest
{
    public byte? LeaveTypeId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string ShortName { get; set; } = string.Empty;
    public int OrganizationId { get; set; } // Required to link the type to an org
    public bool IsPaid { get; set; } = true;
}

public class ToggleLeaveTypeRequest
{
    public byte LeaveTypeId { get; set; }
    public int OrganizationId { get; set; }
    public bool IsShow { get; set; }
}




public class DailyAttendance
{
    public int Id { get; set; }
    public int EmployeeId { get; set; }
    public int OrganizationId { get; set; }
    public DateTime Date { get; set; }
    public DateTime? PunchIn { get; set; }
    public DateTime? PunchOut { get; set; }
    public string? CalculatedStatus { get; set; }
    public bool IsProcessed { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation/Extended properties
    public string? EmployeeName { get; set; }
    public string? EmployeeCode { get; set; }
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

public class QRPunchRequest
{
    public string QRToken { get; set; } = string.Empty;
    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }
}
