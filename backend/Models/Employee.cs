namespace backend.Models;

public class Employee
{
    public int Id { get; set; }
    public int? UserId { get; set; }
    public int OrganizationId { get; set; }
    public string? EmployeeCode { get; set; }
    public string? Salutation { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? Designation { get; set; }
    public string? Gender { get; set; }
    public string? Mobile { get; set; }
    public DateTime? JoiningDate { get; set; }
    public DateTime? DateOfBirth { get; set; }
    public string? ProfilePictureUrl { get; set; }
    public string Status { get; set; } = "Active";

    // New Hybrid Core Fields
    public string? FatherOrSpouse { get; set; }
    public string? PresentAddress { get; set; }
    public string? PermanentAddress { get; set; }
    public string? EmployeePfNo { get; set; }
    public string? EmployeeEsicNo { get; set; }
    public string? EmployeeAadharNo { get; set; }
    public DateTime? Days80ServiceCompletionDate { get; set; }
    public DateTime? PermanentAppointmentDate { get; set; }
    public int? PeriodOfSuspension { get; set; }
    public string? SignatureImageUrl { get; set; }
    public string? ThumbImpressionImageUrl { get; set; }
    public DateTime? DateOfExit { get; set; }
    public string? ReasonForExit { get; set; }
    public string? Remarks { get; set; }
    
    // Dynamic Flex Column
    public string? CustomFieldsJson { get; set; }
    public string? Role { get; set; }
    public string? Department { get; set; }
    public int? DepartmentId { get; set; }
    public int? DesignationId { get; set; }
    public EmployeeAccountDetails? BankDetails { get; set; }

    // Flattened Bank Details for Exports
    public string? AccountNumber { get; set; }
    public string? BankName { get; set; }
    public string? IfscCode { get; set; }
}

public class CreateEmployeeRequest
{
    public string? EmployeeCode { get; set; }
    public string? Salutation { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? Password { get; set; }
    public string? Designation { get; set; }
    public string? Gender { get; set; }
    public string? Mobile { get; set; }
    public string? JoiningDate { get; set; }
    public string? DateOfBirth { get; set; }
    public string? ProfilePictureUrl { get; set; }
    public int? OrganizationId { get; set; }
    public int? LinkToUserId { get; set; }

    // New Physical Core Fields
    public string? FatherOrSpouse { get; set; }
    public string? PresentAddress { get; set; }
    public string? PermanentAddress { get; set; }
    public string? EmployeePfNo { get; set; }
    public string? EmployeeEsicNo { get; set; }
    public string? EmployeeAadharNo { get; set; }
    public string? Days80ServiceCompletionDate { get; set; }
    public string? PermanentAppointmentDate { get; set; }
    public int? PeriodOfSuspension { get; set; }
    public string? SignatureImageUrl { get; set; }
    public string? ThumbImpressionImageUrl { get; set; }
    public string? DateOfExit { get; set; }
    public string? ReasonForExit { get; set; }
    public string? Department { get; set; }
    public int? DepartmentId { get; set; }
    public int? DesignationId { get; set; }
    public string? Remarks { get; set; }

    // Dynamic Flex Column
    public string? CustomFieldsJson { get; set; }
}

public class EmployeeAccountDetails
{
    public int Id { get; set; }
    public int EmployeeId { get; set; }
    public int OrganizationId { get; set; }
    public long? AccountNumber { get; set; }
    public string? AccountHolderName { get; set; }
    public string? Branch { get; set; }
    public string? Ifsc { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public int? CreatedBy { get; set; }
    public int? LastUpdatedBy { get; set; }
}

public class UnlinkedUser
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
}

public class BankDetailsRequest
{
    public int? OrganizationId { get; set; }
    public long? AccountNumber { get; set; }
    public string? AccountHolderName { get; set; }
    public string? Branch { get; set; }
    public string? Ifsc { get; set; }
}
