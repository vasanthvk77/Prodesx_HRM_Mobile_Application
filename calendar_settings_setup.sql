-- 1. Create the table
CREATE TABLE OrganizationCalendarSettings (
    id INT PRIMARY KEY IDENTITY(1,1),
    organization_id INT UNIQUE NOT NULL,

    academic_start_month INT,
    academic_start_day INT,
    academic_end_month INT,
    academic_end_day INT,

    salary_start_day INT,
    salary_end_day INT,

    created_by_id INT,
    created_by_name VARCHAR(100),
    created_at DATETIME DEFAULT GETDATE(),

    updated_by_id INT,
    updated_by_name VARCHAR(100),
    updated_at DATETIME DEFAULT GETDATE()
);
GO

-- 2. Stored Procedure to Fetch Settings
CREATE PROCEDURE sp_GetOrganizationCalendarSettings
    @OrganizationID INT
AS
BEGIN
    SELECT * FROM OrganizationCalendarSettings WHERE organization_id = @OrganizationID;
END;
GO

-- 3. Stored Procedure to Upsert Settings
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
