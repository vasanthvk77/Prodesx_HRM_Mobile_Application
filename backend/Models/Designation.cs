using System;

namespace backend.Models
{
    public class Designation
    {
        public int Id { get; set; }
        public int OrganizationId { get; set; }
        public string? OrganizationName { get; set; }
        public string? DesignationName { get; set; }
        public int? ParentDesignationId { get; set; }
        public string? ParentDesignationName { get; set; }

        // Aliases for Dapper mapping from stored procedures (Dapper needs both get and set for mapping to work reliably in some cases)
        public string? designation_name { get => DesignationName; set => DesignationName = value; }
        public string? organization_name { get => OrganizationName; set => OrganizationName = value; }
        public string? parent_designation_name { get => ParentDesignationName; set => ParentDesignationName = value; }
        public string? designation { get => DesignationName; set => DesignationName = value; }
        public string? parent_designation { get => ParentDesignationName; set => ParentDesignationName = value; }

        public DateTime CreatedAt { get; set; } = DateTime.Now;
        public DateTime UpdatedAt { get; set; } = DateTime.Now;
    }

    public class CreateDesignationRequest
    {
        public int OrganizationId { get; set; }
        public string OrganizationName { get; set; } = string.Empty;
        public string DesignationName { get; set; } = string.Empty;
        public int? ParentDesignationId { get; set; }
    }
}
