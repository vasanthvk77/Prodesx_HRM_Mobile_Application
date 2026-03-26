-- ============================================================
-- ProDesX-HRM Migrations
-- Runs on EXISTING databases only (fresh DBs use schema.sql).
-- Every block is wrapped in an IF NOT EXISTS check so it is
-- safe to run repeatedly on every app startup.
-- ============================================================

-- ── Migration 1: Roles table ─────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Roles')
BEGIN
    CREATE TABLE Roles (
        RoleID       INT IDENTITY(1,1) PRIMARY KEY,
        RoleName     NVARCHAR(100) NOT NULL UNIQUE,
        Description  NVARCHAR(255) NULL,
        IsSystemRole BIT DEFAULT 0,
        CreatedDate  DATETIME DEFAULT GETDATE(),
        CreatedBy    INT NULL,
        LastUpdatedBy INT NULL,
        created_at   DATETIME DEFAULT GETDATE(),
        updated_at   DATETIME DEFAULT GETDATE()
    );

    INSERT INTO Roles (RoleName, Description, IsSystemRole) VALUES
        ('SuperAdmin', 'Full unrestricted access to all organizations and features', 1),
        ('Admin',      'Can manage one or more assigned organizations',              1),
        ('User',       'Access limited to assigned organizations only',              0);

    PRINT '[Migration] Roles table created and seeded.';
END
ELSE
BEGIN
    PRINT '[Migration] Roles table already exists. Skipping.';
END
GO

-- ── Migration 2: UserOrganizationAccess table ─────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'UserOrganizationAccess')
BEGIN
    CREATE TABLE UserOrganizationAccess (
        AccessID       INT IDENTITY(1,1) PRIMARY KEY,
        UserID         INT NOT NULL,
        OrganizationID INT NOT NULL,
        RoleID         INT NOT NULL,
        GrantedByID    INT NULL,
        GrantedDate    DATETIME DEFAULT GETDATE(),
        IsActive       BIT DEFAULT 1,
        CreatedBy      INT NULL,
        LastUpdatedBy  INT NULL,
        created_at     DATETIME DEFAULT GETDATE(),
        updated_at     DATETIME DEFAULT GETDATE(),

        CONSTRAINT FK_UOA_User      FOREIGN KEY (UserID)         REFERENCES users(id)         ON DELETE CASCADE,
        CONSTRAINT FK_UOA_Org       FOREIGN KEY (OrganizationID) REFERENCES organizations(id) ON DELETE CASCADE,
        CONSTRAINT FK_UOA_Role      FOREIGN KEY (RoleID)         REFERENCES Roles(RoleID),
        CONSTRAINT FK_UOA_GrantedBy FOREIGN KEY (GrantedByID)    REFERENCES users(id),
        CONSTRAINT UQ_User_Org      UNIQUE (UserID, OrganizationID)
    );

    -- Seed all existing users into the access table based on their current role
    INSERT INTO UserOrganizationAccess (UserID, OrganizationID, RoleID, GrantedByID)
    SELECT
        u.id,
        u.organization_id,
        ISNULL(r.RoleID, (SELECT RoleID FROM Roles WHERE RoleName = 'User')),
        u.id   -- self-granted (migration)
    FROM users u
    LEFT JOIN Roles r ON r.RoleName = u.role
    WHERE u.organization_id IS NOT NULL;

    PRINT '[Migration] UserOrganizationAccess table created and existing users seeded.';
END
ELSE
BEGIN
    PRINT '[Migration] UserOrganizationAccess table already exists. Skipping.';
END
GO

-- ── Migration 21: employees table ─────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'employees')
BEGIN
    CREATE TABLE employees (
        id                  INT IDENTITY(1,1) PRIMARY KEY,
        user_id             INT NULL,
        organization_id     INT NOT NULL,
        employee_code       VARCHAR(50)    NULL,
        salutation          VARCHAR(10)    NULL,
        name                VARCHAR(255)   NOT NULL,
        email               VARCHAR(255)   NOT NULL,
        designation         VARCHAR(100)   NULL,
        gender              VARCHAR(20)    NULL,
        mobile              VARCHAR(30)    NULL,
        joining_date        DATE           NULL,
        date_of_birth       DATE           NULL,
        profile_picture_url NVARCHAR(MAX)  NULL,
        status              VARCHAR(20)    NOT NULL DEFAULT 'Active',
        
        -- New Hybrid Core Fields
        father_or_spouse      NVARCHAR(100)  NULL,
        present_address       NVARCHAR(255)  NULL,
        permanent_address     NVARCHAR(255)  NULL,
        employee_pf_no        NVARCHAR(50)   NULL,
        employee_esic_no      NVARCHAR(50)   NULL,
        employee_aadhar_no    NVARCHAR(20)   NULL,
        days_80_service_completion_date DATE NULL,
        permanent_appointment_date DATE       NULL,
        period_of_suspension  INT            NULL,
        signature_image_url   NVARCHAR(255)  NULL,
        thumb_impression_image_url NVARCHAR(255) NULL,
        date_of_exit          DATE           NULL,
        reason_for_exit       NVARCHAR(255)  NULL,
        remarks               NVARCHAR(255)  NULL,
        
        -- Dynamic Flex Column
        custom_fields_json    NVARCHAR(MAX)  NULL,
        
        created_at          DATETIME2      NOT NULL DEFAULT GETDATE(),
        updated_at          DATETIME2      NOT NULL DEFAULT GETDATE(),
        created_by          INT            NULL,
        last_updated_by     INT            NULL,

        CONSTRAINT FK_Employees_Users         FOREIGN KEY (user_id)         REFERENCES users(id) ON DELETE SET NULL,
        CONSTRAINT FK_Employees_Organizations FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
    );
    PRINT '[Migration] employees table created.';
END
ELSE
BEGIN
    PRINT '[Migration] employees table already exists. Skipping.';
END
GO

-- ── Migration XX: Emp_Mustorroll table ───────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Emp_Mustorroll')
BEGIN
    CREATE TABLE Emp_Mustorroll (
        id INT IDENTITY(1,1) PRIMARY KEY,
        organization_id INT NOT NULL,
        employee_id INT NOT NULL,

        woman_name NVARCHAR(255) NOT NULL,
        age INT NULL,
        husband_or_father_name NVARCHAR(255) NULL,
        nature_of_work NVARCHAR(255) NULL,
        date_of_employment DATE NULL,

        attendance_json NVARCHAR(MAX) NULL,

        notice_pregnancy_date DATE NULL,
        notice_delivery_date DATE NULL,
        proof_birth_date DATE NULL,
        proof_death_date DATE NULL,

        advance_amount DECIMAL(18,2) NULL,
        advance_date DATE NULL,
        subsequent_amount DECIMAL(18,2) NULL,
        subsequent_date DATE NULL,
        bonus_amount DECIMAL(18,2) NULL,
        leave_wages_sec9 DECIMAL(18,2) NULL,
        leave_wages_sec10 DECIMAL(18,2) NULL,
        remarks NVARCHAR(MAX) NULL,

        created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
        updated_at DATETIME2 NOT NULL DEFAULT GETDATE(),
        created_by INT NULL,
        last_updated_by INT NULL,

        CONSTRAINT FK_Mustorroll_Organizations FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
        -- Avoid "multiple cascade paths" in SQL Server (employees already cascades via organizations).
        CONSTRAINT FK_Mustorroll_Employees FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE NO ACTION
    );

    PRINT '[Migration] Emp_Mustorroll table created.';
END
ELSE
BEGIN
    PRINT '[Migration] Emp_Mustorroll table already exists. Skipping.';
END
GO

-- ── Migration: Add missing audit columns to deals table ──────────────────────
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'deals')
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('deals') AND name = 'updated_at')
    BEGIN
        ALTER TABLE deals ADD updated_at DATETIME DEFAULT GETDATE();
        PRINT '[Migration] Added updated_at column to deals table.';
    END
END
GO

-- ── Migration XX: Muster Roll stored procedures ──────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetMustorRolls
    @OrganizationId INT
AS
BEGIN
    SELECT
        mr.*,
        e.name AS employee_name,
        e.employee_code AS employee_code
    FROM Emp_Mustorroll mr
    INNER JOIN employees e ON e.id = mr.employee_id
    WHERE mr.organization_id = @OrganizationId
    ORDER BY mr.created_at DESC;
END;
GO

CREATE OR ALTER PROCEDURE sp_CreateMustorRoll
    @OrganizationId INT,
    @EmployeeId INT,
    @WomanName NVARCHAR(255),
    @Age INT = NULL,
    @HusbandOrFatherName NVARCHAR(255) = NULL,
    @NatureOfWork NVARCHAR(255) = NULL,
    @DateOfEmployment DATE = NULL,
    @AttendanceJson NVARCHAR(MAX) = NULL,
    @NoticePregnancyDate DATE = NULL,
    @NoticeDeliveryDate DATE = NULL,
    @ProofBirthDate DATE = NULL,
    @ProofDeathDate DATE = NULL,
    @AdvanceAmount DECIMAL(18,2) = NULL,
    @AdvanceDate DATE = NULL,
    @SubsequentAmount DECIMAL(18,2) = NULL,
    @SubsequentDate DATE = NULL,
    @BonusAmount DECIMAL(18,2) = NULL,
    @LeaveWagesSec9 DECIMAL(18,2) = NULL,
    @LeaveWagesSec10 DECIMAL(18,2) = NULL,
    @Remarks NVARCHAR(MAX) = NULL,
    @CreatedBy INT = NULL
