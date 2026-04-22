IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SalaryYear')
BEGIN
    CREATE TABLE SalaryYear (
        SalaryYearId INT IDENTITY(1,1) PRIMARY KEY,
        OrganizationID INT NOT NULL,
        FromYear VARCHAR(4) NOT NULL,
        ToYear VARCHAR(4) NOT NULL,
        DateFrom DATE NOT NULL,
        DateTo DATE NOT NULL,
        CreatedBy INT NOT NULL,
        CreatedDate DATETIME DEFAULT GETDATE(),
        
        CONSTRAINT FK_SalaryYear_Organization FOREIGN KEY (OrganizationID) REFERENCES organizations(id),
        CONSTRAINT UK_SalaryYear_Org_Year UNIQUE (OrganizationID, FromYear)
    );
END
GO

CREATE OR ALTER PROCEDURE sp_GetSalaryYearByOrganizationID
    @OrganizationID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM SalaryYear WHERE OrganizationID = @OrganizationID;
END
GO

CREATE OR ALTER PROCEDURE sp_GetSalaryYearById
    @SalaryYearId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM SalaryYear WHERE SalaryYearId = @SalaryYearId;
END
GO

CREATE OR ALTER PROCEDURE sp_AddSalaryYear
    @OrganizationID INT,
    @FromYear VARCHAR(4),
    @ToYear VARCHAR(4),
    @DateFrom DATE,
    @DateTo DATE,
    @CreatedBy INT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO SalaryYear (OrganizationID, FromYear, ToYear, DateFrom, DateTo, CreatedBy)
    VALUES (@OrganizationID, @FromYear, @ToYear, @DateFrom, @DateTo, @CreatedBy);
END
GO

CREATE OR ALTER PROCEDURE sp_UpdateSalaryYear
    @SalaryYearId INT,
    @OrganizationID INT,
    @FromYear VARCHAR(4),
    @ToYear VARCHAR(4),
    @DateFrom DATE,
    @DateTo DATE,
    @CreatedBy INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE SalaryYear
    SET OrganizationID = @OrganizationID,
        FromYear = @FromYear,
        ToYear = @ToYear,
        DateFrom = @DateFrom,
        DateTo = @DateTo,
        CreatedBy = @CreatedBy
    WHERE SalaryYearId = @SalaryYearId;
END
GO

CREATE OR ALTER PROCEDURE sp_DeleteSalaryYear
    @SalaryYearId INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM SalaryYear WHERE SalaryYearId = @SalaryYearId;
END
GO
