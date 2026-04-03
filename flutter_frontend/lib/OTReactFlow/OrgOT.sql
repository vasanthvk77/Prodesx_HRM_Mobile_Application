IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'EmployeeOverDuty')
BEGIN
CREATE TABLE EmployeeOverDuty (
    OverDutyId INT IDENTITY(1,1) PRIMARY KEY,
    OrganizationId INT NOT NULL,
    EmployeeId INT NOT NULL,
    OverDutyDate DATE NOT NULL,   -- 👈 Better than Month/Year
    Hours DECIMAL(5,2) NOT NULL,  -- e.g., 2.5 hours
    RatePerHour DECIMAL(10,2) NULL, -- optional (can derive from salary)
    Amount AS (Hours * ISNULL(RatePerHour, 0)) PERSISTED,
    Remarks NVARCHAR(250),
    CreatedDateTime DATETIME DEFAULT GETDATE(),
    CreatedBy INT NULL,

    FOREIGN KEY (OrganizationId) REFERENCES organizations(id)
);
END
GO

IF OBJECT_ID('sp_UpdateOT', 'P') IS NOT NULL DROP PROCEDURE sp_UpdateOT;
GO
CREATE PROCEDURE sp_UpdateOT
    @OverDutyId INT,
    @OrganizationId INT,
    @EmployeeId INT,
    @OverDutyDate DATE,
    @Hours DECIMAL(5,2),
    @RatePerHour DECIMAL(10,2),
    @Remarks NVARCHAR(250),
    @CreatedBy INT
AS
BEGIN
    UPDATE EmployeeOverDuty
    SET 
        OrganizationId = @OrganizationId,
        EmployeeId = @EmployeeId,
        OverDutyDate = @OverDutyDate,
        Hours = @Hours,
        RatePerHour = @RatePerHour,
        Remarks = @Remarks,
        CreatedBy = @CreatedBy
    WHERE OverDutyId = @OverDutyId;
END;

GO

IF OBJECT_ID('sp_SaveOT', 'P') IS NOT NULL DROP PROCEDURE sp_SaveOT;
GO
CREATE PROCEDURE sp_SaveOT
    @OrganizationId INT,
    @EmployeeId INT,
    @OverDutyDate DATE,
    @Hours DECIMAL(5,2),
    @RatePerHour DECIMAL(10,2),
    @Remarks NVARCHAR(250),
    @CreatedBy INT
AS
BEGIN
    INSERT INTO EmployeeOverDuty (
        OrganizationId,
        EmployeeId,
        OverDutyDate,
        Hours,
        RatePerHour,
        Remarks,
        CreatedBy
    )
    VALUES (
        @OrganizationId,
        @EmployeeId,
        @OverDutyDate,
        @Hours,
        @RatePerHour,
        @Remarks,
        @CreatedBy
    );
END;

GO

IF OBJECT_ID('sp_GetOTByOrgId', 'P') IS NOT NULL DROP PROCEDURE sp_GetOTByOrgId;
GO
CREATE PROCEDURE sp_GetOTByOrgId
    @OrganizationId INT
AS
BEGIN
    SELECT * FROM EmployeeOverDuty WHERE OrganizationId = @OrganizationId;
END;

GO

IF OBJECT_ID('sp_GetOTByEmpId', 'P') IS NOT NULL DROP PROCEDURE sp_GetOTByEmpId;
GO
CREATE PROCEDURE sp_GetOTByEmpId
    @EmployeeId INT
AS
BEGIN
    SELECT * FROM EmployeeOverDuty WHERE EmployeeId = @EmployeeId;
END;

GO

IF OBJECT_ID('sp_DeleteOT', 'P') IS NOT NULL DROP PROCEDURE sp_DeleteOT;
GO
CREATE PROCEDURE sp_DeleteOT
    @OverDutyId INT
AS
BEGIN
    DELETE FROM EmployeeOverDuty WHERE OverDutyId = @OverDutyId;
END;