AS
BEGIN
    INSERT INTO Emp_Mustorroll (
        organization_id, employee_id,
        woman_name, age, husband_or_father_name, nature_of_work, date_of_employment,
        attendance_json,
        notice_pregnancy_date, notice_delivery_date, proof_birth_date, proof_death_date,
        advance_amount, advance_date, subsequent_amount, subsequent_date,
        bonus_amount, leave_wages_sec9, leave_wages_sec10,
        remarks, created_at, updated_at, created_by, last_updated_by
    )
    VALUES (
        @OrganizationId, @EmployeeId,
        @WomanName, @Age, @HusbandOrFatherName, @NatureOfWork, @DateOfEmployment,
        @AttendanceJson,
        @NoticePregnancyDate, @NoticeDeliveryDate, @ProofBirthDate, @ProofDeathDate,
        @AdvanceAmount, @AdvanceDate, @SubsequentAmount, @SubsequentDate,
        @BonusAmount, @LeaveWagesSec9, @LeaveWagesSec10,
        @Remarks, GETDATE(), GETDATE(), @CreatedBy, @CreatedBy
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS id;
END;
GO

CREATE OR ALTER PROCEDURE sp_UpdateMustorRoll
    @Id INT,
    @OrganizationId INT,
    @EmployeeId INT,
    @WomanName NVARCHAR(255),
    @Age INT = NULL,
    @HusbandOrFatherName NVARCHAR(255) = NULL,
    @NatureOfWork NVARCHAR(255) = NULL,
    @DateOfEmployment DATE = NULL,
    @AttendanceJson NVARCHAR(MAX) = NULL,
    @NoticePregnancyDate DATE = NULL,
    @NoticeDeliveryDate DATE = NULL,
    @ProofBirthDate DATE = NULL,
    @ProofDeathDate DATE = NULL,
    @AdvanceAmount DECIMAL(18,2) = NULL,
    @AdvanceDate DATE = NULL,
    @SubsequentAmount DECIMAL(18,2) = NULL,
    @SubsequentDate DATE = NULL,
    @BonusAmount DECIMAL(18,2) = NULL,
    @LeaveWagesSec9 DECIMAL(18,2) = NULL,
    @LeaveWagesSec10 DECIMAL(18,2) = NULL,
    @Remarks NVARCHAR(MAX) = NULL,
    @LastUpdatedBy INT = NULL
AS
BEGIN
    UPDATE Emp_Mustorroll
    SET
        employee_id = @EmployeeId,
        woman_name = @WomanName,
        age = @Age,
        husband_or_father_name = @HusbandOrFatherName,
        nature_of_work = @NatureOfWork,
        date_of_employment = @DateOfEmployment,
        attendance_json = @AttendanceJson,
        notice_pregnancy_date = @NoticePregnancyDate,
        notice_delivery_date = @NoticeDeliveryDate,
        proof_birth_date = @ProofBirthDate,
        proof_death_date = @ProofDeathDate,
        advance_amount = @AdvanceAmount,
        advance_date = @AdvanceDate,
        subsequent_amount = @SubsequentAmount,
        subsequent_date = @SubsequentDate,
        bonus_amount = @BonusAmount,
        leave_wages_sec9 = @LeaveWagesSec9,
        leave_wages_sec10 = @LeaveWagesSec10,
        remarks = @Remarks,
        updated_at = GETDATE(),
        last_updated_by = @LastUpdatedBy
    WHERE id = @Id AND organization_id = @OrganizationId;

    SELECT @@ROWCOUNT AS rows_affected;
END;
GO

CREATE OR ALTER PROCEDURE sp_DeleteMustorRoll
    @Id INT,
    @OrganizationId INT
AS
BEGIN
    DELETE FROM Emp_Mustorroll WHERE id = @Id AND organization_id = @OrganizationId;
    SELECT @@ROWCOUNT AS rows_affected;
END;
GO

-- ── Migration 3: vw_UserAccess view ─────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.views WHERE name = 'vw_UserAccess')
BEGIN
    EXEC('
    CREATE VIEW vw_UserAccess AS
    SELECT
        u.id            AS UserID,
        u.name          AS UserName,
        u.email         AS Email,
        o.id            AS OrganizationID,
        o.name          AS OrganizationName,
        r.RoleName      AS Role,
        r.IsSystemRole,
        gb.name         AS GrantedByName,
        a.GrantedDate,
        a.IsActive
    FROM UserOrganizationAccess a
    JOIN users         u  ON u.id     = a.UserID
    JOIN organizations o  ON o.id     = a.OrganizationID
    JOIN Roles         r  ON r.RoleID = a.RoleID
    LEFT JOIN users    gb ON gb.id    = a.GrantedByID
    ');
    PRINT '[Migration] vw_UserAccess view created.';
END
ELSE
BEGIN
    PRINT '[Migration] vw_UserAccess view already exists. Skipping.';
END
GO

-- ── Migration 4: sp_GetUserOrganizations ─────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_GetUserOrganizations')
BEGIN
    EXEC('
    CREATE PROCEDURE sp_GetUserOrganizations
        @UserID INT
    AS
    BEGIN
        SELECT
            o.id            AS OrganizationID,
            o.name          AS OrganizationName,
            o.email         AS OrganizationEmail,
            r.RoleID,
            r.RoleName      AS Role,
            a.GrantedDate,
            a.IsActive
        FROM UserOrganizationAccess a
        JOIN organizations o ON o.id     = a.OrganizationID
        JOIN Roles         r ON r.RoleID = a.RoleID
        WHERE a.UserID = @UserID AND a.IsActive = 1
        ORDER BY o.name;
    END
    ');
    PRINT '[Migration] sp_GetUserOrganizations created.';
END
GO

-- ── Migration 5: sp_GrantOrgAccess ───────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_GrantOrgAccess')
BEGIN
    EXEC('
    CREATE PROCEDURE sp_GrantOrgAccess
        @UserID         INT,
        @OrganizationID INT,
        @RoleID         INT,
        @GrantedByID    INT
    AS
    BEGIN
        IF EXISTS (SELECT 1 FROM UserOrganizationAccess
                   WHERE UserID = @UserID AND OrganizationID = @OrganizationID)
        BEGIN
            UPDATE UserOrganizationAccess
            SET RoleID = @RoleID, IsActive = 1, GrantedByID = @GrantedByID, GrantedDate = GETDATE()
            WHERE UserID = @UserID AND OrganizationID = @OrganizationID;
        END
        ELSE
        BEGIN
            INSERT INTO UserOrganizationAccess (UserID, OrganizationID, RoleID, GrantedByID)
            VALUES (@UserID, @OrganizationID, @RoleID, @GrantedByID);
        END
    END
    ');
    PRINT '[Migration] sp_GrantOrgAccess created.';
END
GO

-- ── Migration 6: sp_RevokeOrgAccess ──────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_RevokeOrgAccess')
BEGIN
    EXEC('
    CREATE PROCEDURE sp_RevokeOrgAccess
        @UserID         INT,
        @OrganizationID INT
    AS
    BEGIN
        UPDATE UserOrganizationAccess
        SET IsActive = 0
        WHERE UserID = @UserID AND OrganizationID = @OrganizationID;
    END
    ');
    PRINT '[Migration] sp_RevokeOrgAccess created.';
END
GO

-- ── Migration 7: sp_GetAllUsersWithAccess ────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_GetAllUsersWithAccess')
BEGIN
    EXEC('
    CREATE PROCEDURE sp_GetAllUsersWithAccess
        @OrganizationID INT = NULL
    AS
    BEGIN
        SELECT
            u.id            AS UserID,
            u.name          AS UserName,
            u.email         AS Email,
            o.id            AS OrganizationID,
            o.name          AS OrganizationName,
            r.RoleName      AS Role,
            a.IsActive,
            a.GrantedDate
        FROM UserOrganizationAccess a
        JOIN users         u ON u.id     = a.UserID
        JOIN organizations o ON o.id     = a.OrganizationID
        JOIN Roles         r ON r.RoleID = a.RoleID
        WHERE (@OrganizationID IS NULL OR a.OrganizationID = @OrganizationID)
        ORDER BY o.name, r.RoleName, u.name;
    END
    ');
    PRINT '[Migration] sp_GetAllUsersWithAccess created.';
END
GO
-- ── Migration 8: sp_CreateOrganization ───────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_CreateOrganization')
BEGIN
    EXEC('
    CREATE PROCEDURE sp_CreateOrganization
        @Name VARCHAR(255), @Email VARCHAR(255) = NULL, @Phone VARCHAR(50) = NULL, @Address NVARCHAR(MAX) = NULL
    AS
    BEGIN
        INSERT INTO organizations (name, email, phone, address)
        OUTPUT INSERTED.id
        VALUES (@Name, @Email, @Phone, @Address);
    END
    ');
    PRINT '[Migration] sp_CreateOrganization created.';
END
GO

-- ── Migration 9: sp_CreateUser ──────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_CreateUser')
BEGIN
    EXEC('
    CREATE PROCEDURE sp_CreateUser
        @Name VARCHAR(255), @Email VARCHAR(255), @Hash NVARCHAR(MAX), @Role VARCHAR(50), @OrgId INT
    AS
    BEGIN
        INSERT INTO users (name, email, password_hash, role, organization_id)
        OUTPUT INSERTED.id
        VALUES (@Name, @Email, @Hash, @Role, @OrgId);
    END
    ');
    PRINT '[Migration] sp_CreateUser created.';
END
GO

-- ── Migration 10: sp_GetUserByEmail ────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_GetUserByEmail')
BEGIN
    EXEC('CREATE PROCEDURE sp_GetUserByEmail @Email VARCHAR(255) AS BEGIN SELECT * FROM users WHERE email = @Email; END');
    PRINT '[Migration] sp_GetUserByEmail created.';
END
GO

-- ── Migration 11: sp_GetAllRoles ───────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_GetAllRoles')
BEGIN
    EXEC('CREATE PROCEDURE sp_GetAllRoles AS BEGIN SELECT * FROM Roles ORDER BY RoleID; END');
    PRINT '[Migration] sp_GetAllRoles created.';
END
GO

-- ── Migration 12: sp_GetAllOrganizations ───────────────────
IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_GetAllOrganizations')
BEGIN
    EXEC('CREATE PROCEDURE sp_GetAllOrganizations AS BEGIN SELECT id, name, email FROM organizations ORDER BY name; END');
    PRINT '[Migration] sp_GetAllOrganizations created.';
END
GO

-- ── Migration 13: sp_CheckOrganizationExists ───────────────
IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_CheckOrganizationExists')
BEGIN
    EXEC('CREATE PROCEDURE sp_CheckOrganizationExists @Name VARCHAR(255) AS BEGIN SELECT COUNT(*) FROM organizations WHERE name = @Name; END');
    PRINT '[Migration] sp_CheckOrganizationExists created.';
END
GO

-- ── Migration 14: sp_CheckUserEmailExists ──────────────────
IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_CheckUserEmailExists')
BEGIN
    EXEC('CREATE PROCEDURE sp_CheckUserEmailExists @Email VARCHAR(255) AS BEGIN SELECT COUNT(*) FROM users WHERE email = @Email; END');
    PRINT '[Migration] sp_CheckUserEmailExists created.';
END
GO

-- ── Migration 15: sp_GetRoleIdByName ───────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_GetRoleIdByName')
BEGIN
    EXEC('CREATE PROCEDURE sp_GetRoleIdByName @RoleName NVARCHAR(100) AS BEGIN SELECT RoleID FROM Roles WHERE RoleName = @RoleName; END');
    PRINT '[Migration] sp_GetRoleIdByName created.';
END
GO

-- ── Migration 16: sp_GetUserById ───────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_GetUserById')
BEGIN
    EXEC('CREATE PROCEDURE sp_GetUserById @Id INT AS BEGIN SELECT * FROM users WHERE id = @Id; END');
    PRINT '[Migration] sp_GetUserById created.';
END
GO

-- ── Migration 17: sp_DeleteUser ────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_DeleteUser')
BEGIN
    EXEC('CREATE PROCEDURE sp_DeleteUser @Id INT AS BEGIN DELETE FROM users WHERE id = @Id; END');
    PRINT '[Migration] sp_DeleteUser created.';
END
GO

-- ── Migration 18: sp_GetAllDeals ───────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_GetAllDeals')
BEGIN
    EXEC('CREATE PROCEDURE sp_GetAllDeals @OrganizationId INT AS BEGIN SELECT deal_id AS DealId, organization_id AS OrganizationId, lead_contact_name AS LeadContactName, lead_email AS LeadEmail, lead_phone AS LeadPhone, deal_name AS DealName, pipeline AS Pipeline, deal_stage AS DealStage, deal_value AS DealValue, close_date AS CloseDate, deal_category AS DealCategory, products AS Products, deal_agent AS DealAgent, deal_watcher AS DealWatcher, created_at AS CreatedAt, updated_at AS UpdatedAt, created_by AS CreatedBy, last_updated_by AS LastUpdatedBy FROM deals WHERE organization_id = @OrganizationId ORDER BY created_at DESC; END');
    PRINT '[Migration] sp_GetAllDeals created.';
END
GO

-- ── Migration 19: sp_UpdateDeal ────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_UpdateDeal')
BEGIN
    EXEC('
    CREATE PROCEDURE sp_UpdateDeal
        @Id INT,
        @OrganizationId INT,
        @LeadName VARCHAR(150),
        @LeadEmail VARCHAR(255) = NULL,
        @LeadPhone VARCHAR(50) = NULL,
        @DealName VARCHAR(150),
        @Pipeline VARCHAR(100),
        @Stage VARCHAR(50),
        @Value DECIMAL(18,2),
        @CloseDate DATE,
        @Category VARCHAR(100) = NULL, 
        @Products VARCHAR(500) = NULL, 
        @Agent VARCHAR(100) = NULL, 
        @Watcher VARCHAR(100) = NULL,
        @LastUpdatedBy INT = NULL
    AS
    BEGIN
        UPDATE deals SET lead_contact_name = @LeadName, lead_email = @LeadEmail, lead_phone = @LeadPhone,
            deal_name = @DealName, pipeline = @Pipeline, deal_stage = @Stage, deal_value = @Value,
            close_date = @CloseDate, deal_category = @Category, products = @Products,
            deal_agent = @Agent, deal_watcher = @Watcher, updated_at = GETDATE(), last_updated_by = @LastUpdatedBy
        WHERE deal_id = @Id AND organization_id = @OrganizationId;
    END
    ');
    PRINT '[Migration] sp_UpdateDeal created.';
END
GO

-- ── Migration 20: sp_DeleteDeal ────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_DeleteDeal')
BEGIN
    EXEC('CREATE PROCEDURE sp_DeleteDeal @Id INT, @OrganizationId INT AS BEGIN DELETE FROM deals WHERE deal_id = @Id AND organization_id = @OrganizationId; END');
    PRINT '[Migration] sp_DeleteDeal created.';
END
GO

-- ── Migration 22: sp_CreateEmployee ────────────────────────────────────────────
-- Consolidated at the bottom of the migrations file to support new schema layout.

GO

-- ── Migration 24: sp_GetUnlinkedUsers ──────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_GetUnlinkedUsers')
BEGIN
    EXEC('
    CREATE PROCEDURE sp_GetUnlinkedUsers
        @OrganizationId INT
    AS
    BEGIN
        SELECT u.id, u.name, u.email
        FROM users u
        LEFT JOIN employees e ON e.user_id = u.id AND e.organization_id = @OrganizationId
        WHERE (
            u.organization_id = @OrganizationId
            OR EXISTS (
                SELECT 1 FROM UserOrganizationAccess a
                WHERE a.UserID = u.id AND a.OrganizationID = @OrganizationId AND a.IsActive = 1
            )
        )
        AND e.id IS NULL
        ORDER BY u.name;
    END
    ');
    PRINT '[Migration] sp_GetUnlinkedUsers created.';
END
GO

-- ── Migration 25: sp_DeleteEmployee ────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_DeleteEmployee')
BEGIN
    EXEC('CREATE PROCEDURE sp_DeleteEmployee @Id INT, @OrganizationId INT AS BEGIN DELETE FROM employees WHERE id = @Id AND organization_id = @OrganizationId; END');
    PRINT '[Migration] sp_DeleteEmployee created.';
END
GO


-- ── Migration 27: sp_GetEmployees (v2) ───────────────────────────────
-- Consolidated at the bottom of the migrations file to support new schema layout.

-- ── Migration 26 (Revised): sp_CreateEmployee (v3) ───────────────────────
-- Consolidated at the bottom of the migrations file to support new schema layout.

-- ── Migration 29: sp_UpdateEmployee ──────────────────────────────────────────
-- Consolidated at the bottom of the migrations file to support new schema layout.

-- ── Migration 25: UserOtps table ──────────────────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'UserOtps')
BEGIN
    CREATE TABLE UserOtps (
        id          INT IDENTITY(1,1) PRIMARY KEY,
        email       VARCHAR(255) NOT NULL,
        otp_code    VARCHAR(10)  NOT NULL,
        expiry_time DATETIME     NOT NULL,
        is_used     BIT          DEFAULT 0,
        created_at  DATETIME     DEFAULT GETDATE(),
        created_by  INT NULL,
        last_updated_by INT NULL
    );
    PRINT '[Migration] UserOtps table created.';
END
GO

-- ── Migration 26: sp_UpsertUserOtp ───────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_UpsertUserOtp
    @Email VARCHAR(255),
    @OtpCode VARCHAR(10),
    @ExpiryMinutes INT = 10
AS
BEGIN
    -- Disable old OTPs for this email
    UPDATE UserOtps SET is_used = 1 WHERE email = @Email AND is_used = 0;

    -- Insert new OTP
    INSERT INTO UserOtps (email, otp_code, expiry_time)
    VALUES (@Email, @OtpCode, DATEADD(MINUTE, @ExpiryMinutes, GETDATE()));
END
GO

-- ── Migration 27: sp_VerifyOtp ───────────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_VerifyOtp
    @Email VARCHAR(255),
    @OtpCode VARCHAR(10)
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM UserOtps 
        WHERE email = @Email 
          AND otp_code = @OtpCode 
          AND is_used = 0 
          AND expiry_time > GETDATE()
    )
    BEGIN
        SELECT 1 AS Success;
        UPDATE UserOtps SET is_used = 1 WHERE email = @Email AND otp_code = @OtpCode;
    END
    ELSE
    BEGIN
        SELECT 0 AS Success;
    END
END
GO

-- ── Migration 28: sp_UpdatePassword ─────────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_UpdatePassword
    @Email VARCHAR(255),
    @PasswordHash NVARCHAR(MAX)
AS
BEGIN
    UPDATE users SET password_hash = @PasswordHash, updated_at = GETDATE()
    WHERE email = @Email;
END
GO

-- ── Migration 29: UserLoginSessions table ──────────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'UserLoginSessions')
BEGIN
    CREATE TABLE UserLoginSessions (
        id INT IDENTITY(1,1) PRIMARY KEY,
        user_id INT NOT NULL,
        organization_id INT NOT NULL,
        user_name NVARCHAR(255) NOT NULL,
        last_session_at DATETIME DEFAULT GETDATE(),
        token_expiry_at DATETIME NULL,
        is_active BIT DEFAULT 1,
        created_at DATETIME DEFAULT GETDATE(),
        updated_at DATETIME DEFAULT GETDATE(),
        
        CONSTRAINT FK_USL_Users FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        CONSTRAINT FK_USL_Organizations FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
        CONSTRAINT UQ_UserLoginSessions_UserId UNIQUE (user_id)
    );
    PRINT '[Migration] UserLoginSessions table created.';
END
GO

-- ── Migration 29a: sp_UpsertUserLoginSession ────────────────────────────────
CREATE OR ALTER PROCEDURE sp_UpsertUserLoginSession
    @UserId INT,
    @OrganizationId INT,
    @UserName NVARCHAR(255),
    @TokenExpiryAt DATETIME = NULL
AS
BEGIN
    IF EXISTS (SELECT 1 FROM UserLoginSessions WHERE user_id = @UserId)
    BEGIN
        -- Update existing session
        UPDATE UserLoginSessions 
        SET last_session_at = GETDATE(), 
            token_expiry_at = @TokenExpiryAt,
            is_active = 1,
            updated_at = GETDATE()
        WHERE user_id = @UserId;
    END
    ELSE
    BEGIN
        -- Insert new session
        INSERT INTO UserLoginSessions (user_id, organization_id, user_name, last_session_at, token_expiry_at, is_active, created_at, updated_at)
        VALUES (@UserId, @OrganizationId, @UserName, GETDATE(), @TokenExpiryAt, 1, GETDATE(), GETDATE());
    END
END
GO

-- ── Migration 29b: sp_GetUserLoginSessions ────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_GetUserLoginSessions
    @OrganizationId INT = NULL
AS
BEGIN
    SELECT 
        id AS Id,
        user_id AS UserId,
        organization_id AS OrganizationId,
        user_name AS UserName,
        last_session_at AS LastSessionAt,
        is_active AS IsActive,
        created_at AS CreatedAt,
        updated_at AS UpdatedAt
    FROM UserLoginSessions
    WHERE (@OrganizationId IS NULL OR organization_id = @OrganizationId)
    ORDER BY last_session_at DESC;
END
GO

-- ── Migration 29c: sp_LogoutUserSession ───────────────────────────────────────
CREATE OR ALTER PROCEDURE sp_LogoutUserSession
    @UserId INT
AS
BEGIN
    UPDATE UserLoginSessions 
    SET is_active = 0,
        updated_at = GETDATE()
    WHERE user_id = @UserId;
END
GO

-- ── Migration 29d: sp_CheckAndUpdateExpiredSessions ──────────────────────────────
CREATE OR ALTER PROCEDURE sp_CheckAndUpdateExpiredSessions
AS
BEGIN
    -- Mark sessions with expired tokens as inactive
    UPDATE UserLoginSessions 
    SET is_active = 0,
        updated_at = GETDATE()
    WHERE is_active = 1 
    AND token_expiry_at IS NOT NULL
    AND token_expiry_at < GETDATE();
    
    SELECT @@ROWCOUNT AS ExpiredSessionsMarked;
END
GO


-- ── Migration 30: Shift Management ───────────────────────────

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ShiftTemplates')
BEGIN
    CREATE TABLE ShiftTemplates (
        Id INT PRIMARY KEY IDENTITY(1,1),
        OrganizationId INT NOT NULL,
        ShiftName NVARCHAR(100) NOT NULL,
        ShiftType NVARCHAR(50) NOT NULL,
        StartTime TIME NOT NULL,
        EndTime TIME NOT NULL,
        UnpaidBreak INT NOT NULL DEFAULT 0,
        TotalShiftHours NVARCHAR(10) NOT NULL,
        EarliestPunchIn TIME NULL,
        LatestPunchOut TIME NULL,
        LateGracePeriod INT NOT NULL DEFAULT 0,
        EarlyGracePeriod INT NOT NULL DEFAULT 0,
        CreatedAt DATETIME DEFAULT GETDATE(),
        UpdatedAt DATETIME DEFAULT GETDATE(),
        CreatedBy INT NULL,
        LastUpdatedBy INT NULL,
        CONSTRAINT FK_ShiftTemplates_Organizations FOREIGN KEY (OrganizationId) REFERENCES organizations(id)
    );
    PRINT '[Migration] ShiftTemplates table created.';
END
GO


-- Standardized ShiftAssignments Table and Procedures (Migration)
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ShiftAssignments')
BEGIN
    CREATE TABLE ShiftAssignments (
        id INT PRIMARY KEY IDENTITY(1,1),
        organization_id INT NOT NULL,
        employee_id INT NOT NULL,
        template_id INT NULL,
        shift_name NVARCHAR(100) NULL,
        shift_type NVARCHAR(50) NULL,
        start_time TIME NOT NULL,
        end_time TIME NOT NULL,
        unpaid_break INT NOT NULL DEFAULT 0,
        total_shift_hours NVARCHAR(10) NOT NULL,
        earliest_punch_in TIME NULL,
        latest_punch_out TIME NULL,
        late_grace_period INT NOT NULL DEFAULT 0,
        early_grace_period INT NOT NULL DEFAULT 0,
        work_days NVARCHAR(200) NULL,
        start_date DATE NULL,
        end_date DATE NULL,
        assignment_type INT NOT NULL DEFAULT 3,
        specific_dates NVARCHAR(MAX) NULL,
        remarks NVARCHAR(MAX) NULL,
        created_at DATETIME DEFAULT GETDATE(),
        updated_at DATETIME DEFAULT GETDATE(),
        created_by INT NULL,
        last_updated_by INT NULL,
        CONSTRAINT FK_ShiftAssignments_Organizations FOREIGN KEY (organization_id) REFERENCES organizations(id),
        CONSTRAINT FK_ShiftAssignments_Employees FOREIGN KEY (employee_id) REFERENCES employees(id),
        CONSTRAINT FK_ShiftAssignments_Templates FOREIGN KEY (template_id) REFERENCES ShiftTemplates(id)
    );
    CREATE INDEX IX_ShiftAssignments_Employee ON ShiftAssignments(employee_id);
    CREATE INDEX IX_ShiftTemplates_Org ON ShiftTemplates(organization_id);
    PRINT '[Migration] ShiftAssignments table and indexes created.';
END
GO

CREATE OR ALTER PROCEDURE sp_UpsertShiftAssignment
    @organization_id INT,
    @employee_id INT,
    @template_id INT = NULL,
    @shift_name NVARCHAR(100),
    @shift_type NVARCHAR(50),
    @start_time TIME,
    @end_time TIME,
    @unpaid_break INT,
    @total_shift_hours NVARCHAR(10),
    @earliest_punch_in TIME = NULL,
    @latest_punch_out TIME = NULL,
    @late_grace_period INT = 0,
    @early_grace_period INT = 0,
    @work_days NVARCHAR(200) = NULL,
    @start_date DATE = NULL,
    @end_date DATE = NULL,
    @assignment_type INT = 3,
    @specific_dates NVARCHAR(MAX) = NULL,
    @remarks NVARCHAR(MAX) = NULL,
    @created_by INT = NULL,
    @last_updated_by INT = NULL
AS
BEGIN
    DELETE FROM ShiftAssignments WHERE employee_id = @employee_id AND organization_id = @organization_id;
    INSERT INTO ShiftAssignments (
        organization_id, employee_id, template_id, shift_name, shift_type, 
        start_time, end_time, unpaid_break, total_shift_hours, earliest_punch_in, 
        latest_punch_out, late_grace_period, early_grace_period,
        work_days, start_date, end_date, assignment_type, specific_dates, remarks,
        created_by, last_updated_by, created_at, updated_at
    ) VALUES (
        @organization_id, @employee_id, @template_id, @shift_name, @shift_type, 
        @start_time, @end_time, @unpaid_break, @total_shift_hours, @earliest_punch_in, 
        @latest_punch_out, @late_grace_period, @early_grace_period,
        @work_days, @start_date, @end_date, @assignment_type, @specific_dates, @remarks,
        @created_by, @last_updated_by, GETDATE(), GETDATE()
    );
END;
GO

CREATE OR ALTER PROCEDURE sp_DeleteShiftAssignment
    @employee_id INT,
    @organization_id INT
AS
BEGIN
    DELETE FROM ShiftAssignments WHERE employee_id = @employee_id AND organization_id = @organization_id;
END;
GO
GO

-- ── Migration 34: Daily Shift Roster ──────────────────────────

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'EmployeeSchedules')
BEGIN
    CREATE TABLE EmployeeSchedules (
        Id INT PRIMARY KEY IDENTITY(1,1),
        OrganizationId INT NOT NULL,
        EmployeeId INT NOT NULL,
        Date DATE NOT NULL,
        
        -- Timing details (Full shift details stored per day)
        ShiftName NVARCHAR(100) NULL,
        ShiftType NVARCHAR(50) NULL,
        StartTime TIME NOT NULL,                   -- UTC
        EndTime TIME NOT NULL,                     -- UTC
        UnpaidBreak INT NOT NULL DEFAULT 0,
        TotalShiftHours NVARCHAR(10) NOT NULL,
        EarliestPunchIn TIME NULL,
        LatestPunchOut TIME NULL,
        LateGracePeriod INT NOT NULL DEFAULT 0,
        EarlyGracePeriod INT NOT NULL DEFAULT 0,
        
        IsOverride BIT DEFAULT 0,                  -- 1 if manually changed
        SourceAssignmentId INT NULL,               -- Link to the recurring rule
        
        CreatedAt DATETIME DEFAULT GETDATE(),
        UpdatedAt DATETIME DEFAULT GETDATE(),
        CreatedBy INT NULL,
        LastUpdatedBy INT NULL,
        
        CONSTRAINT FK_EmployeeSchedules_Organizations FOREIGN KEY (OrganizationId) REFERENCES organizations(id),
        CONSTRAINT FK_EmployeeSchedules_Employees FOREIGN KEY (EmployeeId) REFERENCES employees(id),
        CONSTRAINT UQ_Employee_Date UNIQUE (EmployeeId, Date)
    );
    CREATE INDEX IX_EmployeeSchedules_Date ON EmployeeSchedules(Date);
    PRINT '[Migration] EmployeeSchedules table created.';
END
GO

GO
CREATE OR ALTER PROCEDURE sp_GetEmployeeSchedules
    @OrganizationId INT,
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SELECT 
        s.Id, s.OrganizationId, s.EmployeeId, s.Date,
        s.ShiftName, s.ShiftType,
        CONVERT(VARCHAR(5), s.StartTime, 108)       AS StartTime,
        CONVERT(VARCHAR(5), s.EndTime, 108)         AS EndTime,
        s.UnpaidBreak, s.TotalShiftHours,
        CONVERT(VARCHAR(5), s.EarliestPunchIn, 108) AS EarliestPunchIn,
        CONVERT(VARCHAR(5), s.LatestPunchOut, 108)  AS LatestPunchOut,
        s.LateGracePeriod, s.EarlyGracePeriod,
        s.IsOverride, s.SourceAssignmentId,
        s.CreatedAt, s.UpdatedAt,
        e.name AS EmployeeName,
        e.employee_code AS EmployeeCode
    FROM EmployeeSchedules s
    JOIN employees e ON s.EmployeeId = e.id
    WHERE s.OrganizationId = @OrganizationId 
      AND s.Date >= @StartDate 
      AND s.Date <= @EndDate
    ORDER BY s.Date, e.name;
END;
GO

GO
CREATE OR ALTER PROCEDURE sp_UpsertEmployeeSchedule
    @OrganizationId INT,
    @EmployeeId INT,
    @Date DATE,
    @ShiftName NVARCHAR(100),
    @ShiftType NVARCHAR(50),
    @StartTime TIME,
    @EndTime TIME,
    @UnpaidBreak INT,
    @TotalShiftHours NVARCHAR(10),
    @EarliestPunchIn TIME = NULL,
    @LatestPunchOut TIME = NULL,
    @LateGracePeriod INT = 0,
    @EarlyGracePeriod INT = 0,
    @IsOverride BIT = 0,
    @SourceAssignmentId INT = NULL
AS
BEGIN
    IF EXISTS (SELECT 1 FROM EmployeeSchedules WHERE EmployeeId = @EmployeeId AND Date = @Date)
    BEGIN
        UPDATE EmployeeSchedules SET
            ShiftName = @ShiftName,
            ShiftType = @ShiftType,
            StartTime = @StartTime,
            EndTime = @EndTime,
            UnpaidBreak = @UnpaidBreak,
            TotalShiftHours = @TotalShiftHours,
            EarliestPunchIn = @EarliestPunchIn,
            LatestPunchOut = @LatestPunchOut,
            LateGracePeriod = @LateGracePeriod,
            EarlyGracePeriod = @EarlyGracePeriod,
            IsOverride = @IsOverride,
            SourceAssignmentId = @SourceAssignmentId,
            UpdatedAt = GETDATE()
        WHERE EmployeeId = @EmployeeId AND Date = @Date;
    END
    ELSE
    BEGIN
        INSERT INTO EmployeeSchedules (
            OrganizationId, EmployeeId, Date, ShiftName, ShiftType,
            StartTime, EndTime, UnpaidBreak, TotalShiftHours,
            EarliestPunchIn, LatestPunchOut, LateGracePeriod, EarlyGracePeriod,
            IsOverride, SourceAssignmentId
        ) VALUES (
            @OrganizationId, @EmployeeId, @Date, @ShiftName, @ShiftType,
            @StartTime, @EndTime, @UnpaidBreak, @TotalShiftHours,
            @EarliestPunchIn, @LatestPunchOut, @LateGracePeriod, @EarlyGracePeriod,
            @IsOverride, @SourceAssignmentId
        );
    END
END;
GO

-- ── Migration 31: Hybrid Dynamic Fields ─────────────────────────
-- Tables
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'employee_data_fields')
BEGIN
    CREATE TABLE employee_data_fields (
        id INT IDENTITY(1,1) PRIMARY KEY,
        field_key NVARCHAR(50) NOT NULL UNIQUE,
        display_label NVARCHAR(100) NOT NULL,
        section_name NVARCHAR(50) NOT NULL,
        section_order INT DEFAULT 0,
        field_order INT DEFAULT 0,
        grid_size INT DEFAULT 6,
        component_type NVARCHAR(50) NOT NULL, 
        options_json NVARCHAR(MAX) NULL,
        is_core_field BIT DEFAULT 0,
        created_at DATETIME DEFAULT GETDATE(),
        updated_at DATETIME DEFAULT GETDATE(),
        created_by INT NULL,
        last_updated_by INT NULL
    );
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'emp_data_use_fields')
BEGIN
    CREATE TABLE emp_data_use_fields (
        id INT IDENTITY(1,1) PRIMARY KEY,
        organization_id INT NOT NULL,
        field_id INT NOT NULL,
        is_visible BIT DEFAULT 1,
        is_mandatory BIT DEFAULT 0,
        custom_label NVARCHAR(100) NULL,
        created_at DATETIME DEFAULT GETDATE(),
        updated_at DATETIME DEFAULT GETDATE(),
        created_by INT NULL,
        last_updated_by INT NULL,
        FOREIGN KEY (field_id) REFERENCES employee_data_fields(id),
        FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
    );
END
GO
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'employee_account_details')
BEGIN
    CREATE TABLE employee_account_details (
        id INT IDENTITY(1,1) PRIMARY KEY,
        employee_id INT NOT NULL,
        organization_id INT NOT NULL,
        account_number BIGINT NULL,
        account_holder_name VARCHAR(100) NULL,
        branch VARCHAR(100) NULL,
        ifsc VARCHAR(20) NULL,
        created_at DATETIME DEFAULT GETDATE(),
        updated_at DATETIME DEFAULT GETDATE(),
        created_by INT NULL,
        last_updated_by INT NULL,
        FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
        FOREIGN KEY (organization_id) REFERENCES organizations(id)
    );
END
GO

-- Drop procedures first to break metadata dependencies
DROP PROCEDURE IF EXISTS sp_GetEmployees;
DROP PROCEDURE IF EXISTS sp_CreateEmployee;
DROP PROCEDURE IF EXISTS sp_UpdateEmployee;
GO

-- Drop Constraints & Foreign Keys on obsolete columns
DECLARE @const_name NVARCHAR(MAX);
DECLARE @const_sql NVARCHAR(MAX);

-- 1. Drop Default Constraints
DECLARE const_cursor CURSOR FOR 
SELECT d.name 
FROM sys.default_constraints d
JOIN sys.columns c ON d.parent_column_id = c.column_id AND d.parent_object_id = c.object_id
WHERE d.parent_object_id = OBJECT_ID('employees') 
AND c.name IN ('email_notifications', 'login_allowed', 'business_address', 'skills', 'slack_member_id', 'hourly_rate', 'notice_period_end', 'notice_period_start', 'probation_end_date', 'marital_status', 'employment_type', 'language', 'reporting_to', 'about', 'address', 'country', 'department');

OPEN const_cursor;
FETCH NEXT FROM const_cursor INTO @const_name;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @const_sql = 'ALTER TABLE employees DROP CONSTRAINT ' + QUOTENAME(@const_name);
    EXEC (@const_sql);
    FETCH NEXT FROM const_cursor INTO @const_name;
END
CLOSE const_cursor;
DEALLOCATE const_cursor;

-- 2. Drop Foreign Keys on obsolete columns
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Employees_ReportingTo')
    ALTER TABLE employees DROP CONSTRAINT FK_Employees_ReportingTo;
GO

-- Employee Columns Addition
DECLARE @cols NVARCHAR(MAX) = '';
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'father_or_spouse') SET @cols += 'father_or_spouse NVARCHAR(100) NULL,'
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'present_address') SET @cols += 'present_address NVARCHAR(255) NULL,'
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'permanent_address') SET @cols += 'permanent_address NVARCHAR(255) NULL,'
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'employee_pf_no') SET @cols += 'employee_pf_no NVARCHAR(50) NULL,'
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'employee_esic_no') SET @cols += 'employee_esic_no NVARCHAR(50) NULL,'
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'employee_aadhar_no') SET @cols += 'employee_aadhar_no NVARCHAR(20) NULL,'
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'days_80_service_completion_date') SET @cols += 'days_80_service_completion_date DATE NULL,'
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'permanent_appointment_date') SET @cols += 'permanent_appointment_date DATE NULL,'
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'period_of_suspension') SET @cols += 'period_of_suspension INT NULL,'
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'signature_image_url') SET @cols += 'signature_image_url NVARCHAR(255) NULL,'
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'thumb_impression_image_url') SET @cols += 'thumb_impression_image_url NVARCHAR(255) NULL,'
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'date_of_exit') SET @cols += 'date_of_exit DATE NULL,'
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'reason_for_exit') SET @cols += 'reason_for_exit NVARCHAR(255) NULL,'
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'remarks') SET @cols += 'remarks NVARCHAR(255) NULL,'
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'custom_fields_json') SET @cols += 'custom_fields_json NVARCHAR(MAX) NULL,'

