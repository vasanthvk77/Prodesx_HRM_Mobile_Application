using System;

namespace backend.Models
{
    public class Department
    {
        public int Id { get; set; }
        public int OrganizationId { get; set; }
        public string? OrganizationName { get; set; }
        public string? DepartmentName { get; set; }
        public int? ParentDepartmentId { get; set; }
        public string? ParentDepartmentName { get; set; }
        
        // Aliases for Dapper mapping from stored procedures
        public string? department_name { get => DepartmentName; set => DepartmentName = value; }
        public string? organization_name { get => OrganizationName; set => OrganizationName = value; }
        public string? parent_department_name { get => ParentDepartmentName; set => ParentDepartmentName = value; }
        public string? department { get => DepartmentName; set => DepartmentName = value; }

        public DateTime CreatedAt { get; set; } = DateTime.Now;
        public DateTime UpdatedAt { get; set; } = DateTime.Now;
    }

    public class CreateDepartmentRequest
    {
        public int OrganizationId { get; set; }
        public string? OrganizationName { get; set; }
        public string? DepartmentName { get; set; }
        public int? ParentDepartmentId { get; set; }
    }
}
