using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using backend.Data;
using backend.Models;
using Dapper;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;

namespace backend.Services
{
    public class ShiftScheduleBackgroundService : BackgroundService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<ShiftScheduleBackgroundService> _logger;

        public ShiftScheduleBackgroundService(IServiceProvider serviceProvider, ILogger<ShiftScheduleBackgroundService> logger)
        {
            _serviceProvider = serviceProvider;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Shift Schedule Background Service is starting.");

            // Initial delay before the first run (e.g., 10 seconds)
            await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken);

            while (!stoppingToken.IsCancellationRequested)
            {
                _logger.LogInformation("Shift Schedule Background Service is running...");

                try
                {
                    await ProcessSchedulesAsync(stoppingToken);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error occurred executing ProcessSchedulesAsync.");
                }

                // Wait 24 hours before running again (or whatever interval makes sense)
                // For demonstration/testing, running it once a day is good. 
                await Task.Delay(TimeSpan.FromHours(24), stoppingToken);
            }
        }

        private async Task ProcessSchedulesAsync(CancellationToken stoppingToken)
        {
            using var scope = _serviceProvider.CreateScope();
            var dbConnection = scope.ServiceProvider.GetRequiredService<DataBaseConnection>();

            using var conn = dbConnection.CreateConnection();
            
            // Get all recurring active assignments (no end_date or end_date >= Today)
            var activeAssignments = (await conn.QueryAsync<ShiftAssignment>(
                @"SELECT 
                    id, organization_id, employee_id, template_id,
                    shift_name, shift_type, 
                    CONVERT(VARCHAR(5), start_time, 108) AS StartTime, 
                    CONVERT(VARCHAR(5), end_time, 108) AS EndTime, 
                    unpaid_break, total_shift_hours, 
                    CONVERT(VARCHAR(5), earliest_punch_in, 108) AS EarliestPunchIn, 
                    CONVERT(VARCHAR(5), latest_punch_out, 108) AS LatestPunchOut, 
                    late_grace_period, early_grace_period, work_days, 
                    start_date, end_date, assignment_type, specific_dates, remarks,
                    created_at, updated_at
                  FROM ShiftAssignments 
                  WHERE assignment_type = 3 AND (end_date IS NULL OR end_date >= @Today)",
                new { Today = DateTime.Today }
            )).ToList();

            int insertedCount = 0;

            foreach (var assignment in activeAssignments)
            {
                if (stoppingToken.IsCancellationRequested) break;

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
                    new { OrgId = assignment.OrganizationId, EmpId = assignment.EmployeeId }
                )).ToHashSet();

                // We want to ensure the next 30 days from today are generated
                var startDate = DateTime.Today;
                var endDate = DateTime.Today.AddDays(30);

                if (assignment.EndDate.HasValue && assignment.EndDate.Value < endDate)
                {
                    endDate = assignment.EndDate.Value;
                }

                // Robust WorkDays matching
                var workDaysStr = (assignment.WorkDays ?? "Mon,Tue,Wed,Thu,Fri").ToLower();
                var targetDates = new List<(DateTime Date, string Type, bool IsWork)>();

                // Ensure we only generate schedules from the assignment start date onwards
                var currentStartDate = (assignment.StartDate ?? startDate) > startDate ? (assignment.StartDate ?? startDate) : startDate;

                for (var date = currentStartDate; date <= endDate; date = date.AddDays(1))
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

                    if (holidays.Contains(date.Date))
                    {
                        targetDates.Add((date, "H", false));
                    }
                    else if (isWorkDay)
                    {
                        targetDates.Add((date, assignment.ShiftType ?? "W/D", true));
                    }
                    else
                    {
                        targetDates.Add((date, "WF", false));
                    }
                }

                foreach (var item in targetDates)
                {
                    var parameters = new
                    {
                        OrganizationId = assignment.OrganizationId,
                        EmployeeId = assignment.EmployeeId,
                        Date = item.Date.ToString("yyyy-MM-dd"),
                        ShiftName = item.IsWork ? assignment.ShiftName : item.Type == "H" ? "Holiday" : "Week Off",
                        ShiftType = item.Type,
                        StartTime = item.IsWork ? assignment.StartTime : (string?)null,
                        EndTime = item.IsWork ? assignment.EndTime : (string?)null,
                        UnpaidBreak = item.IsWork ? assignment.UnpaidBreak : 0,
                        TotalShiftHours = item.IsWork ? assignment.TotalShiftHours : "00:00",
                        EarliestPunchIn = item.IsWork ? assignment.EarliestPunchIn : (string?)null,
                        LatestPunchOut = item.IsWork ? assignment.LatestPunchOut : (string?)null,
                        LateGracePeriod = item.IsWork ? assignment.LateGracePeriod : 0,
                        EarlyGracePeriod = item.IsWork ? assignment.EarlyGracePeriod : 0,
                        IsOverride = false, // Background service creates base schedules
                        SourceAssignmentId = (int?)assignment.Id,
                        CreatedBy = (int?)null, // System generated
                        LastUpdatedBy = (int?)null
                    };

                    // Don't overwrite if it already exists (specifically manual overrides or existing base schedule)
                    var exists = await conn.QueryFirstOrDefaultAsync<int?>(
                        "SELECT Id FROM EmployeeSchedules WHERE employee_id = @EmployeeId AND Date = @Date",
                        new { EmployeeId = assignment.EmployeeId, Date = item.Date.ToString("yyyy-MM-dd") }
                    );

                    if (exists == null)
                    {
                        await conn.ExecuteAsync("sp_UpsertEmployeeSchedule", parameters, commandType: CommandType.StoredProcedure);
                        insertedCount++;
                    }
                }
            }

            _logger.LogInformation($"Shift Schedule Background Service completed. Inserted {insertedCount} new schedules for the rolling 30-day window.");
        }
    }
}