IF @cols <> ''
BEGIN
    SET @cols = 'ALTER TABLE employees ADD ' + LEFT(@cols, LEN(@cols) - 1);
    EXEC sp_executesql @cols;
END
GO

-- Employee Columns Dropping (Obsolete)
-- We use a cursor or separate EXEC to avoid batch compilation issues if columns are already gone
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'country') ALTER TABLE employees DROP COLUMN country;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'department') ALTER TABLE employees DROP COLUMN department;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'reporting_to') ALTER TABLE employees DROP COLUMN reporting_to;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'language') ALTER TABLE employees DROP COLUMN language;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'employment_type') ALTER TABLE employees DROP COLUMN employment_type;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'marital_status') ALTER TABLE employees DROP COLUMN marital_status;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'probation_end_date') ALTER TABLE employees DROP COLUMN probation_end_date;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'notice_period_start') ALTER TABLE employees DROP COLUMN notice_period_start;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'notice_period_end') ALTER TABLE employees DROP COLUMN notice_period_end;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'hourly_rate') ALTER TABLE employees DROP COLUMN hourly_rate;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'slack_member_id') ALTER TABLE employees DROP COLUMN slack_member_id;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'skills') ALTER TABLE employees DROP COLUMN skills;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'login_allowed') ALTER TABLE employees DROP COLUMN login_allowed;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'email_notifications') ALTER TABLE employees DROP COLUMN email_notifications;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'business_address') ALTER TABLE employees DROP COLUMN business_address;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'about') ALTER TABLE employees DROP COLUMN about;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'address') ALTER TABLE employees DROP COLUMN address;
GO

