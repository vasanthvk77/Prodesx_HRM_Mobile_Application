using System;

namespace backend.Models;

public class ModuleInfo
{
    public int ModuleID { get; set; }
    public string ModuleName { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsEnabled { get; set; }
}

public class ToggleModuleRequest
{
    public int ModuleID { get; set; }
    public bool IsEnabled { get; set; }
    public int? OrganizationId { get; set; }
}
