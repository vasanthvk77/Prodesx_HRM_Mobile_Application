using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.Authorization;
using Dapper;
using System.Data;
using System.Linq;
using System.Collections.Generic;
using backend.Models;
using backend.Data;
using backend.Hubs;

namespace backend.Controllers;

// Forced restart to apply migrations
[Authorize]
[ApiController]
[Route("api/[controller]")]
public class ShiftAssignmentsController : ControllerBase
{
    private readonly DataBaseConnection _dataBaseConnection;
    private readonly IHubContext<EmployeesHub> _hubContext;
    private readonly ILogger<ShiftAssignmentsController> _logger;

    public ShiftAssignmentsController(DataBaseConnection dataBaseConnection, IHubContext<EmployeesHub> hubContext, ILogger<ShiftAssignmentsController> logger)
    {
        _dataBaseConnection = dataBaseConnection;
        _hubContext = hubContext;
        _logger = logger;
    }

    private int GetOrgId()
    {
        var orgClaim = User.FindFirst("OrganizationId")?.Value;
        return int.TryParse(orgClaim, out var id) ? id : 0;
    }

    private int GetUserId()
    {
        var claim = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        return int.TryParse(claim, out var id) ? id : 0;
    }

    // Use explicit orgId from query param (dropdown selection) if provided, else fall back to JWT
    private int ResolveOrgId(int? orgId) => (orgId.HasValue && orgId.Value > 0) ? orgId.Value : GetOrgId();