-- ── Migration 27: sp_GetEmployees ───────────────────────────────
GO
CREATE OR ALTER PROCEDURE sp_GetEmployees 
    @OrganizationId INT 
AS
BEGIN
    SELECT * FROM employees WHERE organization_id = @OrganizationId ORDER BY created_at DESC;
END;
GO

-- ── Migration 26/29: sp_CreateEmployee & sp_UpdateEmployee ────────
-- (Moved to final versions below to avoid duplication)
GO
GO

-- ── Migration 32: Additional Employee & Dynamic Form SPs ──────────
CREATE OR ALTER PROCEDURE sp_OrganizationExistsById @OrgId INT AS
BEGIN
    SELECT COUNT(*) FROM organizations WHERE id = @OrgId;
END;
GO

CREATE OR ALTER PROCEDURE sp_GetEmployeeById @Id INT, @OrganizationId INT = NULL AS
BEGIN
    SELECT * FROM employees WHERE id = @Id AND (@OrganizationId IS NULL OR organization_id = @OrganizationId);
END;
GO

CREATE OR ALTER PROCEDURE sp_UpdateEmployeePhoto @Id INT, @Url NVARCHAR(MAX) = NULL AS
BEGIN
    UPDATE employees SET profile_picture_url = @Url, updated_at = GETDATE() WHERE id = @Id;
