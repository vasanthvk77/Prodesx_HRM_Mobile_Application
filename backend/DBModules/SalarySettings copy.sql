IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SalarySettings')
BEGIN
    CREATE TABLE SalarySettings (
        SSId INT IDENTITY(1,1) PRIMARY KEY,
        OrganizationId INT NOT NULL,
        SalaryYearId INT NOT NULL,
        EmployeeId INT NOT NULL,
        BasicPay DECIMAL(18,2) NOT NULL DEFAULT 0.00,
        CreatedBy INT NOT NULL,
        CreatedDateTime DATETIME DEFAULT GETDATE(),
        UpdatedBy INT NULL,
        UpdatedDateTime DATETIME NULL,
        
        -- Foreign Keys
        -- Note: references organizations(id) is lowercase to match schema.sql
        CONSTRAINT FK_SalarySettings_Organization FOREIGN KEY (OrganizationId) REFERENCES organizations(id),
        CONSTRAINT FK_SalarySettings_SalaryYear FOREIGN KEY (SalaryYearId) REFERENCES SalaryYear(SalaryYearId),
        CONSTRAINT FK_SalarySettings_Employee FOREIGN KEY (EmployeeId) REFERENCES employees(id),
        
        -- Prevent duplicates: One basic salary per employee per financial year
        CONSTRAINT UK_SalarySettings_Emp_Year UNIQUE (SalaryYearId, EmployeeId),
        
        -- Ensure salary isn't negative
        CONSTRAINT CHK_BasicPay_Positive CHECK (BasicPay >= 0)
    );
END
GO

CREATE OR ALTER PROCEDURE sp_InsertSalarySettings
    @OrganizationId INT,
    @SalaryYearId INT,
    @EmployeeId INT,
    @BasicPay DECIMAL(18,2),
    @CreatedBy INT,
    @CreatedDateTime DATETIME
AS
BEGIN
    INSERT INTO SalarySettings (
        OrganizationId,
        SalaryYearId,
        EmployeeId,
        BasicPay,
        CreatedBy,
        CreatedDateTime
    )
    OUTPUT INSERTED.SSId
    VALUES (
        @OrganizationId,
        @SalaryYearId,
        @EmployeeId,
        @BasicPay,
        @CreatedBy,
        @CreatedDateTime
    );
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateSalarySettings
    @SSId INT,
    @OrganizationId INT,
    @SalaryYearId INT,
    @EmployeeId INT,
    @BasicPay DECIMAL(18,2),
    @UpdatedBy INT,
    @UpdatedDateTime DATETIME
AS
BEGIN
    UPDATE SalarySettings
    SET 
        OrganizationId = @OrganizationId,
        SalaryYearId = @SalaryYearId,
        EmployeeId = @EmployeeId,
        BasicPay = @BasicPay,
        UpdatedBy = @UpdatedBy,
        UpdatedDateTime = @UpdatedDateTime
    WHERE SSId = @SSId;
END
GO

CREATE OR ALTER PROCEDURE sp_DeleteSalarySettings
    @SSId INT
AS
BEGIN
    DELETE FROM SalarySettings
    WHERE SSId = @SSId;
END
GO

CREATE OR ALTER PROCEDURE sp_GetSalarySettings
    @OrganizationId INT,
    @SalaryYearId INT
AS
BEGIN
    SELECT 
        ss.*,
        e.name AS EmployeeName,
        e.employee_code AS EmployeeCode
    FROM SalarySettings ss
    INNER JOIN employees e ON e.id = ss.EmployeeId
    WHERE ss.OrganizationId = @OrganizationId
    AND ss.SalaryYearId = @SalaryYearId;
END
GO