-- Multi-tenant Structure
CREATE TABLE organizations (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(50),
    address NVARCHAR(MAX),
    logo_url NVARCHAR(MAX),
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE(),
    created_by INT NULL,
    last_updated_by INT NULL
);
GO

CREATE TABLE users (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash NVARCHAR(MAX) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'User', -- 'SuperAdmin', 'Admin', 'User'
    organization_id INT NULL,
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE(),
    created_by INT NULL,
    last_updated_by INT NULL,
    CONSTRAINT FK_Users_Organizations FOREIGN KEY (organization_id) REFERENCES organizations(id)
);
GO

CREATE TABLE Departments (
    id INT IDENTITY(1,1) PRIMARY KEY,
    organization_id INT NOT NULL,
    department VARCHAR(100) NOT NULL,
    parent_department_id INT NULL,
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE(),
    created_by INT NULL,
    last_updated_by INT NULL,
    CONSTRAINT FK_Departments_Organizations FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
);
GO

CREATE TABLE Designations (
    id INT IDENTITY(1,1) PRIMARY KEY,
    organization_id INT NOT NULL,
    designation VARCHAR(100) NOT NULL,
    parent_designation_id INT NULL,
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE(),
    created_by INT NULL,
    last_updated_by INT NULL,
    CONSTRAINT FK_Designations_Organizations FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
);
GO

-- Leads table updated for Multi-tenancy
CREATE TABLE leads (
    id INT IDENTITY(1,1) PRIMARY KEY,
    organization_id INT NOT NULL, -- Mandatory link to an organization
    salutation VARCHAR(50),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    lead_source VARCHAR(100),
    added_by VARCHAR(100),
    lead_owner VARCHAR(100),
    create_deal BIT DEFAULT 0,
    auto_convert BIT DEFAULT 0,
    
    -- Deal Info
    deal_name VARCHAR(255),
    pipeline VARCHAR(100),
    deal_stages VARCHAR(100),
    deal_value DECIMAL(15, 2) DEFAULT 0.00,
    close_date DATE,
    deal_category VARCHAR(100),
    deal_agent VARCHAR(100),
    products NVARCHAR(MAX),
    deal_watcher VARCHAR(100),
    
    -- Company Details
    company VARCHAR(255),
    website VARCHAR(255),
    address NVARCHAR(MAX),
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100),
    
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE(),
    created_by INT NULL,
    last_updated_by INT NULL,
    CONSTRAINT FK_Leads_Organizations FOREIGN KEY (organization_id) REFERENCES organizations(id)
);
GO

-- 1. Read All Leads (Filtered by Organization)
CREATE PROCEDURE sp_GetLeads
    @OrganizationId INT
AS
BEGIN
    SELECT 
        id AS Id,
        organization_id AS OrganizationId,
        salutation AS Salutation,
        name AS Name,
        email AS Email,
        lead_source AS LeadSource,
        added_by AS AddedBy,
        lead_owner AS LeadOwner,
        create_deal AS CreateDeal,
        auto_convert AS AutoConvert,
        deal_name AS DealName,
        pipeline AS Pipeline,
        deal_stages AS DealStages,
        deal_value AS DealValue,
        close_date AS CloseDate,
        deal_category AS DealCategory,
        deal_agent AS DealAgent,
        products AS Products,
        deal_watcher AS DealWatcher,
        company AS Company,
        website AS Website,
        address AS Address,
        city AS City,
        state AS State,
        country AS Country,
        created_at AS CreatedAt,
        updated_at AS UpdatedAt,
        created_by AS CreatedBy,
        last_updated_by AS LastUpdatedBy
    FROM leads 
    WHERE organization_id = @OrganizationId 
    ORDER BY created_at DESC;
END;
GO

-- 2. Add Lead
CREATE PROCEDURE sp_AddLead
    @OrganizationId INT,
    @Salutation VARCHAR(50) = NULL,
    @Name VARCHAR(255),
    @Email VARCHAR(255) = NULL,
    @LeadSource VARCHAR(100) = NULL,
    @AddedBy VARCHAR(100) = NULL,
    @LeadOwner VARCHAR(100) = NULL,
    @CreateDeal BIT = 0,
    @AutoConvert BIT = 0,
    @DealName VARCHAR(255) = NULL,
    @Pipeline VARCHAR(100) = NULL,
    @DealStages VARCHAR(100) = NULL,
    @DealValue DECIMAL(15, 2) = NULL,
    @CloseDate DATE = NULL,
    @DealCategory VARCHAR(100) = NULL,
    @DealAgent VARCHAR(100) = NULL,
    @Products NVARCHAR(MAX) = NULL,
    @DealWatcher VARCHAR(100) = NULL,
    @Company VARCHAR(255) = NULL,
    @Website VARCHAR(255) = NULL,
    @Address NVARCHAR(MAX) = NULL,
    @City VARCHAR(100) = NULL,
    @State VARCHAR(100) = NULL,
    @Country VARCHAR(100) = NULL,
    -- Sink parameters for Dapper auto-mapping
    @Id INT = NULL,
    @CreatedAt DATETIME2 = NULL,
    @UpdatedAt DATETIME2 = NULL,
    @CreatedBy INT = NULL