END;
GO

CREATE OR ALTER PROCEDURE sp_GetEmployeeAccountDetails @EmployeeId INT AS
BEGIN
    SELECT 
        id as Id,
        employee_id as EmployeeId,
        organization_id as OrganizationId,
        account_number as AccountNumber,
        account_holder_name as AccountHolderName,
        branch as Branch,
        ifsc as Ifsc,
        created_at as CreatedAt,
        updated_at as UpdatedAt,
        created_by as CreatedBy,
        last_updated_by as LastUpdatedBy
    FROM employee_account_details 
    WHERE employee_id = @EmployeeId;
END;
GO

CREATE OR ALTER PROCEDURE sp_UpsertEmployeeAccountDetails
    @EmployeeId INT,
    @OrganizationId INT,
    @AccountNumber BIGINT,
    @AccountHolderName VARCHAR(100),
    @Branch VARCHAR(100),
    @Ifsc VARCHAR(20),
    @CreatedBy INT = NULL,
    @LastUpdatedBy INT = NULL
AS
BEGIN
    MERGE INTO employee_account_details AS target
    USING (SELECT @EmployeeId AS eid, @OrganizationId AS oid) AS source
    ON target.employee_id = source.eid
    WHEN MATCHED THEN
        UPDATE SET account_number = @AccountNumber, account_holder_name = @AccountHolderName, branch = @Branch, ifsc = @Ifsc, updated_at = GETDATE(), last_updated_by = @LastUpdatedBy
    WHEN NOT MATCHED THEN
        INSERT (employee_id, organization_id, account_number, account_holder_name, branch, ifsc, created_at, updated_at, created_by, last_updated_by)
        VALUES (@EmployeeId, @OrganizationId, @AccountNumber, @AccountHolderName, @Branch, @Ifsc, GETDATE(), GETDATE(), @CreatedBy, @LastUpdatedBy);
END;
GO

CREATE OR ALTER PROCEDURE sp_UpdateEmployeeSignature @Id INT, @Url NVARCHAR(MAX) = NULL AS
BEGIN
    UPDATE employees SET signature_image_url = @Url, updated_at = GETDATE() WHERE id = @Id;
END;
GO

CREATE OR ALTER PROCEDURE sp_GetEmployeeFormFields @OrgId INT AS
BEGIN
    SELECT f.id, f.field_key, f.display_label, f.section_name, f.section_order, f.field_order,
        f.grid_size, f.component_type, f.options_json,
        CAST(COALESCE(a.is_visible, 1) AS INT) as IsVisible, CAST(COALESCE(a.is_mandatory, 0) AS INT) as IsMandatory, 
        COALESCE(a.custom_label, f.display_label) as CustomLabel, CAST(f.is_core_field AS INT) as IsCoreField
    FROM employee_data_fields f
    LEFT JOIN emp_data_use_fields a ON f.id = a.field_id AND a.organization_id = @OrgId
    ORDER BY f.section_order, f.field_order;
END;
GO

CREATE OR ALTER PROCEDURE sp_UpsertEmployeeFieldSetting
    @OrgId INT,
    @FieldId INT,
    @IsVisible BIT,
    @IsMandatory BIT,
    @LastUpdatedBy INT = NULL
AS
BEGIN
    UPDATE emp_data_use_fields 
    SET is_visible = @IsVisible, is_mandatory = @IsMandatory, updated_at = GETDATE(), last_updated_by = @LastUpdatedBy
    WHERE organization_id = @OrgId AND field_id = @FieldId;

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO emp_data_use_fields (organization_id, field_id, is_visible, is_mandatory, created_at, updated_at, created_by, last_updated_by)
        VALUES (@OrgId, @FieldId, @IsVisible, @IsMandatory, GETDATE(), GETDATE(), @LastUpdatedBy, @LastUpdatedBy);
    END
END;
GO

CREATE OR ALTER PROCEDURE sp_CheckFieldKeyExists @FieldKey NVARCHAR(50) AS
BEGIN
    SELECT COUNT(*) FROM employee_data_fields WHERE field_key = @FieldKey;
END;
GO

CREATE OR ALTER PROCEDURE sp_CreateMasterField
    @FieldKey NVARCHAR(50), @DisplayLabel NVARCHAR(100), @SectionName NVARCHAR(50), @SectionOrder INT, @FieldOrder INT, @GridSize INT, @ComponentType NVARCHAR(50), @OptionsJson NVARCHAR(MAX) = NULL
AS
BEGIN
    INSERT INTO employee_data_fields (field_key, display_label, section_name, section_order, field_order, grid_size, component_type, options_json, is_core_field)
    OUTPUT INSERTED.id
    VALUES (@FieldKey, @DisplayLabel, @SectionName, @SectionOrder, @FieldOrder, @GridSize, @ComponentType, @OptionsJson, 0);
END;
GO

CREATE OR ALTER PROCEDURE sp_DeleteMasterField @Id INT AS
BEGIN
    IF EXISTS (SELECT 1 FROM employee_data_fields WHERE id = @Id AND is_core_field = 1) RETURN;
    DELETE FROM emp_data_use_fields WHERE field_id = @Id;
    DELETE FROM employee_data_fields WHERE id = @Id;
END;
GO

CREATE OR ALTER PROCEDURE sp_AutoSeedNewField
    @FieldId INT
AS
BEGIN
    INSERT INTO emp_data_use_fields (organization_id, field_id, is_visible, is_mandatory)
    SELECT o.id, @FieldId, 1, 0
    FROM organizations o
    WHERE NOT EXISTS (
        SELECT 1 FROM emp_data_use_fields 
        WHERE organization_id = o.id AND field_id = @FieldId
    );
END;
GO

-- ── Migration 33: Add Department Field to Employees ──────────
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('employees') AND name = 'department')
BEGIN
    ALTER TABLE employees ADD department NVARCHAR(100) NULL;
END;
GO

CREATE OR ALTER PROCEDURE sp_GetEmployees @OrganizationId INT AS
BEGIN
    SELECT 
        id AS Id,
        user_id AS UserId,
        organization_id AS OrganizationId,
        employee_code AS EmployeeCode,
        salutation AS Salutation,
        name AS Name,
        email AS Email,
        designation AS Designation,
        gender AS Gender,
        mobile AS Mobile,
        joining_date AS JoiningDate,
        date_of_birth AS DateOfBirth,
        profile_picture_url AS ProfilePictureUrl,
        status AS Status,
        father_or_spouse AS FatherOrSpouse,
        present_address AS PresentAddress,
        permanent_address AS PermanentAddress,
        employee_pf_no AS EmployeePfNo,
        employee_esic_no AS EmployeeEsicNo,
        employee_aadhar_no AS EmployeeAadharNo,
        days_80_service_completion_date AS Days80ServiceCompletionDate,
        permanent_appointment_date AS PermanentAppointmentDate,
        period_of_suspension AS PeriodOfSuspension,
        signature_image_url AS SignatureImageUrl,
        thumb_impression_image_url AS ThumbImpressionImageUrl,
        date_of_exit AS DateOfExit,
        reason_for_exit AS ReasonForExit,
        department AS Department,
        remarks AS Remarks,
        custom_fields_json AS CustomFieldsJson,
        created_at AS CreatedAt,
        updated_at AS UpdatedAt,
        created_by AS CreatedBy,
        last_updated_by AS LastUpdatedBy
    FROM employees WHERE organization_id = @OrganizationId ORDER BY created_at DESC;
END;
GO

