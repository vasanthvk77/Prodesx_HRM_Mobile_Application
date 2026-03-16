namespace backend.Models;

public class MustorRollRecord
{
    public int Id { get; set; }
    public int OrganizationId { get; set; }
    public int EmployeeId { get; set; }

    // Convenience fields from join
    public string? EmployeeName { get; set; }
    public string? EmployeeCode { get; set; }

    public string WomanName { get; set; } = string.Empty;
    public int? Age { get; set; }
    public string? HusbandOrFatherName { get; set; }
    public string? NatureOfWork { get; set; }
    public DateTime? DateOfEmployment { get; set; }

    public string? AttendanceJson { get; set; }

    public DateTime? NoticePregnancyDate { get; set; }
    public DateTime? NoticeDeliveryDate { get; set; }
    public DateTime? ProofBirthDate { get; set; }
    public DateTime? ProofDeathDate { get; set; }

    public decimal? AdvanceAmount { get; set; }
    public DateTime? AdvanceDate { get; set; }
    public decimal? SubsequentAmount { get; set; }
    public DateTime? SubsequentDate { get; set; }
    public decimal? BonusAmount { get; set; }
    public decimal? LeaveWagesSec9 { get; set; }
    public decimal? LeaveWagesSec10 { get; set; }
    public string? Remarks { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class MustorAttendanceRow
{
    public string? MonthYear { get; set; }
    public int? DaysEmployed { get; set; }
    public int? DaysLaidOff { get; set; }
    public int? DaysNotEmployed { get; set; }
}

public class UpsertMustorRollRequest
{
    public int? OrganizationId { get; set; }
    public int EmployeeId { get; set; }

    public string WomanName { get; set; } = string.Empty;
    public int? Age { get; set; }
    public string? HusbandOrFatherName { get; set; }
    public string? NatureOfWork { get; set; }
    public string? DateOfEmployment { get; set; }

    public List<MustorAttendanceRow>? AttendanceRows { get; set; }

    public string? NoticePregnancyDate { get; set; }
    public string? NoticeDeliveryDate { get; set; }
    public string? ProofBirthDate { get; set; }
    public string? ProofDeathDate { get; set; }

    public decimal? AdvanceAmount { get; set; }
    public string? AdvanceDate { get; set; }
    public decimal? SubsequentAmount { get; set; }
    public string? SubsequentDate { get; set; }
    public decimal? BonusAmount { get; set; }
    public decimal? LeaveWagesSec9 { get; set; }
    public decimal? LeaveWagesSec10 { get; set; }
    public string? Remarks { get; set; }
}