AS
BEGIN
    INSERT INTO leads (
        organization_id, salutation, name, email, lead_source, added_by, lead_owner, 
        create_deal, auto_convert, deal_name, pipeline, deal_stages, 
        deal_value, close_date, deal_category, deal_agent, products, 
        deal_watcher, company, website, address, city, state, country,
        created_by, last_updated_by
    ) 
    OUTPUT INSERTED.id
    VALUES (
        @OrganizationId, @Salutation, @Name, @Email, @LeadSource, @AddedBy, @LeadOwner, 
        @CreateDeal, @AutoConvert, @DealName, @Pipeline, @DealStages, 
        @DealValue, @CloseDate, @DealCategory, @DealAgent, @Products, 
        @DealWatcher, @Company, @Website, @Address, @City, @State, @Country,
        @CreatedBy, @CreatedBy
    );
END;
GO

-- 3. Update Lead
CREATE PROCEDURE sp_UpdateLead
    @Id INT,
    @OrganizationId INT,
    @Salutation VARCHAR(50) = NULL,
    @Name VARCHAR(255),
    @Email VARCHAR(255) = NULL,
    @LeadSource VARCHAR(100) = NULL,
    @AddedBy VARCHAR(100) = NULL,
    @LeadOwner VARCHAR(100) = NULL,
    @CreateDeal BIT = 0,
    @AutoConvert BIT = 0,
    @DealName VARCHAR(255) = NULL,
    @Pipeline VARCHAR(100) = NULL,
    @DealStages VARCHAR(100) = NULL,
    @DealValue DECIMAL(15, 2) = NULL,
    @CloseDate DATE = NULL,
    @DealCategory VARCHAR(100) = NULL,
    @DealAgent VARCHAR(100) = NULL,
    @Products NVARCHAR(MAX) = NULL,
    @DealWatcher VARCHAR(100) = NULL,
    @Company VARCHAR(255) = NULL,
    @Website VARCHAR(255) = NULL,
    @Address NVARCHAR(MAX) = NULL,
    @City VARCHAR(100) = NULL,
    @State VARCHAR(100) = NULL,
    @Country VARCHAR(100) = NULL,
    -- Sink parameters for Dapper auto-mapping
    @CreatedAt DATETIME2 = NULL,
    @UpdatedAt DATETIME2 = NULL,
    @LastUpdatedBy INT = NULL
AS
BEGIN
    UPDATE leads SET 
        salutation = @Salutation,
        name = @Name,
        email = @Email,
        lead_source = @LeadSource,
        added_by = @AddedBy,
        lead_owner = @LeadOwner,
        create_deal = @CreateDeal,
        auto_convert = @AutoConvert,
        deal_name = @DealName,
        pipeline = @Pipeline,
        deal_stages = @DealStages,
        deal_value = @DealValue,
        close_date = @CloseDate,
        deal_category = @DealCategory,
        deal_agent = @DealAgent,
        products = @Products,
        deal_watcher = @DealWatcher,
        company = @Company,
        website = @Website,
        address = @Address,
        city = @City,
        state = @State,
        country = @Country,
        updated_at = GETDATE(),
        last_updated_by = @LastUpdatedBy
    WHERE id = @Id AND organization_id = @OrganizationId;

    EXEC sp_GetLeads @OrganizationId;
END;
GO

-- 4. Delete Lead
CREATE PROCEDURE sp_DeleteLead
    @Id INT,
    @OrganizationId INT
AS
BEGIN
    DELETE FROM leads WHERE id = @Id AND organization_id = @OrganizationId;
    EXEC sp_GetLeads @OrganizationId;
END;
GO