CREATE OR ALTER PROCEDURE sp_CreateEmployee
    @OrganizationId INT, @LinkToUserId INT = NULL, @EmployeeCode NVARCHAR(50) = NULL, @Salutation NVARCHAR(20) = NULL,
    @Name NVARCHAR(100), @Email NVARCHAR(100), @Designation NVARCHAR(100) = NULL, @Gender NVARCHAR(20) = NULL,
    @Mobile NVARCHAR(20) = NULL, @JoiningDate DATE = NULL, @DateOfBirth DATE = NULL, @ProfilePictureUrl NVARCHAR(255) = NULL,
    @FatherOrSpouse NVARCHAR(100) = NULL, @PresentAddress NVARCHAR(255) = NULL, @PermanentAddress NVARCHAR(255) = NULL,
    @EmployeePfNo NVARCHAR(50) = NULL, @EmployeeEsicNo NVARCHAR(50) = NULL, @EmployeeAadharNo NVARCHAR(20) = NULL,
    @Days80ServiceCompletionDate DATE = NULL, @PermanentAppointmentDate DATE = NULL, @PeriodOfSuspension INT = NULL,
    @SignatureImageUrl NVARCHAR(255) = NULL, @ThumbImpressionImageUrl NVARCHAR(255) = NULL, @DateOfExit DATE = NULL,
    @ReasonForExit NVARCHAR(255) = NULL, @Department NVARCHAR(100) = NULL, @Remarks NVARCHAR(255) = NULL, 
    @CustomFieldsJson NVARCHAR(MAX) = NULL, @CreatedBy INT = NULL
AS
BEGIN
    INSERT INTO employees (organization_id, user_id, employee_code, salutation, name, email, designation,
        gender, mobile, joining_date, date_of_birth, profile_picture_url,
        father_or_spouse, present_address, permanent_address, employee_pf_no, 
        employee_esic_no, employee_aadhar_no, days_80_service_completion_date,
        permanent_appointment_date, period_of_suspension, signature_image_url,
        thumb_impression_image_url, date_of_exit, reason_for_exit, department, remarks, custom_fields_json,
        created_by, last_updated_by)
    OUTPUT INSERTED.id
    VALUES (@OrganizationId, @LinkToUserId, @EmployeeCode, @Salutation, @Name, @Email, @Designation,
        @Gender, @Mobile, @JoiningDate, @DateOfBirth, @ProfilePictureUrl, @FatherOrSpouse, @PresentAddress, @PermanentAddress,
        @EmployeePfNo, @EmployeeEsicNo, @EmployeeAadharNo, @Days80ServiceCompletionDate, @PermanentAppointmentDate,
        @PeriodOfSuspension, @SignatureImageUrl, @ThumbImpressionImageUrl, @DateOfExit, @ReasonForExit, @Department, @Remarks, @CustomFieldsJson,
        @CreatedBy, @CreatedBy);
END;
GO

CREATE OR ALTER PROCEDURE sp_UpdateEmployee
    @Id INT, @OrganizationId INT, @EmployeeCode NVARCHAR(50) = NULL, @Salutation NVARCHAR(20) = NULL,
    @Name NVARCHAR(100), @Email NVARCHAR(100), @Designation NVARCHAR(100) = NULL, @Gender NVARCHAR(20) = NULL,
    @Mobile NVARCHAR(20) = NULL, @JoiningDate DATE = NULL, @DateOfBirth DATE = NULL, @ProfilePictureUrl NVARCHAR(255) = NULL,
    @FatherOrSpouse NVARCHAR(100) = NULL, @PresentAddress NVARCHAR(255) = NULL, @PermanentAddress NVARCHAR(255) = NULL,
    @EmployeePfNo NVARCHAR(50) = NULL, @EmployeeEsicNo NVARCHAR(50) = NULL, @EmployeeAadharNo NVARCHAR(20) = NULL,
    @Days80ServiceCompletionDate DATE = NULL, @PermanentAppointmentDate DATE = NULL, @PeriodOfSuspension INT = NULL,
    @SignatureImageUrl NVARCHAR(255) = NULL, @ThumbImpressionImageUrl NVARCHAR(255) = NULL, @DateOfExit DATE = NULL,
    @ReasonForExit NVARCHAR(255) = NULL, @Department NVARCHAR(100) = NULL, @Remarks NVARCHAR(255) = NULL, 
    @CustomFieldsJson NVARCHAR(MAX) = NULL, @LastUpdatedBy INT = NULL
AS
BEGIN
    UPDATE employees SET employee_code = @EmployeeCode, salutation = @Salutation, name = @Name, email = @Email,
        designation = @Designation, gender = @Gender, mobile = @Mobile, joining_date = @JoiningDate, date_of_birth = @DateOfBirth,
        profile_picture_url = @ProfilePictureUrl, father_or_spouse = @FatherOrSpouse, present_address = @PresentAddress,
        permanent_address = @PermanentAddress, employee_pf_no = @EmployeePfNo, employee_esic_no = @EmployeeEsicNo,
        employee_aadhar_no = @EmployeeAadharNo, days_80_service_completion_date = @Days80ServiceCompletionDate,
        permanent_appointment_date = @PermanentAppointmentDate, period_of_suspension = @PeriodOfSuspension,
        signature_image_url = @SignatureImageUrl, thumb_impression_image_url = @ThumbImpressionImageUrl,
        date_of_exit = @DateOfExit, reason_for_exit = @ReasonForExit, department = @Department, remarks = @Remarks,
        custom_fields_json = @CustomFieldsJson, updated_at = GETDATE(),
        last_updated_by = @LastUpdatedBy
    WHERE id = @Id AND organization_id = @OrganizationId;
END;
GO

-- ── Migration 35: Organization Management Support ──────────────────────────
PRINT '[Migration] Updating Organization related stored procedures...';
GO
DROP PROCEDURE IF EXISTS sp_CreateOrganization;
GO
CREATE PROCEDURE sp_CreateOrganization
    @Name VARCHAR(255),
    @Email VARCHAR(255) = NULL,
    @Phone VARCHAR(50) = NULL,
    @Address NVARCHAR(MAX) = NULL,
    @LogoUrl NVARCHAR(MAX) = NULL
AS
BEGIN
    INSERT INTO organizations (name, email, phone, address, logo_url)
    OUTPUT INSERTED.id
    VALUES (@Name, @Email, @Phone, @Address, @LogoUrl);
END;
GO
DROP PROCEDURE IF EXISTS sp_UpdateOrganization;
GO
CREATE PROCEDURE sp_UpdateOrganization
    @Id INT,
    @Name VARCHAR(255),
    @Email VARCHAR(255) = NULL,
    @Phone VARCHAR(50) = NULL,
    @Address NVARCHAR(MAX) = NULL,
    @LogoUrl NVARCHAR(MAX) = NULL
AS
BEGIN
    UPDATE organizations
    SET name = @Name,
        email = @Email,
        phone = @Phone,
        address = @Address,
        logo_url = COALESCE(@LogoUrl, logo_url),
        updated_at = GETDATE()
    WHERE id = @Id;
END;
GO
DROP PROCEDURE IF EXISTS sp_DeleteOrganization;
GO
CREATE PROCEDURE sp_DeleteOrganization
    @Id INT
AS
BEGIN
    DELETE FROM organizations WHERE id = @Id;
END;
GO
DROP PROCEDURE IF EXISTS sp_GetOrganizationById;
GO
CREATE PROCEDURE sp_GetOrganizationById
    @Id INT
AS
BEGIN
    SELECT id, name, email, phone, address, logo_url, created_at, updated_at
    FROM organizations
    WHERE id = @Id;
END;
GO
DROP PROCEDURE IF EXISTS sp_GetAllOrganizations;
GO
CREATE PROCEDURE sp_GetAllOrganizations
AS
BEGIN
    SELECT id, name, email, phone, address, logo_url, created_at
    FROM organizations
    ORDER BY name;
END;
GO
PRINT '[Migration] Updating User Access procedures to include logos...';
GO
CREATE OR ALTER PROCEDURE sp_GetUserOrganizations
    @UserID INT
AS
BEGIN
    SELECT 
        o.id            AS OrganizationID,
        o.name          AS OrganizationName,
        o.email         AS OrganizationEmail,
        o.logo_url      AS OrganizationLogo,
        r.RoleID,
        r.RoleName      AS Role,
        a.GrantedDate,
        a.IsActive
    FROM UserOrganizationAccess a
    JOIN organizations o ON o.id     = a.OrganizationID
    JOIN Roles         r ON r.RoleID = a.RoleID
    WHERE a.UserID = @UserID
    ORDER BY o.name;
END;
GO
CREATE OR ALTER PROCEDURE sp_GetAllUsersWithAccess
    @OrganizationID INT = NULL
AS
BEGIN
    SELECT 
        u.id            AS UserID,
        u.name          AS UserName,
        u.email         AS Email,
        o.id            AS OrganizationID,
        o.name          AS OrganizationName,
        o.logo_url      AS OrganizationLogo,
        r.RoleName      AS Role,
        a.IsActive,
        a.GrantedDate
    FROM UserOrganizationAccess a
    JOIN users         u ON u.id     = a.UserID
    JOIN organizations o ON o.id     = a.OrganizationID
    JOIN Roles         r ON r.RoleID = a.RoleID
    WHERE (@OrganizationID IS NULL OR a.OrganizationID = @OrganizationID)
    ORDER BY u.name, o.name;
END;
GO
PRINT '[Migration] User Access procedures updated.';
-- ── Migration 39.5: Holidays (Form VI) ────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Holidays')
BEGIN
    CREATE TABLE Holidays (
        HolidayID       INT IDENTITY(1,1) PRIMARY KEY,
        OrganizationID  INT NOT NULL,
        HolidayName     NVARCHAR(150) NOT NULL,
        TicketNumber    NVARCHAR(50) NULL,
        FatherName      NVARCHAR(150) NULL,
        January         BIT DEFAULT 0,
        February        BIT DEFAULT 0,
        March           BIT DEFAULT 0,
        April           BIT DEFAULT 0,
        May             BIT DEFAULT 0,
        June            BIT DEFAULT 0,
        July            BIT DEFAULT 0,
        August          BIT DEFAULT 0,
        September       BIT DEFAULT 0,
        October         BIT DEFAULT 0,
        November        BIT DEFAULT 0,
        December        BIT DEFAULT 0,
        CreatedDate     DATETIME DEFAULT GETDATE(),
        CreatedBy       INT NULL,
        LastUpdatedBy   INT NULL,
        CONSTRAINT FK_Holidays_Organizations FOREIGN KEY (OrganizationID) REFERENCES organizations(id) ON DELETE CASCADE
    );

    PRINT '[Migration] Holidays table created.';
END
GO

-- ── Migration 40: Module Management ───────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Modules')
BEGIN
    CREATE TABLE Modules (
        ModuleID    INT IDENTITY(1,1) PRIMARY KEY,
        ModuleName  NVARCHAR(100) NOT NULL UNIQUE,
        Description NVARCHAR(255) NULL,
        IsActive    BIT DEFAULT 1,
        CreatedDate DATETIME DEFAULT GETDATE(),
        CreatedBy   INT NULL,
        LastUpdatedBy INT NULL
    );

    INSERT INTO Modules (ModuleName, Description) VALUES
        ('Form A', 'Muster Roll (Form A) register and export'),
        ('Form 12', 'Register of Adult Workers and Young Persons'),
        ('Form U', 'Register of Adult Workers (Form U)'),
        ('Form VI', 'Register of National & Festival Holidays for the year');

    PRINT '[Migration] Modules table created and seeded.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'OrganizationModuleAccess')
