using Dapper;
using Serilog;
using backend.Hubs;
using backend.Data;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;

// ── Configure Serilog before anything else ─── (DB rev: Migration 31)
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .WriteTo.Console(
        restrictedToMinimumLevel: Serilog.Events.LogEventLevel.Warning,
        outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}")
    .WriteTo.File(
        path: "Logs/app-.log",
        rollingInterval: RollingInterval.Day,          // new file each day: app-20260302.log
        retainedFileCountLimit: 30,                    // keep last 30 days
        outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff} [{Level:u3}] {SourceContext} | {Message:lj}{NewLine}{Exception}")
    .Enrich.FromLogContext()
    .CreateLogger();

try
{
    Log.Information("=== ProDesX-HRM Backend Starting (Migrations Rev 5: Explicit Columns) ===");

    var builder = WebApplication.CreateBuilder(args);

    // Replace default .NET logger with Serilog
    builder.Host.UseSerilog();

    // Add services to the container
    builder.Services.AddOpenApi();
    builder.Services.AddControllers();
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen();
    builder.Services.AddSignalR();

    // Register background tasks
    builder.Services.AddHostedService<backend.Services.ShiftScheduleBackgroundService>();
    builder.Services.AddScoped<backend.Services.ExportService>();

    // JWT Authentication Setup
    var jwtSettings = builder.Configuration.GetSection("Jwt");
    var jwtKey = jwtSettings["Key"] ?? throw new Exception("Critical Error: 'Jwt:Key' is missing in appsettings.json");
    var key = Encoding.ASCII.GetBytes(jwtKey);

    builder.Services.AddAuthentication(options =>
    {
        options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
        options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
    })
    .AddJwtBearer(options =>
    {
        options.RequireHttpsMetadata = false;
        options.SaveToken = true;
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(key),
            ValidateIssuer = true,
            ValidIssuer = jwtSettings["Issuer"] ?? throw new Exception("'Jwt:Issuer' is missing in appsettings.json"),
            ValidateAudience = true,
            ValidAudience = jwtSettings["Audience"] ?? throw new Exception("'Jwt:Audience' is missing in appsettings.json"),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.Zero
        };

        // NEW: Handle SignalR authentication via query string
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var accessToken = context.Request.Query["access_token"];
                var path = context.HttpContext.Request.Path;
                if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs"))
                {
                    context.Token = accessToken;
                }
                return Task.CompletedTask;
            }
        };
    });

    builder.Services.AddAuthorization();

    // Enable snake_case to PascalCase mapping for Dapper
    DefaultTypeMap.MatchNamesWithUnderscores = true;

    // Add CORS
    builder.Services.AddCors(options =>
    {
        options.AddPolicy("AllowAll", policy =>
            {
                policy.SetIsOriginAllowed(_ => true)
                      .AllowAnyMethod()
                      .AllowAnyHeader()
                      .AllowCredentials();
            });
    });

    // Register DataBaseConnection
    var connectionString = builder.Configuration.GetConnectionString("DefaultConnection") ?? throw new Exception("Critical Error: 'ConnectionStrings:DefaultConnection' is missing in appsettings.json");
    builder.Services.AddSingleton(new DataBaseConnection(connectionString));

    var app = builder.Build();

    // Move CORS to the very top of the pipeline
    app.UseCors("AllowAll");

    // Auto-Initialize Database
    var schemaPath = Path.Combine(app.Environment.ContentRootPath, "../schema.sql");
    var migrationsPath = Path.Combine(app.Environment.ContentRootPath, "../migrations.sql");
    var seedFieldsPath = Path.Combine(app.Environment.ContentRootPath, "../seed_fields.sql");

    var adminEmail = app.Configuration["InitialAdmin:Email"] ?? throw new Exception("'InitialAdmin:Email' is missing");
    var adminPassword = app.Configuration["InitialAdmin:Password"] ?? throw new Exception("'InitialAdmin:Password' is missing");

    DbInitializer.Initialize(connectionString, schemaPath, migrationsPath, seedFieldsPath, adminEmail, adminPassword);

    var backendUrl = app.Configuration["BackendUrl"] ?? throw new Exception("Critical Error: 'BackendUrl' is missing in appsettings.json");
    app.Urls.Add(backendUrl);

    // Serve uploaded files (e.g. employee profile photos) from uploads/
    app.UseStaticFiles();
    var uploadsPath = Path.Combine(Directory.GetCurrentDirectory(), "uploads");
    if (!Directory.Exists(uploadsPath)) Directory.CreateDirectory(uploadsPath);
    app.UseStaticFiles(new StaticFileOptions
    {
        FileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(uploadsPath),
        RequestPath = "/uploads"
    });

    // Configure the HTTP request pipeline
    app.UseSwagger();
    app.UseSwaggerUI();
    app.UseHttpsRedirection();
    app.UseAuthentication();
    app.UseAuthorization();

    // Log every HTTP request automatically
    app.UseSerilogRequestLogging(opts =>
    {
        opts.MessageTemplate = "HTTP {RequestMethod} {RequestPath} → {StatusCode} ({Elapsed:0.0}ms)";
    });

    // Hubs should be mapped before Controllers for better precedence
    app.MapHub<LeadsHub>("/hubs/leads");
    app.MapHub<DealsHub>("/dealsHub");
    app.MapHub<UserManagementHub>("/hubs/userManagement");
    app.MapHub<DesignationHub>("/hubs/designations");
    app.MapHub<EmployeesHub>("/hubs/employees");
    app.MapHub<DepartmentHub>("/hubs/departments");
    app.MapHub<MustorRollHub>("/hubs/mustorroll");
    app.MapHub<DangerousOccurrencesHub>("/hubs/dangerousoccurrences");
    app.MapHub<HolidaysHub>("/hubs/holidays");
    app.MapHub<AttendanceHub>("/hubs/attendance");
    app.MapHub<EmpOTHub>("/hubs/empot");
    app.MapHub<ProfessionalTaxHub>("/hubs/professionaltax");
    app.MapHub<AllowancesHub>("/hubs/allowances");
    app.MapHub<StaffAllowanceHub>("/hubs/staffallowances");
    app.MapHub<DeductionsHub>("/hubs/deductions");
    app.MapHub<StaffDeductionHub>("/hubs/staffdeductions");
    app.MapHub<SalaryYearHub>("/hubs/salaryyears");
    app.MapHub<SalarySettingsHub>("/hubs/salarysettings");
    app.MapHub<StaffSalaryHub>("/hubs/staffsalary");

    app.MapControllers();
    Log.Information("=== Backend running at {Url} ===", backendUrl);

    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Backend terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush(); // ensure all logs are written before process exits
}