-- Deals Page Updated for Multi-tenancy
CREATE TABLE deals (
    deal_id INT IDENTITY(1,1) PRIMARY KEY,
    organization_id INT NOT NULL,
    lead_contact_name VARCHAR(150) NOT NULL,
    lead_email VARCHAR(255) NULL, 
    lead_phone VARCHAR(50) NULL,  
    deal_name VARCHAR(150) NOT NULL,
    pipeline VARCHAR(100) NOT NULL,
    deal_stage VARCHAR(50) NOT NULL,
    deal_value DECIMAL(18,2) NOT NULL,
    close_date DATE NOT NULL,
    deal_category VARCHAR(100) NULL,
    products VARCHAR(500) NULL,
    deal_agent VARCHAR(100) NULL,
    deal_watcher VARCHAR(100) NULL,
    created_at DATETIME DEFAULT GETDATE(),
    updated_at DATETIME DEFAULT GETDATE(),
    created_by INT NULL,
    last_updated_by INT NULL,
    CONSTRAINT FK_Deals_Organizations FOREIGN KEY (organization_id) REFERENCES organizations(id)
);
GO

-- ══════════════════════════════════════════════════════════
-- EMPLOYEES & HYBRID DYNAMIC FIELDS
-- ══════════════════════════════════════════════════════════

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
    department            NVARCHAR(100)  NULL,
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
GO

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
GO

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
GO

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
GO

-- ══════════════════════════════════════════════════════════
-- MUSTOR ROLL (Form A) - Employee Linked
-- ══════════════════════════════════════════════════════════

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
GO

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

CREATE PROCEDURE sp_insert_deal
(
    @OrganizationId INT,
    @LeadName      VARCHAR(150),
    @LeadEmail     VARCHAR(255) = NULL,
    @LeadPhone     VARCHAR(50)  = NULL,
    @DealName      VARCHAR(150),
    @Pipeline      VARCHAR(100),
    @Stage         VARCHAR(50),
    @Value         DECIMAL(18,2),
    @CloseDate     DATE,
    @Category      VARCHAR(100) = NULL,
    @Products      VARCHAR(500) = NULL,
    @Agent         VARCHAR(100) = NULL,
    @Watcher       VARCHAR(100) = NULL,
    @CreatedBy     INT = NULL
)
AS
BEGIN
    INSERT INTO deals (
        organization_id, lead_contact_name, lead_email, lead_phone, 
        deal_name, pipeline, deal_stage, deal_value, close_date,
        deal_category, products, deal_agent, deal_watcher,
        created_by, last_updated_by
    )
    OUTPUT INSERTED.deal_id
    VALUES (
        @OrganizationId, @LeadName, @LeadEmail, @LeadPhone, 
        @DealName, @Pipeline, @Stage, @Value, @CloseDate,
        @Category, @Products, @Agent, @Watcher,
        @CreatedBy, @CreatedBy
    );
END;
GO

-- ══════════════════════════════════════════════════════════
-- ROLES TABLE
-- Defines all possible roles in the system
-- ══════════════════════════════════════════════════════════
CREATE TABLE Roles (
    RoleID       INT IDENTITY(1,1) PRIMARY KEY,
    RoleName     NVARCHAR(100) NOT NULL UNIQUE,
    Description  NVARCHAR(255) NULL,
    IsSystemRole BIT DEFAULT 0,      -- 1 = built-in role (SuperAdmin/Admin), cannot be deleted
    created_at   DATETIME DEFAULT GETDATE(),
    updated_at   DATETIME DEFAULT GETDATE(),
    CreatedBy    INT NULL,
    LastUpdatedBy INT NULL
);
GO

-- Seed the 3 built-in system roles
INSERT INTO Roles (RoleName, Description, IsSystemRole) VALUES
    ('SuperAdmin', 'Full unrestricted access to all organizations and features', 1),
    ('Admin',      'Can manage one or more assigned organizations',              1),
    ('User',       'Access limited to assigned organizations only',              0);
GO

-- ══════════════════════════════════════════════════════════
-- USER ORGANIZATION ACCESS TABLE
-- Maps which user has access to which org with which role.
-- SuperAdmin skips this table (full access by nature of role).
-- Admin/User must have a row here per org they can access.
-- ══════════════════════════════════════════════════════════
CREATE TABLE UserOrganizationAccess (
    AccessID       INT IDENTITY(1,1) PRIMARY KEY,
    UserID         INT NOT NULL,
    OrganizationID INT NOT NULL,
    RoleID         INT NOT NULL,
    GrantedByID    INT NULL,                    -- which UserID granted this access
    GrantedDate    DATETIME DEFAULT GETDATE(),
    IsActive       BIT DEFAULT 1,               -- 0 = access revoked (soft delete)
    created_at     DATETIME DEFAULT GETDATE(),
    updated_at     DATETIME DEFAULT GETDATE(),

    CONSTRAINT FK_UOA_User      FOREIGN KEY (UserID)         REFERENCES users(id)         ON DELETE CASCADE,
    CONSTRAINT FK_UOA_Org       FOREIGN KEY (OrganizationID) REFERENCES organizations(id) ON DELETE CASCADE,
    CONSTRAINT FK_UOA_Role      FOREIGN KEY (RoleID)         REFERENCES Roles(RoleID),
    CONSTRAINT FK_UOA_GrantedBy FOREIGN KEY (GrantedByID)    REFERENCES users(id),

    -- A user can only have ONE active role per organization
    CONSTRAINT UQ_User_Org UNIQUE (UserID, OrganizationID)
);
GO

