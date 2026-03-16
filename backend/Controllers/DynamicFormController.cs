using Dapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Data;
using backend.Models;
using backend.Data;

namespace backend.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class DynamicFormController : ControllerBase
{
    private readonly DataBaseConnection _db;
    private readonly ILogger<DynamicFormController> _logger;

    public DynamicFormController(DataBaseConnection db, ILogger<DynamicFormController> logger)
    {
        _db = db;
        _logger = logger;
    }

    private string GetRole() => User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value ?? "User";

    private int GetUserId()
    {
        var claim = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        return int.TryParse(claim, out var id) ? id : 0;
    }

    // GET /api/DynamicForm/employee-fields
    // All logged-in users can see fields (form renders based on this)
    [HttpGet("employee-fields")]
    public async Task<IActionResult> GetEmployeeFields([FromQuery] int? organizationId)
    {
        var userOrgId = int.Parse(User.FindFirst("OrganizationId")?.Value ?? "0");
        var targetOrgId = organizationId ?? userOrgId;

        try
        {
            using var conn = _db.CreateConnection();
            var fields = await conn.QueryAsync<dynamic>("sp_GetEmployeeFormFields", new { OrgId = targetOrgId }, commandType: CommandType.StoredProcedure);
            return Ok(fields);
        }
        catch (Exception ex)
        {
            return StatusCode(500, $"Failed to fetch form configuration: {ex.Message}");
        }
    }

    // POST /api/DynamicForm/update-fields
    // Admin and SuperAdmin can toggle visibility per org
    [Authorize(Roles = "Admin,SuperAdmin")]
    [HttpPost("update-fields")]
    public async Task<IActionResult> UpdateEmployeeFields([FromBody] UpdateFieldsRequest request)
    {
        var userOrgIdClaim = User.FindFirst("OrganizationId")?.Value;
        int.TryParse(userOrgIdClaim, out var userOrgId);
        var targetOrgId = request.OrganizationId ?? userOrgId;

        if (targetOrgId <= 0) return BadRequest("Valid OrganizationId is required.");
        if (request.Fields == null || !request.Fields.Any()) return BadRequest("No fields provided.");

        try
        {
            using var conn = _db.CreateConnection();
            using var transaction = conn.BeginTransaction();

            var uniqueFields = request.Fields
                .GroupBy(f => f.FieldId)
                .Select(g => g.First())
                .ToList();

            foreach (var field in uniqueFields)
            {
                await conn.ExecuteAsync("sp_UpsertEmployeeFieldSetting", new
                {
                    OrgId = targetOrgId,
                    FieldId = field.FieldId,
                    IsVisible = field.IsVisible >= 1 ? 1 : 0,
                    IsMandatory = field.IsMandatory >= 1 ? 1 : 0,
                    LastUpdatedBy = GetUserId()
                }, transaction, commandType: CommandType.StoredProcedure);
            }

            transaction.Commit();
            return Ok(new { message = "Fields updated successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "EmpDataUpdateError: Failed to update employee fields for OrgId {OrgId}. Payload: {@Fields}", 
                targetOrgId, request.Fields);
                
            var errorDetail = ex.Message;
            if (ex.InnerException != null) errorDetail += " | " + ex.InnerException.Message;
            return StatusCode(500, $"Configuration update failed: {errorDetail}");
        }
    }

    // POST /api/DynamicForm/create-field
    // SuperAdmin only — adds a new master field available to all organizations
    [Authorize(Roles = "SuperAdmin")]
    [HttpPost("create-field")]
    public async Task<IActionResult> CreateMasterField([FromBody] CreateMasterFieldRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.FieldKey) || string.IsNullOrWhiteSpace(request.DisplayLabel))
            return BadRequest("FieldKey and DisplayLabel are required.");

        try
        {
            using var conn = _db.CreateConnection();

            // Check for duplicate field_key
            var exists = await conn.ExecuteScalarAsync<int>("sp_CheckFieldKeyExists", new { request.FieldKey }, commandType: CommandType.StoredProcedure);

            if (exists > 0)
                return Conflict(new { message = $"A field with key '{request.FieldKey}' already exists." });

            var newId = await conn.ExecuteScalarAsync<int>("sp_CreateMasterField", new
                {
                    request.FieldKey,
                    request.DisplayLabel,
                    SectionName = request.SectionName ?? "General",
                    SectionOrder = request.SectionOrder ?? 99,
                    FieldOrder = request.FieldOrder ?? 99,
                    GridSize = request.GridSize ?? 6,
                    ComponentType = request.ComponentType ?? "text",
                    OptionsJson = request.OptionsJson,
                    CreatedBy = GetUserId()
                }, commandType: CommandType.StoredProcedure);

            // Auto-seed into all organizations as visible
            await conn.ExecuteAsync("sp_AutoSeedNewField", new { FieldId = newId }, commandType: CommandType.StoredProcedure);

            return Ok(new { message = "Field created successfully.", fieldId = newId });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "CreateFieldFailure: Failed to create master field with key {FieldKey}", request.FieldKey);
            return StatusCode(500, $"Failed to create field: {ex.Message}");
        }
    }

    // DELETE /api/DynamicForm/delete-field/{id}
    // SuperAdmin only — removes a master field from all orgs (only non-core fields)
    [Authorize(Roles = "SuperAdmin")]
    [HttpDelete("delete-field/{id}")]
    public async Task<IActionResult> DeleteMasterField(int id)
    {
        try
        {
            using var conn = _db.CreateConnection();

            var rows = await conn.ExecuteAsync("sp_DeleteMasterField", new { Id = id }, commandType: CommandType.StoredProcedure);

            if (rows == 0) return NotFound(new { message = "Field not found." });
            return Ok(new { message = "Field deleted successfully." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "DeleteFieldFailure: Failed to delete master field with ID {Id}", id);
            return StatusCode(500, $"Failed to delete field: {ex.Message}");
        }
    }
}

// ── Request Models ───────────────────────────────────────────────────────────

public class UpdateFieldsRequest
{
    public int? OrganizationId { get; set; }
    public List<FieldSettingUpdate> Fields { get; set; } = new();
}

public class FieldSettingUpdate
{
    public int FieldId { get; set; }
    public int IsVisible { get; set; }
    public int IsMandatory { get; set; }
}

public class CreateMasterFieldRequest
{
    public string FieldKey { get; set; } = string.Empty;
    public string DisplayLabel { get; set; } = string.Empty;
    public string? SectionName { get; set; }
    public int? SectionOrder { get; set; }
    public int? FieldOrder { get; set; }
    public int? GridSize { get; set; }
    public string? ComponentType { get; set; }
    public string? OptionsJson { get; set; }
}