    [HttpGet("templates")]
    public async Task<IActionResult> GetShiftTemplates([FromQuery] int? orgId)
    {
        var resolvedOrgId = ResolveOrgId(orgId);
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            var templates = await conn.QueryAsync<ShiftTemplate>(
                "sp_GetShiftTemplates",
                new { OrganizationId = resolvedOrgId },
                commandType: CommandType.StoredProcedure
            );
            return Ok(templates);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching shift templates");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpPost("templates")]
    public async Task<IActionResult> CreateShiftTemplate([FromBody] ShiftTemplate template, [FromQuery] int? orgId)
    {
        var resolvedOrgId = ResolveOrgId(orgId);
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            var parameters = new
            {
                Id = 0,
                OrganizationId = resolvedOrgId,
                template.ShiftName,
                template.ShiftType,
                template.StartTime,
                template.EndTime,
                template.UnpaidBreak,
                template.TotalShiftHours,
                template.EarliestPunchIn,
                template.LatestPunchOut,
                template.LateGracePeriod,
                template.EarlyGracePeriod,
                CreatedBy = GetUserId(),
                LastUpdatedBy = GetUserId()
            };

            var id = await conn.ExecuteScalarAsync<int>(
                "sp_UpsertShiftTemplate", 
                parameters, 
                commandType: CommandType.StoredProcedure
            );
            template.Id = id;
            template.OrganizationId = resolvedOrgId;

            // SignalR Notification
            await _hubContext.Clients.Group($"Org_{resolvedOrgId}").SendAsync("ShiftTemplateUpdated", new { Action = "Create", Data = template });
            
            return Ok(template);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating shift template");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpPut("templates/{id}")]
    public async Task<IActionResult> UpdateShiftTemplate(int id, [FromBody] ShiftTemplate template, [FromQuery] int? orgId)
    {
        var resolvedOrgId = ResolveOrgId(orgId);
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            var parameters = new
            {
                Id = id,
                OrganizationId = resolvedOrgId,
                template.ShiftName,
                template.ShiftType,
                template.StartTime,
                template.EndTime,
                template.UnpaidBreak,
                template.TotalShiftHours,
                template.EarliestPunchIn,
                template.LatestPunchOut,
                template.LateGracePeriod,
                template.EarlyGracePeriod,
                LastUpdatedBy = GetUserId()
            };

            await conn.ExecuteAsync(
                "sp_UpsertShiftTemplate", 
                parameters, 
                commandType: CommandType.StoredProcedure
            );
            template.Id = id;
            template.OrganizationId = resolvedOrgId;

            // SignalR Notification
            await _hubContext.Clients.Group($"Org_{resolvedOrgId}").SendAsync("ShiftTemplateUpdated", new { Action = "Update", Data = template });

            return Ok(template);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating shift template");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpDelete("templates/{id}")]
    public async Task<IActionResult> DeleteShiftTemplate(int id, [FromQuery] int? orgId)
    {
        var resolvedOrgId = ResolveOrgId(orgId);
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            await conn.ExecuteAsync(
                "sp_DeleteShiftTemplate",
                new { Id = id, OrganizationId = resolvedOrgId },
                commandType: CommandType.StoredProcedure
            );

            // SignalR Notification
            await _hubContext.Clients.Group($"Org_{resolvedOrgId}").SendAsync("ShiftTemplateUpdated", new { Action = "Delete", Id = id });

            return Ok(new { Message = "Template deleted" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting shift template");
            return StatusCode(500, ex.Message);
        }
    }

    // --- Shift Assignments ---

    [HttpGet]
    public async Task<IActionResult> GetShiftAssignments([FromQuery] int? orgId)
    {
        var resolvedOrgId = ResolveOrgId(orgId);
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            var assignments = await conn.QueryAsync<ShiftAssignment>(
                "sp_GetShiftAssignments", 
                new { OrganizationId = resolvedOrgId },
                commandType: CommandType.StoredProcedure
            );
            return Ok(assignments);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching shift assignments");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpPost]
    public async Task<IActionResult> UpsertShiftAssignment([FromBody] ShiftAssignment assignment, [FromQuery] int? orgId)
    {
        var resolvedOrgId = ResolveOrgId(orgId);
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            var parameters = new
            {
                organization_id = resolvedOrgId,
                employee_id = assignment.EmployeeId,
                template_id = assignment.TemplateId,
                shift_name = assignment.ShiftName,
                shift_type = assignment.ShiftType,
                start_time = assignment.StartTime,
                end_time = assignment.EndTime,
                unpaid_break = assignment.UnpaidBreak,
                total_shift_hours = assignment.TotalShiftHours,
                earliest_punch_in = assignment.EarliestPunchIn,
                latest_punch_out = assignment.LatestPunchOut,
                late_grace_period = assignment.LateGracePeriod,
                early_grace_period = assignment.EarlyGracePeriod,
                work_days = assignment.WorkDays,
                start_date = assignment.StartDate,
                end_date = assignment.EndDate,
                assignment_type = assignment.AssignmentType,
                specific_dates = assignment.SpecificDates,
                remarks = assignment.Remarks,
                created_by = GetUserId(),
                last_updated_by = GetUserId()
            };

            await conn.ExecuteAsync(
                "sp_UpsertShiftAssignment", 
                parameters, 
                commandType: CommandType.StoredProcedure
            );

            // Fetch the assignment ID for linking
            var assignmentId = await conn.QueryFirstOrDefaultAsync<int>(
                "SELECT TOP 1 id FROM ShiftAssignments WHERE employee_id = @EmployeeId AND organization_id = @OrganizationId",
                new { assignment.EmployeeId, OrganizationId = resolvedOrgId }
            );
            assignment.Id = assignmentId;

            // Generate daily schedules for the next 30 days based on this new assignment
            await GenerateDailySchedulesFromAssignment(assignment, resolvedOrgId);

            // SignalR Notification
            await _hubContext.Clients.Group($"Org_{resolvedOrgId}").SendAsync("ShiftAssignmentUpdated", new { Action = "Assign", EmployeeId = assignment.EmployeeId });

            return Ok(new { Message = "Shift assigned successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error assigning shift");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpGet("roster")]
    public async Task<IActionResult> GetMonthlyRosterFixed([FromQuery] string start, [FromQuery] string end, [FromQuery] int? orgId)
    {
        var resolvedOrgId = ResolveOrgId(orgId);
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            var roster = await conn.QueryAsync<EmployeeSchedule>(
                "sp_GetEmployeeSchedules",
                new { OrganizationId = resolvedOrgId, StartDate = start, EndDate = end },
                commandType: CommandType.StoredProcedure
            );
            return Ok(roster);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching roster");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpPost("schedule")]
    public async Task<IActionResult> UpsertDailySchedule([FromBody] EmployeeSchedule schedule, [FromQuery] int? orgId)
    {
        var resolvedOrgId = ResolveOrgId(orgId);
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            var parameters = new
            {
                OrganizationId = resolvedOrgId,
                schedule.EmployeeId,
                Date = schedule.Date.ToString("yyyy-MM-dd"),
                schedule.ShiftName,
                schedule.ShiftType,
                schedule.StartTime,
                schedule.EndTime,
                schedule.UnpaidBreak,
                schedule.TotalShiftHours,
                schedule.EarliestPunchIn,
                schedule.LatestPunchOut,
                schedule.LateGracePeriod,
                schedule.EarlyGracePeriod,
                IsOverride = true,
                SourceAssignmentId = schedule.SourceAssignmentId,
                CreatedBy = GetUserId(),
                LastUpdatedBy = GetUserId()
            };

            await conn.ExecuteAsync(
                "sp_UpsertEmployeeSchedule",
                parameters,
                commandType: CommandType.StoredProcedure
            );

            // SignalR Notification
            await _hubContext.Clients.Group($"Org_{resolvedOrgId}").SendAsync("ShiftAssignmentUpdated", new { Action = "ScheduleUpdate", EmployeeId = schedule.EmployeeId, Date = schedule.Date });

            return Ok(new { Message = "Daily schedule updated" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating daily schedule");
            return StatusCode(500, ex.Message);
        }
    }

    private async Task GenerateDailySchedulesFromAssignment(ShiftAssignment assignment, int orgId)
    {
        using var conn = _dataBaseConnection.CreateConnection();
        
        // We'll use a list of objects to track both the date and its properties (Work/Holiday/WeekOff)
        var schedulesToInsert = new List<dynamic>();

        if (assignment.AssignmentType == 1) // Single Date
        {
            if (assignment.StartDate.HasValue) 
                schedulesToInsert.Add(new { Date = assignment.StartDate.Value, Type = assignment.ShiftType, IsWorkDay = true });
        }
        else if (assignment.AssignmentType == 2) // Multiple Dates
        {
            if (!string.IsNullOrEmpty(assignment.SpecificDates))
            {
                var dateStrings = assignment.SpecificDates.Split(',').Select(d => d.Trim());
                foreach (var ds in dateStrings)
                {
                    if (DateTime.TryParse(ds, out var parsedDate)) 
                        schedulesToInsert.Add(new { Date = parsedDate, Type = assignment.ShiftType, IsWorkDay = true });
                }
            }
        }
        else if (assignment.AssignmentType == 3) // Range / Recurring
        {
            var startDate = assignment.StartDate ?? DateTime.Today;
            var endDate = assignment.EndDate ?? DateTime.Today.AddDays(30); 
            var workDaysStr = (assignment.WorkDays ?? "Mon,Tue,Wed,Thu,Fri").ToLower();
            
            // Fetch holidays that apply to this employee
            var holidays = (await conn.QueryAsync<DateTime>(
                @"IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'HolidayAssignments')
                  BEGIN
                      DECLARE @sql NVARCHAR(MAX) = 'SELECT DISTINCT CAST(h.HolidayDate AS DATE) 
                            FROM Holidays h
                            LEFT JOIN HolidayAssignments ha ON h.HolidayID = ha.holiday_id
                            LEFT JOIN employees e ON e.id = @e_id
                            WHERE h.OrganizationID = @o_id
                            AND (
                                h.AssignmentType = ''All'' OR 
                                (ha.target_type = ''Employee'' AND ha.target_id = @e_id) OR
                                (ha.target_type = ''Department'' AND ha.target_id = e.department_id) OR
                                (ha.target_type = ''Designation'' AND ha.target_id = e.designation_id)
                            )';
                      EXEC sp_executesql @sql, N'@e_id INT, @o_id INT', @e_id = @EmpId, @o_id = @OrgId;
                  END
                  ELSE
                  BEGIN
                      SELECT DISTINCT CAST(HolidayDate AS DATE) FROM Holidays WHERE OrganizationID = @OrgId AND AssignmentType = 'All'
                  END",
                new { OrgId = orgId, EmpId = assignment.EmployeeId }
            )).ToHashSet();

            for (var date = startDate; date <= endDate; date = date.AddDays(1))
            {
                var dayFull = date.ToString("dddd").ToLower();
                var day3 = date.ToString("ddd").ToLower();
                var day2 = day3.Substring(0, 2);
                var day1 = day3.Substring(0, 1);

                bool isWorkDay = false;
                if (workDaysStr.Contains(","))
                {
                    var splitDays = workDaysStr.Split(',').Select(d => d.Trim()).ToList();
                    isWorkDay = splitDays.Any(d => d == dayFull || d == day3 || d == day2 || d == day1);
                }
                else
                {
                    if (day3 == "tue") isWorkDay = workDaysStr.Contains("tu");
                    else if (day3 == "thu") isWorkDay = workDaysStr.Contains("th");
                    else if (day3 == "sat") isWorkDay = workDaysStr.Contains("sa") || (workDaysStr.Contains("s") && !workDaysStr.Contains("su"));
                    else if (day3 == "sun") isWorkDay = workDaysStr.Contains("su");
                    else isWorkDay = workDaysStr.Contains(day1);
                }

                string finalType = "WF";
                bool isActualWork = false;

                if (holidays.Contains(date.Date)) 
                {
                    finalType = "H";
                }
                else if (isWorkDay)
                {
                    finalType = assignment.ShiftType ?? "W/D";
                    isActualWork = true;
                }

                schedulesToInsert.Add(new { Date = date, Type = finalType, IsWorkDay = isActualWork });
            }
        }

        foreach (var item in schedulesToInsert)
        {
            var parameters = new
            {
                OrganizationId = orgId,
                EmployeeId = assignment.EmployeeId,
                Date = ((DateTime)item.Date).ToString("yyyy-MM-dd"),
                ShiftName = (bool)item.IsWorkDay ? assignment.ShiftName : (string)item.Type == "H" ? "Holiday" : "Week Off",
                ShiftType = (string)item.Type,
                StartTime = (bool)item.IsWorkDay ? assignment.StartTime : (string?)null,
                EndTime = (bool)item.IsWorkDay ? assignment.EndTime : (string?)null,
                UnpaidBreak = (bool)item.IsWorkDay ? assignment.UnpaidBreak : 0,
                TotalShiftHours = (bool)item.IsWorkDay ? assignment.TotalShiftHours : "00:00",
                EarliestPunchIn = (bool)item.IsWorkDay ? assignment.EarliestPunchIn : (string?)null,
                LatestPunchOut = (bool)item.IsWorkDay ? assignment.LatestPunchOut : (string?)null,
                LateGracePeriod = (bool)item.IsWorkDay ? assignment.LateGracePeriod : 0,
                EarlyGracePeriod = (bool)item.IsWorkDay ? assignment.EarlyGracePeriod : 0,
                IsOverride = false,
                SourceAssignmentId = (int?)assignment.Id,
                CreatedBy = GetUserId(),
                LastUpdatedBy = GetUserId()
            };

            // Don't overwrite manual overrides
            var exists = await conn.QueryFirstOrDefaultAsync<int?>(
                "SELECT id FROM EmployeeSchedules WHERE employee_id = @EmployeeId AND Date = @Date AND is_override = 1",
                new { assignment.EmployeeId, Date = ((DateTime)item.Date).ToString("yyyy-MM-dd") }
            );

            if (exists == null)
            {
                await conn.ExecuteAsync("sp_UpsertEmployeeSchedule", parameters, commandType: CommandType.StoredProcedure);
            }
        }
    }

    [HttpDelete("schedule/{employeeId}")]
    public async Task<IActionResult> DeleteDailySchedule(int employeeId, [FromQuery] string date, [FromQuery] int? orgId)
    {
        var resolvedOrgId = ResolveOrgId(orgId);
        try
        {
            if (!DateTime.TryParse(date, out var parsedDate))
            {
                return BadRequest("Invalid date format. Use yyyy-MM-dd");
            }

            using var conn = _dataBaseConnection.CreateConnection();
            
            // Delete the daily schedule for this specific date
            await conn.ExecuteAsync(
                "DELETE FROM EmployeeSchedules WHERE employee_id = @EmployeeId AND organization_id = @OrganizationId AND Date = @Date",
                new { EmployeeId = employeeId, OrganizationId = resolvedOrgId, Date = parsedDate.ToString("yyyy-MM-dd") }
            );

            // SignalR Notification
            await _hubContext.Clients.Group($"Org_{resolvedOrgId}").SendAsync("ShiftAssignmentUpdated", new { Action = "ScheduleDelete", EmployeeId = employeeId, Date = parsedDate });

            return Ok(new { Message = "Daily schedule removed" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting daily schedule");
            return StatusCode(500, ex.Message);
        }
    }

    [HttpDelete("employee/{employeeId}")]
    public async Task<IActionResult> RemoveShiftAssignment(int employeeId, [FromQuery] int? orgId)
    {
        var resolvedOrgId = ResolveOrgId(orgId);
        try
        {
            using var conn = _dataBaseConnection.CreateConnection();
            
            // Delete daily schedules (except overrides? for now delete all future)
            await conn.ExecuteAsync(
                "DELETE FROM EmployeeSchedules WHERE employee_id = @EmployeeId AND organization_id = @OrganizationId AND Date >= @Today",
                new { EmployeeId = employeeId, OrganizationId = resolvedOrgId, Today = DateTime.Today }
            );

            await conn.ExecuteAsync(
                "sp_DeleteShiftAssignment",
                new { employee_id = employeeId, organization_id = resolvedOrgId },
                commandType: CommandType.StoredProcedure
            );

            // SignalR Notification
            await _hubContext.Clients.Group($"Org_{resolvedOrgId}").SendAsync("ShiftAssignmentUpdated", new { Action = "Remove", EmployeeId = employeeId });

            return Ok(new { Message = "Assignment removed" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing shift assignment");
            return StatusCode(500, ex.Message);
        }
    }
}