-- View: Human-readable summary of all user access
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
JOIN users         u  ON u.id      = a.UserID
JOIN organizations o  ON o.id      = a.OrganizationID
JOIN Roles         r  ON r.RoleID  = a.RoleID
LEFT JOIN users    gb ON gb.id     = a.GrantedByID;
GO

-- ══════════════════════════════════════════════════════════
-- STORED PROCEDURES
-- ══════════════════════════════════════════════════════════

-- 1. Get all organizations a user can access
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
END;
GO

-- 2. Grant (or update) a user's access to an organization
CREATE PROCEDURE sp_GrantOrgAccess
    @UserID         INT,
    @OrganizationID INT,
    @RoleID         INT,
    @GrantedByID    INT
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM UserOrganizationAccess
        WHERE UserID = @UserID AND OrganizationID = @OrganizationID
    )
    BEGIN
        -- Already exists — update role and re-activate
        UPDATE UserOrganizationAccess
        SET RoleID      = @RoleID,
            IsActive    = 1,
            GrantedByID = @GrantedByID,
            GrantedDate = GETDATE()
        WHERE UserID = @UserID AND OrganizationID = @OrganizationID;
    END
    ELSE
    BEGIN
        -- New access entry
        INSERT INTO UserOrganizationAccess (UserID, OrganizationID, RoleID, GrantedByID)
        VALUES (@UserID, @OrganizationID, @RoleID, @GrantedByID);
    END
END;
GO

-- 3. Revoke a user's access to an organization (soft delete — account stays intact)
CREATE PROCEDURE sp_RevokeOrgAccess
    @UserID         INT,
    @OrganizationID INT
AS
BEGIN
    UPDATE UserOrganizationAccess
    SET IsActive = 0
    WHERE UserID = @UserID AND OrganizationID = @OrganizationID;
END;
GO

-- 4. Get all users with their org access (admin dashboard view)
CREATE PROCEDURE sp_GetAllUsersWithAccess
    @OrganizationID INT = NULL     -- NULL = return all orgs (SuperAdmin use)
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
END;
GO

-- 5. Create Organization (Safe ID retrieval)
CREATE PROCEDURE sp_CreateOrganization
    @Name VARCHAR(255),
    @Email VARCHAR(255) = NULL,
    @Phone VARCHAR(50) = NULL,
    @Address NVARCHAR(MAX) = NULL,
    @LogoUrl NVARCHAR(MAX) = NULL,
    @CreatedBy INT = NULL
AS
BEGIN
    INSERT INTO organizations (name, email, phone, address, logo_url, created_by, last_updated_by)
    OUTPUT INSERTED.id
    VALUES (@Name, @Email, @Phone, @Address, @LogoUrl, @CreatedBy, @CreatedBy);
END;
GO

-- 6. Create User (Safe ID retrieval)
CREATE PROCEDURE sp_CreateUser
    @Name VARCHAR(255),
    @Email VARCHAR(255),
    @Hash NVARCHAR(MAX),
    @Role VARCHAR(50),
    @OrgId INT,
    @CreatedBy INT = NULL
AS
BEGIN
    INSERT INTO users (name, email, password_hash, role, organization_id, created_by, last_updated_by)
    OUTPUT INSERTED.id
    VALUES (@Name, @Email, @Hash, @Role, @OrgId, @CreatedBy, @CreatedBy);
END;
GO

-- 7. Get User By Email
CREATE PROCEDURE sp_GetUserByEmail
    @Email VARCHAR(255)
AS
BEGIN
    SELECT * FROM users WHERE email = @Email;
END;
GO

-- 8. Get All Roles
CREATE PROCEDURE sp_GetAllRoles
AS
BEGIN
    SELECT * FROM Roles ORDER BY RoleID;
