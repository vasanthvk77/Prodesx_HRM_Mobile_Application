using System;

namespace backend.Models;

public class OrganizationCalendarSettings
{
    public int Id { get; set; }
    public int OrganizationId { get; set; }

    public int? AcademicStartMonth { get; set; }
    public int? AcademicStartDay { get; set; }
    public int? AcademicEndMonth { get; set; }
    public int? AcademicEndDay { get; set; }

    public int? SalaryStartDay { get; set; }
    public int? SalaryEndDay { get; set; }

    public int? CreatedById { get; set; }
    public string? CreatedByName { get; set; }
    public DateTime? CreatedAt { get; set; }

    public int? UpdatedById { get; set; }
    public string? UpdatedByName { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

public class UpsertCalendarSettingsRequest
{
    public int OrganizationId { get; set; }
    public int AcademicStartMonth { get; set; }
    public int AcademicStartDay { get; set; }
    public int AcademicEndMonth { get; set; }
    public int AcademicEndDay { get; set; }
    public int SalaryStartDay { get; set; }
    public int SalaryEndDay { get; set; }
}
