using Dapper; // v31: TIME→VARCHAR fix
using Serilog;
using Microsoft.Data.SqlClient;
using System.Text.RegularExpressions;
using BCrypt.Net;

namespace backend.Data;

public static class DbInitializer
{
    // Initializing the database with stored procedures and seed data.
    public static void Initialize(string connectionString, string schemaPath, string migrationsPath, string seedFieldsPath, string adminEmail, string adminPassword)
    {
        using var conn = new SqlConnection(connectionString);
        Log.Information("=== ProDesX-HRM Backend Starting (Migrations Rev 4: Clean GOs) ===");
        try
        {
            conn.Open();
            Log.Information("[DB] Connected to: {Server} | {Database}", conn.DataSource, conn.Database);

            // Detect a fresh vs existing database.
            // We consider "fresh" only if there are no user tables at all.
            var userTableCount = conn.ExecuteScalar<int>(
                "SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0");

            if (userTableCount == 0)
            {
                // ── Fresh database: run full schema.sql ──────────────────
                Log.Information("--------------------------------------------------");
                Log.Information("[DB] Database not initialized. Running schema.sql...");

                RunSqlFile(conn, schemaPath, "schema.sql");

                // Bring a fresh DB up to latest revisions too.
                // This avoids having to manually keep schema.sql perfectly in sync with every migration.
                RunSqlFile(conn, migrationsPath, "migrations.sql");

                SeedInitialData(conn, adminEmail, adminPassword);

                // Seed dynamic employee fields after default org exists
                RunSqlFile(conn, seedFieldsPath, "seed_fields.sql");

                Log.Information("[DB] Database initialization complete.");
                Log.Information("--------------------------------------------------");
            }
            else
            {
                // ── Existing database: run migrations.sql ────────────────
                Log.Information("[DB] Database exists. Running migrations.sql...");

                RunSqlFile(conn, migrationsPath, "migrations.sql");

                Log.Information("[DB] Migrations complete.");
            }
        }
        catch (Exception ex)
        {
            Log.Fatal(ex, "[DB] CRITICAL ERROR during Database Initialization");
        }
    }

    // Reads a SQL file, splits on GO, and executes each batch independently
    private static void RunSqlFile(SqlConnection conn, string filePath, string label)
    {
        if (!File.Exists(filePath))
        {
            Log.Warning("[DB] SQL file not found: {FilePath}", filePath);
            return;
        }

        var script = File.ReadAllText(filePath);
        var batches = Regex.Split(script, @"^\s*GO\s*$",
            RegexOptions.Multiline | RegexOptions.IgnoreCase);

        int success = 0, skipped = 0;
        foreach (var batch in batches)
        {
            if (string.IsNullOrWhiteSpace(batch)) continue;
            try
            {
                conn.Execute(batch);
                success++;
            }
            catch (Exception ex)
            {
                // Log and continue — one bad batch shouldn't block the rest
                skipped++;
                Log.Warning("[DB] Batch skipped in {Label}: {Error}", label, ex.Message.Split('\n')[0]);
            }
        }

        Log.Information("[DB] Finished running {Label}. {Success} batches applied, {Skipped} skipped.", label, success, skipped);

        // Ensure stored procedures are always up-to-date on every start.
        // Many of our migrations guard procedures with IF NOT EXISTS, which prevents updates.
        // We extract CREATE PROCEDURE bodies and re-run them as CREATE OR ALTER.
        if (label.Equals("migrations.sql", StringComparison.OrdinalIgnoreCase))
        {
            ApplyProceduresAsCreateOrAlter(conn, script);
        }
    }

    private static void ApplyProceduresAsCreateOrAlter(SqlConnection conn, string script)
    {
        var batches = Regex.Split(script, @"^\s*GO\s*$",
            RegexOptions.Multiline | RegexOptions.IgnoreCase);

        int applied = 0, failed = 0;
        foreach (var batch in batches)
        {
            if (string.IsNullOrWhiteSpace(batch)) continue;

            // Skip batches wrapped in EXEC() - they're already applied in the initial run
            if (Regex.IsMatch(batch, @"EXEC\s*\(\s*'", RegexOptions.IgnoreCase))
                continue;

            // Match either "CREATE PROCEDURE" or "CREATE OR ALTER PROCEDURE"
            var idx = Regex.Match(batch, @"\bCREATE\s+(?:OR\s+ALTER\s+)?PROCEDURE\b", RegexOptions.IgnoreCase).Index;
            if (idx < 0 || idx >= batch.Length) continue;

            var procBody = batch.Substring(idx);
            // Replace both "CREATE PROCEDURE" and "CREATE OR ALTER PROCEDURE" with normalized "CREATE OR ALTER PROCEDURE"
            procBody = Regex.Replace(procBody, @"\bCREATE\s+(?:OR\s+ALTER\s+)?PROCEDURE\b", "CREATE OR ALTER PROCEDURE", RegexOptions.IgnoreCase, TimeSpan.FromSeconds(1));

            try
            {
                conn.Execute(procBody);
                applied++;
            }
            catch (Exception ex)
            {
                failed++;
                Log.Warning("[DB] Procedure apply skipped: {Error}", ex.Message.Split('\n')[0]);
            }
        }

        if (applied + failed > 0)
        {
            Log.Information("[DB] Procedures refreshed (CREATE OR ALTER). {Applied} applied, {Failed} skipped.", applied, failed);
        }
    }

    // Seed called only on fresh database
    private static void SeedInitialData(SqlConnection conn, string adminEmail, string adminPassword)
    {
        var orgCount = conn.ExecuteScalar<int>("SELECT COUNT(*) FROM organizations");
        if (orgCount > 0) return;

        // Insert default organization
        conn.Execute("INSERT INTO organizations (name, email) VALUES ('ProDesX HQ', 'hq@prodesx.com')");
        var orgId = conn.ExecuteScalar<int>("SELECT TOP 1 id FROM organizations ORDER BY id DESC");

        // Insert SuperAdmin (password from config)
        string passHash = BCrypt.Net.BCrypt.HashPassword(adminPassword);
        conn.Execute(@"
            INSERT INTO users (name, email, password_hash, role, organization_id)
            VALUES ('Super Admin', @Email, @Hash, 'SuperAdmin', @OrgId)",
            new { Email = adminEmail, Hash = passHash, OrgId = orgId });

        var superAdminId = conn.ExecuteScalar<int>("SELECT TOP 1 id FROM users ORDER BY id DESC");
        var superAdminRoleId = conn.ExecuteScalar<int>("SELECT RoleID FROM Roles WHERE RoleName = 'SuperAdmin'");

        // Give SuperAdmin an entry in UserOrganizationAccess for the home org
        conn.Execute(@"
            INSERT INTO UserOrganizationAccess (UserID, OrganizationID, RoleID, GrantedByID)
            VALUES (@UserId, @OrgId, @RoleId, @UserId)",
            new { UserId = superAdminId, OrgId = orgId, RoleId = superAdminRoleId });

        Log.Information("[DB] SuperAdmin ('{Email}') created and seeded from config.", adminEmail);
    }
}