END;
GO

-- 9. Get All Organizations
CREATE PROCEDURE sp_GetAllOrganizations
AS
BEGIN
    SELECT id, name, email, phone, address, logo_url, created_at FROM organizations ORDER BY name;
END;
GO

-- 10. Check Organization Name Exists
CREATE PROCEDURE sp_CheckOrganizationExists
    @Name VARCHAR(255)
AS
BEGIN
    SELECT COUNT(*) FROM organizations WHERE name = @Name;
END;
GO

-- 11. Get Organization By ID
CREATE PROCEDURE sp_GetOrganizationById
    @Id INT
AS
BEGIN
    SELECT * FROM organizations WHERE id = @Id;
END;
GO

-- 12. Update Organization
CREATE PROCEDURE sp_UpdateOrganization
    @Id INT,
    @Name VARCHAR(255),
    @Email VARCHAR(255) = NULL,
    @Phone VARCHAR(50) = NULL,
    @Address NVARCHAR(MAX) = NULL,
    @LogoUrl NVARCHAR(MAX) = NULL,
    @LastUpdatedBy INT = NULL
AS
BEGIN
    UPDATE organizations 
    SET name = @Name, 
        email = @Email, 
        phone = @Phone, 
        address = @Address, 
        logo_url = COALESCE(@LogoUrl, logo_url),
        updated_at = GETDATE(),
        last_updated_by = @LastUpdatedBy
    WHERE id = @Id;
END;
GO

-- 13. Delete Organization (Foreign keys are ON DELETE CASCADE for leads/employees/uoa)
CREATE PROCEDURE sp_DeleteOrganization
    @Id INT
AS
BEGIN
    DELETE FROM organizations WHERE id = @Id;
END;
GO

-- 14. Check User Email Exists
CREATE PROCEDURE sp_CheckUserEmailExists
    @Email VARCHAR(255)
AS
BEGIN
    SELECT COUNT(*) FROM users WHERE email = @Email;
END;
GO

-- 12. Get Role ID by Name
CREATE PROCEDURE sp_GetRoleIdByName
    @RoleName NVARCHAR(100)
AS
BEGIN
    SELECT RoleID FROM Roles WHERE RoleName = @RoleName;
END;
GO

-- 13. Get User By ID
CREATE PROCEDURE sp_GetUserById
    @Id INT
AS
BEGIN
    SELECT * FROM users WHERE id = @Id;
END;
GO

-- 14. Delete User account
CREATE PROCEDURE sp_DeleteUser
    @Id INT
AS
BEGIN
    DELETE FROM users WHERE id = @Id;
END;
GO

-- 15. Get All Deals (Filtered by Organization)
CREATE PROCEDURE sp_GetAllDeals
    @OrganizationId INT
AS
BEGIN
    SELECT 
        deal_id AS DealId,
        organization_id AS OrganizationId,
        lead_contact_name AS LeadContactName,
        lead_email AS LeadEmail,
        lead_phone AS LeadPhone,
        deal_name AS DealName,
        pipeline AS Pipeline,
        deal_stage AS DealStage,
        deal_value AS DealValue,
        close_date AS CloseDate,
        deal_category AS DealCategory,
        products AS Products,
        deal_agent AS DealAgent,
        deal_watcher AS DealWatcher,
        created_at AS CreatedAt,
        updated_at AS UpdatedAt,
        created_by AS CreatedBy,
        last_updated_by AS LastUpdatedBy
    FROM deals 
    WHERE organization_id = @OrganizationId 
    ORDER BY created_at DESC;
END;
GO

-- 16. Update Deal
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
    UPDATE deals SET 
        lead_contact_name = @LeadName,
        lead_email = @LeadEmail,
        lead_phone = @LeadPhone,
        deal_name = @DealName,
        pipeline = @Pipeline,
        deal_stage = @Stage,
        deal_value = @Value,
        close_date = @CloseDate,
        deal_category = @Category,
        products = @Products,
        deal_agent = @Agent,
        deal_watcher = @Watcher,
        last_updated_by = @LastUpdatedBy
    WHERE deal_id = @Id AND organization_id = @OrganizationId;
END;
GO

-- 17. Delete Deal
CREATE PROCEDURE sp_DeleteDeal
    @Id INT,
    @OrganizationId INT
AS
BEGIN
    DELETE FROM deals WHERE deal_id = @Id AND organization_id = @OrganizationId;
END;
GO

-- ══════════════════════════════════════════════════════════
-- USER LOGIN SESSIONS TRACKING
-- Tracks active user sessions and last login timestamp
-- ══════════════════════════════════════════════════════════

