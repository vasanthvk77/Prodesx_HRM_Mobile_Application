namespace backend.Models;

public class EmployeeDataField
{
    public int Id { get; set; }
    public string FieldKey { get; set; } = string.Empty;
    public string DisplayLabel { get; set; } = string.Empty;
    public string SectionName { get; set; } = string.Empty;
    public int FieldOrder { get; set; }
    public int GridSize { get; set; }
    public string ComponentType { get; set; } = string.Empty;
    public string? OptionsJson { get; set; }
    public bool IsCoreField { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.Now;
    public DateTime UpdatedAt { get; set; } = DateTime.Now;
    public int? CreatedBy { get; set; }
    public int? LastUpdatedBy { get; set; }
}

public class OrganizationFieldAccess
{
    public int Id { get; set; }
    public int OrganizationId { get; set; }
    public int FieldId { get; set; }
    public bool IsVisible { get; set; }
    public bool IsMandatory { get; set; }
    public string? CustomLabel { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.Now;
    public DateTime UpdatedAt { get; set; } = DateTime.Now;
    public int? CreatedBy { get; set; }
    public int? LastUpdatedBy { get; set; }
    
    // Joined data
    public EmployeeDataField? FieldMetadata { get; set; }
}