BEGIN
    CREATE TABLE OrganizationModuleAccess (
        AccessID       INT IDENTITY(1,1) PRIMARY KEY,
        OrganizationID INT NOT NULL,
        ModuleID       INT NOT NULL,
        IsEnabled      BIT DEFAULT 1,
        GrantedDate    DATETIME DEFAULT GETDATE(),
        CreatedBy      INT NULL,
        LastUpdatedBy  INT NULL,

        CONSTRAINT FK_OMA_Org     FOREIGN KEY (OrganizationID) REFERENCES organizations(id) ON DELETE CASCADE,
        CONSTRAINT FK_OMA_Module  FOREIGN KEY (ModuleID)       REFERENCES Modules(ModuleID) ON DELETE CASCADE,
        CONSTRAINT UQ_Org_Module  UNIQUE (OrganizationID, ModuleID)
    );

    -- Enable all Form modules for all existing organizations by default
    INSERT INTO OrganizationModuleAccess (OrganizationID, ModuleID, IsEnabled)
    SELECT o.id, m.ModuleID, 1
    FROM organizations o, Modules m
    WHERE m.ModuleName IN ('Form A', 'Form 12', 'Form U', 'Form VI');

    PRINT '[Migration] OrganizationModuleAccess table created.';
END
GO

-- ── Migration 40.5: Register Form VI Module for Existing Organizations ──────
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'OrganizationModuleAccess')
   AND EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Modules')
BEGIN
    -- For existing organizations that don't have Form VI linked yet, add it
    INSERT INTO OrganizationModuleAccess (OrganizationID, ModuleID, IsEnabled)
    SELECT DISTINCT o.id, m.ModuleID, 1
    FROM organizations o, Modules m
    WHERE m.ModuleName = 'Form VI'
      AND NOT EXISTS (
          SELECT 1 FROM OrganizationModuleAccess oma
          WHERE oma.OrganizationID = o.id AND oma.ModuleID = m.ModuleID
      );

    PRINT '[Migration] Form VI module linked to existing organizations.';
END
GO

-- ── Migration 42: Audit Fields for all tables ──────────────────
PRINT '[Migration] Adding Audit Fields (created_by, last_updated_by) to all existing tables...';
GO

DECLARE @TableName NVARCHAR(255);
DECLARE @SQL NVARCHAR(MAX);

DECLARE table_cursor CURSOR FOR 
SELECT name FROM sys.tables;

OPEN table_cursor;
FETCH NEXT FROM table_cursor INTO @TableName;
WHILE @@FETCH_STATUS = 0
BEGIN
    -- Check for created_by
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(@TableName) AND name IN ('created_by', 'CreatedBy'))
    BEGIN
        SET @SQL = 'ALTER TABLE ' + QUOTENAME(@TableName) + ' ADD created_by INT NULL';
        EXEC (@SQL);
        PRINT 'Added created_by to ' + @TableName;
    END

    -- Check for last_updated_by
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(@TableName) AND name IN ('last_updated_by', 'LastUpdatedBy'))
    BEGIN
        SET @SQL = 'ALTER TABLE ' + QUOTENAME(@TableName) + ' ADD last_updated_by INT NULL';
        EXEC (@SQL);
        PRINT 'Added last_updated_by to ' + @TableName;
    END

    FETCH NEXT FROM table_cursor INTO @TableName;
END
CLOSE table_cursor;
DEALLOCATE table_cursor;
GO

-- ── Migration 41: Module Management Procedures ─────────────────
CREATE OR ALTER PROCEDURE sp_GetOrganizationModules
    @OrganizationId INT
AS
BEGIN
    SELECT 
        m.ModuleID,
        m.ModuleName,
        m.Description,
        ISNULL(oma.IsEnabled, 0) AS IsEnabled
    FROM Modules m
    LEFT JOIN OrganizationModuleAccess oma ON m.ModuleID = oma.ModuleID AND oma.OrganizationID = @OrganizationId
    WHERE m.IsActive = 1;
END;
GO

CREATE OR ALTER PROCEDURE sp_ToggleOrganizationModule
    @OrganizationId INT,
    @ModuleId INT,
    @IsEnabled BIT
AS
BEGIN
    IF EXISTS (SELECT 1 FROM OrganizationModuleAccess WHERE OrganizationID = @OrganizationId AND ModuleID = @ModuleId)
    BEGIN
        UPDATE OrganizationModuleAccess 
        SET IsEnabled = @IsEnabled 
        WHERE OrganizationID = @OrganizationId AND ModuleID = @ModuleId;
    END
    ELSE
    BEGIN
        INSERT INTO OrganizationModuleAccess (OrganizationID, ModuleID, IsEnabled)
        VALUES (@OrganizationId, @ModuleId, @IsEnabled);
    END
END;
GO

-- ── Migration 49: Ensure Departments & Designations Tables ────────────────
-- Handles table creation or adding missing audit columns

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Departments')
BEGIN
    CREATE TABLE Departments (
        id INT IDENTITY(1,1) PRIMARY KEY,
        organization_id INT NOT NULL,
        department NVARCHAR(255) NOT NULL,
        parent_department_id INT NULL,
        created_at DATETIME2 DEFAULT GETDATE(),
        updated_at DATETIME2 DEFAULT GETDATE(),
        created_by INT NULL,
        last_updated_by INT NULL,
        CONSTRAINT FK_Departments_Organizations FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
    );
    PRINT '[Migration] Departments table created.';
END
ELSE
BEGIN
    -- Add missing columns to existing table
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Departments') AND name = 'created_by')
    BEGIN
        ALTER TABLE Departments ADD created_by INT NULL;
        PRINT '[Migration] Added created_by to Departments.';
    END
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Departments') AND name = 'last_updated_by')
    BEGIN
        ALTER TABLE Departments ADD last_updated_by INT NULL;
        PRINT '[Migration] Added last_updated_by to Departments.';
    END
    -- Optionally upgrade string length if needed
    ALTER TABLE Departments ALTER COLUMN department NVARCHAR(255) NOT NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Designations')
BEGIN
    CREATE TABLE Designations (
        id INT IDENTITY(1,1) PRIMARY KEY,
        organization_id INT NOT NULL,
        designation NVARCHAR(255) NOT NULL,
        parent_designation_id INT NULL,
        created_at DATETIME2 DEFAULT GETDATE(),
        updated_at DATETIME2 DEFAULT GETDATE(),
        created_by INT NULL,
        last_updated_by INT NULL,
        CONSTRAINT FK_Designations_Organizations FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
    );
    PRINT '[Migration] Designations table created.';
END
ELSE
BEGIN
    -- Add missing columns to existing table
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Designations') AND name = 'created_by')
    BEGIN
        ALTER TABLE Designations ADD created_by INT NULL;
        PRINT '[Migration] Added created_by to Designations.';
    END
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Designations') AND name = 'last_updated_by')
    BEGIN
        ALTER TABLE Designations ADD last_updated_by INT NULL;
        PRINT '[Migration] Added last_updated_by to Designations.';
    END
    -- Optionally upgrade string length if needed
    ALTER TABLE Designations ALTER COLUMN designation NVARCHAR(255) NOT NULL;
END
GO

-- ── Migration 50: Department & Designation Procedures ─────────────────────
-- Adding/Updating procedures for Departments and Designations

CREATE OR ALTER PROCEDURE sp_GetDepartmentsByOrganization
    @OrgId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        d.id, 
        d.organization_id, 
        o.name AS organization_name,
        d.department AS department_name, 
        d.parent_department_id, 
        p.department AS parent_department_name,
        d.created_at, 
        d.updated_at 
    FROM Departments d
    LEFT JOIN Departments p ON d.parent_department_id = p.id
    LEFT JOIN organizations o ON d.organization_id = o.id
    WHERE d.organization_id = @OrgId;
END;
GO

CREATE OR ALTER PROCEDURE sp_InsertDepartment
    @OrgId INT,
    @Name NVARCHAR(255),
    @ParentId INT = NULL,
    @CreatedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Departments (organization_id, department, parent_department_id, created_by, last_updated_by)
    VALUES (@OrgId, @Name, @ParentId, @CreatedBy, @CreatedBy);
END;
GO

CREATE OR ALTER PROCEDURE sp_UpdateDepartment
    @Id INT,
    @Name NVARCHAR(255),
    @ParentId INT = NULL,
    @LastUpdatedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Departments
    SET department = @Name,
        parent_department_id = @ParentId,
        updated_at = GETDATE(),
        last_updated_by = @LastUpdatedBy
    WHERE id = @Id;
END;
GO

CREATE OR ALTER PROCEDURE sp_UpdateAndDeleteDepartment
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE Departments SET parent_department_id = NULL WHERE parent_department_id = @Id;
        DELETE FROM Departments WHERE id = @Id;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE sp_GetDesignationsByOrganization
    @OrgId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        d.id, 
        d.organization_id, 
        o.name AS organization_name,
        d.designation AS designation_name, 
        d.parent_designation_id, 
        p.designation AS parent_designation_name,
        d.created_at, 
        d.updated_at 
    FROM Designations d
    LEFT JOIN Designations p ON d.parent_designation_id = p.id
    LEFT JOIN organizations o ON d.organization_id = o.id
    WHERE d.organization_id = @OrgId;
END;
GO

CREATE OR ALTER PROCEDURE sp_InsertDesignation
    @OrganizationId INT,
    @DesignationName NVARCHAR(255),
    @ParentDesignationId INT = NULL,
    @CreatedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Designations (organization_id, designation, parent_designation_id, created_by, last_updated_by)
    VALUES (@OrganizationId, @DesignationName, @ParentDesignationId, @CreatedBy, @CreatedBy);
END;
GO

CREATE OR ALTER PROCEDURE sp_UpdateDesignation
    @Id INT,
    @DesignationName NVARCHAR(255),
    @ParentDesignationId INT = NULL,
    @LastUpdatedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Designations
    SET designation = @DesignationName,
        parent_designation_id = @ParentDesignationId,
        updated_at = GETDATE(),
        last_updated_by = @LastUpdatedBy
    WHERE id = @Id;
END;
GO

CREATE OR ALTER PROCEDURE sp_UpdateAndDeleteDesignation
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE Designations SET parent_designation_id = NULL WHERE parent_designation_id = @Id;
        DELETE FROM Designations WHERE id = @Id;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ── Final Migration: Force-restore sp_UpsertShiftAssignment ──────────────────────────────
PRINT '[Migration] Force-restoring sp_UpsertShiftAssignment with correct parameters...';
GO

IF OBJECT_ID('sp_UpsertShiftAssignment', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE sp_UpsertShiftAssignment;
END
GO

CREATE OR ALTER PROCEDURE sp_UpsertShiftAssignment
    @organization_id INT,
    @employee_id INT,
    @template_id INT = NULL,
    @shift_name NVARCHAR(100),
    @shift_type NVARCHAR(50),
    @start_time TIME,
    @end_time TIME,
    @unpaid_break INT,
    @total_shift_hours NVARCHAR(10),
    @earliest_punch_in TIME = NULL,
    @latest_punch_out TIME = NULL,
    @late_grace_period INT = 0,
    @early_grace_period INT = 0,
    @work_days NVARCHAR(200) = NULL,
    @start_date DATE = NULL,
    @end_date DATE = NULL,
    @assignment_type INT = 3,
    @specific_dates NVARCHAR(MAX) = NULL,
    @remarks NVARCHAR(MAX) = NULL,
    @created_by INT = NULL,
    @last_updated_by INT = NULL
AS
BEGIN
    DELETE FROM ShiftAssignments WHERE employee_id = @employee_id AND organization_id = @organization_id;
    
    INSERT INTO ShiftAssignments (
        organization_id, employee_id, template_id, shift_name, shift_type, 
        start_time, end_time, unpaid_break, total_shift_hours, earliest_punch_in, 
        latest_punch_out, late_grace_period, early_grace_period,
        work_days, start_date, end_date, assignment_type, specific_dates, remarks,
        created_by, last_updated_by
    ) VALUES (
        @organization_id, @employee_id, @template_id, @shift_name, @shift_type, 
        @start_time, @end_time, @unpaid_break, @total_shift_hours, @earliest_punch_in, 
        @latest_punch_out, @late_grace_period, @early_grace_period,
        @work_days, @start_date, @end_date, @assignment_type, @specific_dates, @remarks,
        @created_by, @last_updated_by
    );
END;
GO

PRINT '[Migration] sp_UpsertShiftAssignment has been force-restored.';
GO

-- ── Migration 51: Form 26 A (Dangerous Occurrences) ─────────────────────────
PRINT '[Migration] Starting Migration 51: Form 26 A...';
GO

-- 1. Register Module
IF NOT EXISTS (SELECT 1 FROM Modules WHERE ModuleName = 'Form 26 A')
BEGIN
    INSERT INTO Modules (ModuleName, Description) 
    VALUES ('Form 26 A', 'Register of Accidents, Dangerous Occurrences and Accidents');
    PRINT '[Migration] Form 26 A added to Modules.';
END

IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'OrganizationModuleAccess')
   AND EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Modules')