-- 1. Create UserLoginSessions Table
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
GO

-- 2. Upsert User Login Session (Create or Update)
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
END;
GO

-- 3. Get User Login Sessions
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
END;
GO

-- 4. Logout User Session
CREATE OR ALTER PROCEDURE sp_LogoutUserSession
    @UserId INT
AS
BEGIN
    UPDATE UserLoginSessions 
    SET is_active = 0,
        updated_at = GETDATE()
    WHERE user_id = @UserId;
END;
GO

-- 4a. Check and Update Expired Sessions
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
END;
GO

-- ══════════════════════════════════════════════════════════
-- SHIFT MANAGEMENT
-- Supports Global Shift Templates and Individual Employee Assignments
-- ══════════════════════════════════════════════════════════

-- 1. Create ShiftTemplates Table
CREATE TABLE ShiftTemplates (
    Id INT PRIMARY KEY IDENTITY(1,1),
    OrganizationId INT NOT NULL,
    ShiftName NVARCHAR(100) NOT NULL,
    ShiftType NVARCHAR(50) NOT NULL,          -- Day, Night, Open, etc.
    StartTime TIME NOT NULL,                  -- Stored in UTC
    EndTime TIME NOT NULL,                    -- Stored in UTC
    UnpaidBreak INT NOT NULL DEFAULT 0,       -- Break duration in minutes
    TotalShiftHours NVARCHAR(10) NOT NULL,    -- Calculated duration (HH:mm)
    EarliestPunchIn TIME NULL,                -- UTC
    LatestPunchOut TIME NULL,                 -- UTC
    LateGracePeriod INT NOT NULL DEFAULT 0,   -- Minutes
    EarlyGracePeriod INT NOT NULL DEFAULT 0,  -- Minutes
    CreatedAt DATETIME DEFAULT GETDATE(),
    UpdatedAt DATETIME DEFAULT GETDATE(),
    CreatedBy INT NULL,
    LastUpdatedBy INT NULL,
    
    CONSTRAINT FK_ShiftTemplates_Organizations 
        FOREIGN KEY (OrganizationId) REFERENCES organizations(id) 
);
GO

-- 2. Create ShiftAssignments Table

-- Standardized ShiftAssignments Table
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
GO

CREATE INDEX IX_ShiftAssignments_Employee ON ShiftAssignments(employee_id);
CREATE INDEX IX_ShiftTemplates_Org ON ShiftTemplates(organization_id);
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

-- ══════════════════════════════════════════════════════════
-- HYBRID EMPLOYEE PROCEDURES
-- ══════════════════════════════════════════════════════════

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
    @OrganizationId INT,
    @LinkToUserId INT = NULL,
    @EmployeeCode VARCHAR(50) = NULL,
    @Salutation VARCHAR(10) = NULL,
    @Name VARCHAR(255),
    @Email VARCHAR(255),
    @Designation VARCHAR(100) = NULL,
    @Gender VARCHAR(20) = NULL,
    @Mobile VARCHAR(30) = NULL,
    @JoiningDate DATE = NULL,
    @DateOfBirth DATE = NULL,
    @ProfilePictureUrl NVARCHAR(MAX) = NULL,
    @FatherOrSpouse NVARCHAR(100) = NULL,
    @PresentAddress NVARCHAR(255) = NULL,
    @PermanentAddress NVARCHAR(255) = NULL,
    @EmployeePfNo NVARCHAR(50) = NULL,
    @EmployeeEsicNo NVARCHAR(50) = NULL,
    @EmployeeAadharNo NVARCHAR(20) = NULL,
    @Days80ServiceCompletionDate DATE = NULL,
    @PermanentAppointmentDate DATE = NULL,
    @PeriodOfSuspension INT = NULL,
    @SignatureImageUrl NVARCHAR(255) = NULL,
    @ThumbImpressionImageUrl NVARCHAR(255) = NULL,
    @DateOfExit DATE = NULL,
    @ReasonForExit NVARCHAR(255) = NULL, 
    @Department NVARCHAR(100) = NULL, 
    @Remarks NVARCHAR(255) = NULL, 
    @CustomFieldsJson NVARCHAR(MAX) = NULL,
    @CreatedBy INT = NULL
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
    @Id INT,
    @OrganizationId INT,
    @EmployeeCode VARCHAR(50) = NULL,
    @Salutation VARCHAR(10) = NULL,
    @Name VARCHAR(255),
    @Email VARCHAR(255),
    @Designation VARCHAR(100) = NULL,
    @Gender VARCHAR(20) = NULL,
    @Mobile VARCHAR(30) = NULL,
    @JoiningDate DATE = NULL,
    @DateOfBirth DATE = NULL,
    @ProfilePictureUrl NVARCHAR(MAX) = NULL,
    @FatherOrSpouse NVARCHAR(100) = NULL,
    @PresentAddress NVARCHAR(255) = NULL,
    @PermanentAddress NVARCHAR(255) = NULL,
    @EmployeePfNo NVARCHAR(50) = NULL,
    @EmployeeEsicNo NVARCHAR(50) = NULL,
    @EmployeeAadharNo NVARCHAR(20) = NULL,
    @Days80ServiceCompletionDate DATE = NULL,
    @PermanentAppointmentDate DATE = NULL,
    @PeriodOfSuspension INT = NULL,
    @SignatureImageUrl NVARCHAR(255) = NULL,
    @ThumbImpressionImageUrl NVARCHAR(255) = NULL,
    @DateOfExit DATE = NULL,
    @ReasonForExit NVARCHAR(255) = NULL, 
    @Department NVARCHAR(100) = NULL, 
    @Remarks NVARCHAR(255) = NULL, 
    @CustomFieldsJson NVARCHAR(MAX) = NULL,
    @LastUpdatedBy INT = NULL
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

