IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ProfessionalTax')
BEGIN 
CREATE TABLE ProfessionalTax (
    PTId INT IDENTITY(1,1) PRIMARY KEY,
    TaxName NVARCHAR(100) NOT NULL, 
    FromAmount DECIMAL(18, 2) NOT NULL,
    ToAmount DECIMAL(18, 2) NOT NULL,
    TaxAmount DECIMAL(18, 2) NOT NULL,
    OrganizationId INT NOT NULL,
    IsActive BIT DEFAULT 1,
    CreatedDateTime DATETIME DEFAULT GETDATE(),
    CreatedBy INT NULL,
    CONSTRAINT FK_ProfessionalTax_Organization FOREIGN KEY (OrganizationId) REFERENCES organizations(id)
);
END;

GO

-- CREATE STORED PROCEDURES

CREATE OR ALTER PROCEDURE sp_CreateProfessionalTax
    @TaxName NVARCHAR(100),
    @FromAmount DECIMAL(18, 2),
    @ToAmount DECIMAL(18, 2),
    @TaxAmount DECIMAL(18, 2),
    @OrganizationId INT,
    @IsActive BIT,
    @CreatedBy INT
AS
BEGIN
    INSERT INTO ProfessionalTax (TaxName, FromAmount, ToAmount, TaxAmount, OrganizationId, IsActive, CreatedBy)
    VALUES (@TaxName, @FromAmount, @ToAmount, @TaxAmount, @OrganizationId, @IsActive, @CreatedBy);
END;

GO

CREATE OR ALTER PROCEDURE sp_UpdateProfessionalTax
    @PTId INT,
    @TaxName NVARCHAR(100),
    @FromAmount DECIMAL(18, 2),
    @ToAmount DECIMAL(18, 2),
    @TaxAmount DECIMAL(18, 2),
    @OrganizationId INT,
    @IsActive BIT,
    @CreatedBy INT
AS
BEGIN
    UPDATE ProfessionalTax
    SET TaxName = @TaxName,
        FromAmount = @FromAmount,
        ToAmount = @ToAmount,
        TaxAmount = @TaxAmount,
        OrganizationId = @OrganizationId,
        IsActive = @IsActive,
        CreatedBy = @CreatedBy
    WHERE PTId = @PTId;
END;

GO

CREATE OR ALTER PROCEDURE sp_GetProfessionalTaxByOrgId
    @OrganizationId INT
AS
BEGIN
    SELECT * FROM ProfessionalTax WHERE OrganizationId = @OrganizationId AND IsActive = 1;
END;

GO

CREATE OR ALTER PROCEDURE sp_DeleteProfessionalTax
    @PTId INT
AS
BEGIN
    DELETE FROM ProfessionalTax WHERE PTId = @PTId;
END;