BEGIN
    INSERT INTO OrganizationModuleAccess (OrganizationID, ModuleID, IsEnabled)
    SELECT DISTINCT o.id, m.ModuleID, 1
    FROM organizations o, Modules m
    WHERE m.ModuleName = 'Form 26 A'
      AND NOT EXISTS (
          SELECT 1 FROM OrganizationModuleAccess oma
          WHERE oma.OrganizationID = o.id AND oma.ModuleID = m.ModuleID
      );
    PRINT '[Migration] Form 26 A module linked to existing organizations.';
END
GO

-- 2. Create Table
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Dangerous_Occurrences_Register')
BEGIN
    CREATE TABLE Dangerous_Occurrences_Register (
        id                                                  INT IDENTITY(1,1) PRIMARY KEY,
        org_id                                              INT NOT NULL,
        calendar_year                                       INT NOT NULL,
        dangerous_occurrence_serial_no                      INT NOT NULL,
        occurrence_datetime                                 DATETIME2 NOT NULL,
        form18A_despatch_date                               DATE NULL,
        dangerous_occurrence_place                          NVARCHAR(MAX) NULL,
        occurrence_description_action_taken                 NVARCHAR(MAX) NULL,
        damage_details_damage_loss_repair_replacement_cost  NVARCHAR(MAX) NULL,
        manager_remarks_and_initials                        NVARCHAR(MAX) NULL,
        created_by                                          INT NULL,
        created_at                                          DATETIME2 DEFAULT GETDATE(),
        last_updated_by                                     INT NULL,
        updated_at                                          DATETIME2 DEFAULT GETDATE(),

        CONSTRAINT FK_DOR_Org FOREIGN KEY (org_id) REFERENCES organizations(id) ON DELETE CASCADE
    );
    PRINT '[Migration] Dangerous_Occurrences_Register table created.';
END
GO

-- ── Migration 51a: Data Cleanup for Form 26 A (Handle legacy string IDs) ───
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Dangerous_Occurrences_Register')
BEGIN
    -- Clear non-numeric created_by
    UPDATE Dangerous_Occurrences_Register 
    SET created_by = NULL 
    WHERE created_by IS NOT NULL AND ISNUMERIC(CAST(created_by AS NVARCHAR(MAX))) = 0;

    -- Clear non-numeric last_updated_by
    UPDATE Dangerous_Occurrences_Register 
    SET last_updated_by = NULL 
    WHERE last_updated_by IS NOT NULL AND ISNUMERIC(CAST(last_updated_by AS NVARCHAR(MAX))) = 0;
    
    PRINT '[Migration] Dangerous_Occurrences_Register audit data cleaned up.';
END
GO

-- 3. Stored Procedures
CREATE OR ALTER PROCEDURE sp_GetDangerousOccurrences
    @OrgId INT,
    @CalendarYear INT = NULL,
    @FromDate DATETIME2 = NULL,
    @ToDate DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM Dangerous_Occurrences_Register 
    WHERE org_id = @OrgId
      AND (@CalendarYear IS NULL OR calendar_year = @CalendarYear)
      AND (@FromDate IS NULL OR occurrence_datetime >= @FromDate)
      AND (@ToDate IS NULL OR occurrence_datetime <= @ToDate)
    ORDER BY occurrence_datetime DESC;
END;
GO

CREATE OR ALTER PROCEDURE sp_CreateDangerousOccurrence
    @OrgId INT,
    @CalendarYear INT,
    @DangerousOccurrenceSerialNo INT,
    @OccurrenceDatetime DATETIME2,
    @Form18ADespatchDate DATE = NULL,
    @DangerousOccurrencePlace NVARCHAR(MAX) = NULL,
    @OccurrenceDescriptionActionTaken NVARCHAR(MAX) = NULL,
    @DamageDetailsDamageLossRepairReplacementCost NVARCHAR(MAX) = NULL,
    @ManagerRemarksAndInitials NVARCHAR(MAX) = NULL,
    @CreatedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Dangerous_Occurrences_Register (
        org_id, calendar_year, dangerous_occurrence_serial_no, occurrence_datetime,
        form18A_despatch_date, dangerous_occurrence_place, occurrence_description_action_taken,
        damage_details_damage_loss_repair_replacement_cost, manager_remarks_and_initials,
        created_by, created_at, last_updated_by, updated_at
    ) VALUES (
        @OrgId, @CalendarYear, @DangerousOccurrenceSerialNo, @OccurrenceDatetime,
        @Form18ADespatchDate, @DangerousOccurrencePlace, @OccurrenceDescriptionActionTaken,
        @DamageDetailsDamageLossRepairReplacementCost, @ManagerRemarksAndInitials,
        @CreatedBy, GETDATE(), @CreatedBy, GETDATE()
    );
END;
GO

CREATE OR ALTER PROCEDURE sp_UpdateDangerousOccurrence
    @Id INT,
    @OrgId INT,
    @CalendarYear INT,
    @DangerousOccurrenceSerialNo INT,
    @OccurrenceDatetime DATETIME2,
    @Form18ADespatchDate DATE = NULL,
    @DangerousOccurrencePlace NVARCHAR(MAX) = NULL,
    @OccurrenceDescriptionActionTaken NVARCHAR(MAX) = NULL,
    @DamageDetailsDamageLossRepairReplacementCost NVARCHAR(MAX) = NULL,
    @ManagerRemarksAndInitials NVARCHAR(MAX) = NULL,
    @UpdatedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Dangerous_Occurrences_Register SET
        calendar_year = @CalendarYear,
        dangerous_occurrence_serial_no = @DangerousOccurrenceSerialNo,
        occurrence_datetime = @OccurrenceDatetime,
        form18A_despatch_date = @Form18ADespatchDate,
        dangerous_occurrence_place = @DangerousOccurrencePlace,
        occurrence_description_action_taken = @OccurrenceDescriptionActionTaken,
        damage_details_damage_loss_repair_replacement_cost = @DamageDetailsDamageLossRepairReplacementCost,
        manager_remarks_and_initials = @ManagerRemarksAndInitials,
        last_updated_by = @UpdatedBy,
        updated_at = GETDATE()
    WHERE id = @Id AND org_id = @OrgId;
END;
GO

CREATE OR ALTER PROCEDURE sp_DeleteDangerousOccurrence
    @Id INT,
    @OrgId INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM Dangerous_Occurrences_Register WHERE id = @Id AND org_id = @OrgId;
END;
GO

CREATE OR ALTER PROCEDURE sp_GetNextDangerousOccurrenceSerialNo
    @OrgId INT,
    @CalendarYear INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ISNULL(MAX(dangerous_occurrence_serial_no), 0) + 1 
    FROM Dangerous_Occurrences_Register 
    WHERE org_id = @OrgId AND calendar_year = @CalendarYear;
END;
GO

PRINT '[Migration] Migration 51: Form 26 A completed successfully.';
GO

-- ── Migration 52: Face Recognition Schema ───────────────────
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'FaceEmbeddings')
BEGIN
    CREATE TABLE FaceEmbeddings (
        id INT IDENTITY(1,1) PRIMARY KEY,
        employee_id INT NOT NULL,
        role NVARCHAR(50) NULL,
        embedding NVARCHAR(MAX) NOT NULL, -- Stored as JSON array
        created_at DATETIME DEFAULT GETDATE(),
        updated_at DATETIME DEFAULT GETDATE(),
        CONSTRAINT FK_FaceEmbeddings_Employees FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE
    );
    PRINT '[Migration] FaceEmbeddings table created.';
END
GO

CREATE OR ALTER PROCEDURE sp_UpsertFaceEmbedding
    @EmployeeId VARCHAR(50),
    @OrganizationId INT,
    @Role VARCHAR(50), -- Designation
    @Embedding NVARCHAR(MAX),
    @UserId INT = 1
AS
BEGIN
    IF EXISTS (SELECT 1 FROM employee_face_embeddings WHERE employee_id = @EmployeeId AND organization_id = @OrganizationId)
    BEGIN
        UPDATE employee_face_embeddings 
        SET embedding = @Embedding, 
            role = @Role, 
            updated_at = GETDATE(),
            updated_by = @UserId
        WHERE employee_id = @EmployeeId AND organization_id = @OrganizationId;
    END
    ELSE
    BEGIN
        INSERT INTO employee_face_embeddings (employee_id, organization_id, role, embedding, created_at, created_by, updated_at, updated_by)
        VALUES (@EmployeeId, @OrganizationId, @Role, @Embedding, GETDATE(), @UserId, GETDATE(), @UserId);
    END
END
GO

CREATE OR ALTER PROCEDURE sp_GetAllFaceEmbeddings
    @OrganizationId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        fe.employee_id,
        fe.role,
        fe.embedding,
        e.name as EmployeeName,
        e.employee_code as EmployeeCode
    FROM employee_face_embeddings fe
    LEFT JOIN employees e ON (
        fe.employee_id = CAST(e.id AS VARCHAR(50)) 
        OR fe.employee_id = e.employee_code
    )
    WHERE fe.organization_id = @OrganizationId 
       OR fe.organization_id IS NULL; -- Fallback for migration period
END
GO

CREATE OR ALTER PROCEDURE sp_MarkFaceAttendance
    @EmployeeId VARCHAR(50), 
    @Role VARCHAR(50) = NULL,
    @PunchedInType VARCHAR(50) = 'face',
    @UserId INT = 1,
    @OrganizationID INT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO employee_attendance (employee_id, role, punchedin_type, created_at, created_by, last_updated_by, organization_id)
    SELECT id, @Role, @PunchedInType, GETDATE(), @UserId, @UserId, @OrganizationID
    FROM employees 
    WHERE (employee_code = @EmployeeId OR CAST(id AS VARCHAR(50)) = @EmployeeId);
END
GO

CREATE OR ALTER PROCEDURE sp_GetAttendanceLogs
    @OrganizationId INT
AS
BEGIN
    SELECT 
        a.id,
        a.employee_id AS EmployeeCode,
        e.name AS EmployeeName,
        a.role AS Role,
        a.punchedin_type AS PunchType,
        a.created_at AS PunchTime,
        u.name AS CreatedBy
    FROM employee_attendance a
    LEFT JOIN employees e ON (a.employee_id = e.employee_code OR CAST(e.id AS VARCHAR(50)) = a.employee_id)
    LEFT JOIN users u ON a.created_by = u.id
    WHERE e.organization_id = @OrganizationId
    ORDER BY a.created_at DESC;
END;
GO

PRINT '[Migration] Migration 53: Attendance Logs procedure added.';
GO


------------embeddings----------------