-- ══════════════════════════════════════════════════════════
-- ADDITIONAL UTILITY PROCEDURES
-- ══════════════════════════════════════════════════════════

CREATE OR ALTER PROCEDURE sp_OrganizationExistsById
    @OrgId INT
AS
BEGIN
    SELECT COUNT(*) FROM organizations WHERE id = @OrgId;
END;
GO

CREATE OR ALTER PROCEDURE sp_GetEmployeeById
    @Id INT,
    @OrganizationId INT = NULL
AS
BEGIN
    SELECT * FROM employees 
    WHERE id = @Id AND (@OrganizationId IS NULL OR organization_id = @OrganizationId);
END;
GO

CREATE OR ALTER PROCEDURE sp_UpdateEmployeePhoto
    @Id INT,
    @Url NVARCHAR(MAX) = NULL,
    @LastUpdatedBy INT = NULL
AS
BEGIN
    UPDATE employees SET profile_picture_url = @Url, updated_at = GETDATE(), last_updated_by = @LastUpdatedBy
    WHERE id = @Id;
END;
GO

CREATE OR ALTER PROCEDURE sp_GetEmployeeAccountDetails
    @EmployeeId INT
AS
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
        UPDATE SET 
            account_number = @AccountNumber,
            account_holder_name = @AccountHolderName,
            branch = @Branch,
            ifsc = @Ifsc,
            updated_at = GETDATE(),
            last_updated_by = @LastUpdatedBy
    WHEN NOT MATCHED THEN
        INSERT (employee_id, organization_id, account_number, account_holder_name, branch, ifsc, created_at, updated_at, created_by, last_updated_by)
        VALUES (@EmployeeId, @OrganizationId, @AccountNumber, @AccountHolderName, @Branch, @Ifsc, GETDATE(), GETDATE(), @CreatedBy, @LastUpdatedBy);
END;
GO

CREATE OR ALTER PROCEDURE sp_UpdateEmployeeSignature
    @Id INT,
    @Url NVARCHAR(MAX) = NULL,
    @LastUpdatedBy INT = NULL
AS
BEGIN
    UPDATE employees SET signature_image_url = @Url, updated_at = GETDATE(), last_updated_by = @LastUpdatedBy
    WHERE id = @Id;
END;
GO

-- ══════════════════════════════════════════════════════════
-- DYNAMIC FORM PROCEDURES
-- ══════════════════════════════════════════════════════════

CREATE OR ALTER PROCEDURE sp_GetEmployeeFormFields
    @OrgId INT
AS
BEGIN
    SELECT 
        f.id, f.field_key, f.display_label, f.section_name, f.section_order, f.field_order,
        f.grid_size, f.component_type, f.options_json,
        CAST(COALESCE(a.is_visible, 1) AS INT) as IsVisible, 
        CAST(COALESCE(a.is_mandatory, 0) AS INT) as IsMandatory, 
        COALESCE(a.custom_label, f.display_label) as CustomLabel,
        CAST(f.is_core_field AS INT) as IsCoreField
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

CREATE OR ALTER PROCEDURE sp_CheckFieldKeyExists
    @FieldKey NVARCHAR(50)
AS
BEGIN
    SELECT COUNT(*) FROM employee_data_fields WHERE field_key = @FieldKey;
END;
GO

CREATE OR ALTER PROCEDURE sp_CreateMasterField
    @FieldKey NVARCHAR(50),
    @DisplayLabel NVARCHAR(100),
    @SectionName NVARCHAR(50),
    @SectionOrder INT,
    @FieldOrder INT,
    @GridSize INT,
    @ComponentType NVARCHAR(50),
    @OptionsJson NVARCHAR(MAX) = NULL,
    @CreatedBy INT = NULL
AS
BEGIN
    INSERT INTO employee_data_fields 
        (field_key, display_label, section_name, section_order, field_order, grid_size, component_type, options_json, is_core_field, created_by, last_updated_by)
    OUTPUT INSERTED.id
    VALUES 
        (@FieldKey, @DisplayLabel, @SectionName, @SectionOrder, @FieldOrder, @GridSize, @ComponentType, @OptionsJson, 0, @CreatedBy, @CreatedBy);
END;
GO

CREATE OR ALTER PROCEDURE sp_DeleteMasterField
    @Id INT
AS
BEGIN
    -- Check if it's a core field
    IF EXISTS (SELECT 1 FROM employee_data_fields WHERE id = @Id AND is_core_field = 1)
    BEGIN
        RETURN;
    END

    -- Remove org mappings
    DELETE FROM emp_data_use_fields WHERE field_id = @Id;
    -- Remove master definition
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

-- ══════════════════════════════════════════════════════════
-- DEPARTMENT & DESIGNATION PROCEDURES
-- ══════════════════════════════════════════════════════════

-- 1. Get Departments by Organization
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

-- 2. Insert Department
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

-- 3. Update Department
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

-- 4. Delete Department
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

-- 5. Get Designations by Organization
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

-- 6. Insert Designation
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

-- 7. Update Designation
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

-- 8. Delete Designation
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


---calender settings

CREATE TABLE OrganizationCalendarSettings (
    id INT PRIMARY KEY IDENTITY(1,1),

    organization_id INT UNIQUE NOT NULL,   -- ensures one row per organization

    academic_start_month INT,
    academic_start_day INT,

    academic_end_month INT,
    academic_end_day INT,

    salary_start_day INT,   -- Example: Feb 10
    salary_end_day INT,     -- Example: Mar 9


    created_by_id INT,
    created_by_name VARCHAR(100),

    created_at DATETIME DEFAULT GETDATE(),

    updated_by_id INT,
    updated_by_name VARCHAR(100),
    updated_at DATETIME DEFAULT GETDATE()
);
GO

CREATE PROCEDURE sp_GetOrganizationCalendarSettings
    @OrganizationID INT
AS
BEGIN
    SELECT * FROM OrganizationCalendarSettings WHERE organization_id = @OrganizationID;
END;
GO

CREATE PROCEDURE sp_UpsertOrganizationCalendarSettings
    @OrganizationID INT,
    @AcademicStartMonth INT,
    @AcademicStartDay INT,
    @AcademicEndMonth INT,
    @AcademicEndDay INT,
    @SalaryStartDay INT,
    @SalaryEndDay INT,
    @UserID INT,
    @UserName VARCHAR(100)
AS
BEGIN
    IF EXISTS (SELECT 1 FROM OrganizationCalendarSettings WHERE organization_id = @OrganizationID)
    BEGIN
        UPDATE OrganizationCalendarSettings
        SET academic_start_month = @AcademicStartMonth,
            academic_start_day = @AcademicStartDay,
            academic_end_month = @AcademicEndMonth,
            academic_end_day = @AcademicEndDay,
            salary_start_day = @SalaryStartDay,
            salary_end_day = @SalaryEndDay,
            updated_by_id = @UserID,
            updated_by_name = @UserName,
            updated_at = GETDATE()
        WHERE organization_id = @OrganizationID;
    END
    ELSE
    BEGIN
        INSERT INTO OrganizationCalendarSettings (
            organization_id, 
            academic_start_month, academic_start_day, 
            academic_end_month, academic_end_day, 
            salary_start_day, salary_end_day, 
            created_by_id, created_by_name, created_at,
            updated_by_id, updated_by_name, updated_at
        )
        VALUES (
            @OrganizationID, 
            @AcademicStartMonth, @AcademicStartDay, 
            @AcademicEndMonth, @AcademicEndDay, 
            @SalaryStartDay, @SalaryEndDay, 
            @UserID, @UserName, GETDATE(),
            @UserID, @UserName, GETDATE()
        );
    END
END;
GO