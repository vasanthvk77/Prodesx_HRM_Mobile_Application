-- ── Staff Salary Master Table (Meta-data for a payroll run) ────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'StaffSalaryMaster')
BEGIN
    CREATE TABLE StaffSalaryMaster (
        SalaryMasterId BIGINT IDENTITY(1,1) PRIMARY KEY,
        OrganizationId INT NOT NULL,
        SalaryYearId INT NOT NULL,
        [Month] TINYINT NOT NULL,
        IsFinalized BIT NOT NULL DEFAULT 0,
        CreatedBy INT NOT NULL,
        CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),

        CONSTRAINT FK_SalaryMaster_Year FOREIGN KEY (SalaryYearId) REFERENCES SalaryYear(SalaryYearId)
    );
    -- Unique index to prevent duplicate runs for the same Org/Year/Month
    CREATE UNIQUE INDEX UK_StaffSalaryMaster_Org_Year_Month ON StaffSalaryMaster (OrganizationId, SalaryYearId, [Month]);
END
GO

-- ── Staff Salary Table (Individual employee records) ──────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'StaffSalary')
BEGIN
    CREATE TABLE StaffSalary (
        SalaryId BIGINT IDENTITY(1,1) PRIMARY KEY,
        SalaryMasterId BIGINT NOT NULL,
        EmployeeId INT NOT NULL,
        
        -- Snapshot columns (stored at time of generation)
        BaseBasicPay DECIMAL(18,2) NOT NULL DEFAULT 0,
        PresentDays DECIMAL(18,2) NOT NULL DEFAULT 0,
        TotalDaysInMonth TINYINT NOT NULL DEFAULT 0,
        AllowancesDetail NVARCHAR(MAX) NULL, -- JSON Breakdown
        DeductionsDetail NVARCHAR(MAX) NULL, -- JSON Breakdown

        -- Core financial columns
        NetSalary DECIMAL(18,2) NOT NULL, -- This is the 'Earned' Basic Pay (pro-rated)
        TotalAllowance DECIMAL(18,2) NOT NULL,
        TotalDeduction DECIMAL(18,2) NOT NULL,
        
        -- Computed Columns (for convenience)
        TotalSalWithoutDeduction AS (NetSalary + TotalAllowance),
        GrossSalary AS (NetSalary + TotalAllowance - TotalDeduction), 
        
        -- Audit Columns
        CreatedBy INT NOT NULL,
        CreatedDate DATETIME DEFAULT GETDATE(),

        CONSTRAINT FK_StaffSalary_Master FOREIGN KEY (SalaryMasterId) REFERENCES StaffSalaryMaster(SalaryMasterId),
        CONSTRAINT FK_StaffSalary_Emp FOREIGN KEY (EmployeeId) REFERENCES Employees(Id),
        
        -- One salary record per employee per master run
        CONSTRAINT UK_StaffSalary_Emp_Master UNIQUE (EmployeeId, SalaryMasterId)
    );
END
ELSE
BEGIN
    -- 1. Add Master-Detail Link
    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('StaffSalary') AND name = 'SalaryMasterId')
        ALTER TABLE StaffSalary ADD SalaryMasterId BIGINT NULL;

    -- 2. Add Snapshot Columns (for historical data integrity)
    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('StaffSalary') AND name = 'BaseBasicPay')
        ALTER TABLE StaffSalary ADD BaseBasicPay DECIMAL(18,2) NOT NULL DEFAULT 0;
    
    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('StaffSalary') AND name = 'PresentDays')
        ALTER TABLE StaffSalary ADD PresentDays DECIMAL(18,2) NOT NULL DEFAULT 0;

    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('StaffSalary') AND name = 'TotalDaysInMonth')
        ALTER TABLE StaffSalary ADD TotalDaysInMonth TINYINT NOT NULL DEFAULT 0;

    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('StaffSalary') AND name = 'AllowancesDetail')
        ALTER TABLE StaffSalary ADD AllowancesDetail NVARCHAR(MAX) NULL;

    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('StaffSalary') AND name = 'DeductionsDetail')
        ALTER TABLE StaffSalary ADD DeductionsDetail NVARCHAR(MAX) NULL;
END
GO

-- ── Stored Procedures ──────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE sp_GetStaffSalariesByOrg
    @OrganizationId INT
AS
BEGIN
    SELECT ss.*, ssm.SalaryYearId, ssm.[Month], ssm.IsFinalized, 
           e.name AS EmployeeName, e.employee_code AS EmployeeCode, e.profile_picture_url AS ProfilePictureUrl
    FROM StaffSalary ss
    INNER JOIN StaffSalaryMaster ssm ON ss.SalaryMasterId = ssm.SalaryMasterId
    INNER JOIN Employees e ON ss.EmployeeId = e.id
    WHERE ssm.OrganizationId = @OrganizationId
    ORDER BY ss.CreatedDate DESC
END
GO

CREATE OR ALTER PROCEDURE sp_GetStaffSalaryById
    @SalaryId BIGINT
AS
BEGIN
    SELECT ss.*, ssm.SalaryYearId, ssm.[Month], ssm.IsFinalized, 
           e.name AS EmployeeName, e.employee_code AS EmployeeCode, e.profile_picture_url AS ProfilePictureUrl
    FROM StaffSalary ss
    INNER JOIN StaffSalaryMaster ssm ON ss.SalaryMasterId = ssm.SalaryMasterId
    INNER JOIN Employees e ON ss.EmployeeId = e.id
    WHERE ss.SalaryId = @SalaryId
END
GO

CREATE OR ALTER PROCEDURE sp_GetStaffSalariesByEmployeeId
    @EmployeeId INT
AS
BEGIN
    SELECT ss.*, ssm.SalaryYearId, ssm.[Month], ssm.IsFinalized, 
           e.name AS EmployeeName, e.employee_code AS EmployeeCode, e.profile_picture_url AS ProfilePictureUrl
    FROM StaffSalary ss
    INNER JOIN StaffSalaryMaster ssm ON ss.SalaryMasterId = ssm.SalaryMasterId
    INNER JOIN Employees e ON ss.EmployeeId = e.id
    WHERE ss.EmployeeId = @EmployeeId
    ORDER BY ssm.SalaryYearId DESC, ssm.[Month] DESC
END
GO

CREATE OR ALTER PROCEDURE sp_GetMonthlySalaryPreview
    @OrganizationId INT,
    @SalaryYearId INT,
    @Month TINYINT,
    @Year INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        e.id AS EmployeeId,
        e.name AS EmployeeName,
        e.employee_code AS EmployeeCode,
        e.profile_picture_url AS ProfilePictureUrl,
        ISNULL(ss.BasicPay, 0) AS BaseBasicPay,
        att.TotalDaysInMonth,
        att.PresentDays,

        -- Calculated Totals (CROSS APPLY results)
        ISNULL(allow.TotalAllowance, 0) AS TotalAllowance,
        ISNULL(allow.TotalBaseAllowance, 0) AS TotalBaseAllowance,
        ISNULL(deduct.TotalDeduction, 0) AS TotalDeduction,

        -- Allowances JSON Breakdown (Includes Base and Calculated for UI/Payslip)
        (
            SELECT a.FullName AS [name], 
                   sa.Amount AS [baseAmount],
                   sa.CalType AS [calType],
                   (CASE 
                        WHEN sa.CalType = 0 THEN (calc.EarnedBasic * sa.Amount / 100.0) 
                        ELSE (sa.Amount * (CAST(att.PresentDays AS DECIMAL(18,2)) / NULLIF(CAST(att.TotalDaysInMonth AS DECIMAL(18,2)), 0))) 
                    END) AS [amount]
            FROM StaffAllowance sa 
            JOIN Allowances a ON sa.AllowenceId = a.AllowencesId 
            WHERE sa.EmployeeID = e.id 
            FOR JSON PATH
        ) AS AllowancesDetail,

        -- Deductions JSON Breakdown (UNCHANGED as per user request)
        ISNULL(deduct.DeductionsDetail, '[]') AS DeductionsDetail,

        -- Check if it is already generated/finalized
        CAST(ISNULL((
            SELECT ssm.IsFinalized 
            FROM StaffSalaryMaster ssm
            WHERE ssm.OrganizationId = @OrganizationId AND ssm.SalaryYearId = @SalaryYearId AND ssm.[Month] = @Month
        ), 0) AS BIT) AS IsFinalized

    FROM employees e
    LEFT JOIN SalarySettings ss ON e.id = ss.EmployeeId AND ss.SalaryYearId = @SalaryYearId
    LEFT JOIN (
        -- Consolidate Statutory Settings into a single row per Org for easy joining
        SELECT OrganizationId,
               MAX(CASE WHEN ShortCode = 'PF' THEN IsActive ELSE 0 END) AS IsPFActive,
               MAX(CASE WHEN ShortCode = 'ESI' THEN IsActive ELSE 0 END) AS IsESIActive,
               MAX(CASE WHEN ShortCode = 'PF' THEN Percentage ELSE 0 END) AS PFPercentage,
               MAX(CASE WHEN ShortCode = 'PF' THEN CapAmount ELSE 0 END) AS PFCapAmount,
               MAX(CASE WHEN ShortCode = 'ESI' THEN Percentage ELSE 0 END) AS ESIPercentage
        FROM (
            SELECT 
                @OrganizationId AS OrganizationId,
                m.ShortCode,
                ISNULL(s.IsActive, 0) AS IsActive,
                ISNULL(s.OverridePercentage, m.DefaultPercentage) AS Percentage,
                ISNULL(s.OverrideCapAmount, m.DefaultCapAmount) AS CapAmount
            FROM StatutoryMaster m
            LEFT JOIN OrganizationStatutorySettings s ON m.StatutoryId = s.StatutoryId AND s.OrganizationId = @OrganizationId
        ) t
        GROUP BY OrganizationId
    ) ops ON e.organization_id = ops.OrganizationId
    CROSS APPLY (
        SELECT 
            DAY(EOMONTH(DATEFROMPARTS(@Year, @Month, 1))) AS TotalDaysInMonth,
            ISNULL((
                SELECT SUM(CASE WHEN ltf.ShortName = 'P' THEN 0.5 ELSE 0 END + CASE WHEN lts.ShortName = 'P' THEN 0.5 ELSE 0 END)
                FROM StaffAttendance sa
                JOIN AttendanceMaster am ON sa.AttendanceSettingId = am.AttendanceSettingId
                LEFT JOIN LeaveType ltf ON sa.FH = ltf.LeaveTypeId
                LEFT JOIN LeaveType lts ON sa.SH = lts.LeaveTypeId
                WHERE sa.EmployeeId = e.id AND MONTH(am.Date) = @Month AND YEAR(am.Date) = @Year
            ), 0) AS PresentDays
    ) att
    CROSS APPLY (
        SELECT (CASE WHEN att.TotalDaysInMonth > 0 
                     THEN (ISNULL(ss.BasicPay, 0) / CAST(att.TotalDaysInMonth AS DECIMAL(18,2))) * att.PresentDays 
                     ELSE 0 END) AS EarnedBasic
    ) calc
    OUTER APPLY (
        SELECT SUM(t.ItemAmount) AS TotalAllowance,
               SUM(t.BaseValue) AS TotalBaseAllowance,
               SUM(CASE WHEN t.ShortName = 'DA' THEN t.ItemAmount ELSE 0 END) AS TotalDA
        FROM (
            SELECT (CASE 
                        WHEN sa.CalType = 0 THEN (calc.EarnedBasic * sa.Amount / 100.0) 
                        ELSE (sa.Amount * (CAST(att.PresentDays AS DECIMAL(18,2)) / NULLIF(CAST(att.TotalDaysInMonth AS DECIMAL(18,2)), 0))) 
                    END) AS ItemAmount,
                   (CASE 
                        WHEN sa.CalType = 0 THEN (ISNULL(ss.BasicPay, 0) * sa.Amount / 100.0) 
                        ELSE sa.Amount 
                    END) AS BaseValue,
                   a.ShortName
            FROM StaffAllowance sa 
            JOIN Allowances a ON sa.AllowenceId = a.AllowencesId
            WHERE sa.EmployeeID = e.id
        ) t
    ) allow
    CROSS APPLY (
        -- Statutory Deductions Logic (Now uses EarnedBasic + DA for PF)
        SELECT 
            -- PF: Round(Min(EarnedBasic + DA, Cap) * Rate%, 0)
            ISNULL(CASE WHEN ops.IsPFActive = 1 THEN ROUND(CASE WHEN (calc.EarnedBasic + ISNULL(allow.TotalDA, 0)) > ops.PFCapAmount THEN ops.PFCapAmount ELSE (calc.EarnedBasic + ISNULL(allow.TotalDA, 0)) END * (ops.PFPercentage / 100.0), 0) ELSE 0 END, 0) AS CalculatedPF,
            -- ESI: Ceiling((EarnedBasic + Allow) * Rate%)
            ISNULL(CASE WHEN ops.IsESIActive = 1 THEN CEILING((calc.EarnedBasic + ISNULL(allow.TotalAllowance, 0)) * (ops.ESIPercentage / 100.0)) ELSE 0 END, 0) AS CalculatedESI
    ) stat
    OUTER APPLY (
        SELECT SUM(t.ItemAmount) AS TotalDeduction,
                (
                   SELECT [name], [baseAmount], [calType], [amount] FROM (
                       -- Static Deductions (PRO-RATED for LOP)
                       SELECT d.FullName AS [name], 
                              sd.Amount AS [baseAmount],
                              sd.CalType AS [calType],
                              (CASE 
                                   WHEN sd.CalType = 0 THEN (calc.EarnedBasic * sd.Amount / 100.0) 
                                   ELSE (sd.Amount * (CAST(att.PresentDays AS DECIMAL(18,2)) / NULLIF(CAST(att.TotalDaysInMonth AS DECIMAL(18,2)), 0))) 
                               END) AS [amount]
                       FROM StaffDeductions sd 
                       JOIN Deductions d ON sd.DeductionId = d.DeductionsId 
                       WHERE sd.EmployeeID = e.id
                       UNION ALL
                       -- Dynamic PF (Short-term storage)
                       SELECT 'PF' AS [name], NULL AS [baseAmount], 0 AS [calType], stat.CalculatedPF AS [amount] WHERE stat.CalculatedPF > 0
                       UNION ALL
                       -- Dynamic ESI
                       SELECT 'ESI' AS [name], NULL AS [baseAmount], 0 AS [calType], stat.CalculatedESI AS [amount] WHERE stat.CalculatedESI > 0
                   ) d_sub
                   FOR JSON PATH
               ) AS DeductionsDetail
        FROM (
            SELECT (CASE 
                        WHEN sd.CalType = 0 THEN (calc.EarnedBasic * sd.Amount / 100.0) 
                        ELSE (sd.Amount * (CAST(att.PresentDays AS DECIMAL(18,2)) / NULLIF(CAST(att.TotalDaysInMonth AS DECIMAL(18,2)), 0))) 
                    END) AS ItemAmount
            FROM StaffDeductions sd WHERE sd.EmployeeID = e.id
            UNION ALL SELECT stat.CalculatedPF
            UNION ALL SELECT stat.CalculatedESI
        ) t
    ) deduct
    WHERE e.organization_id = @OrganizationId AND e.status = 'Active';
END
GO


CREATE OR ALTER PROCEDURE sp_UpsertStaffSalary
    @OrganizationId INT,
    @SalaryYearId INT,
    @Month TINYINT,
    @EmployeeId INT,
    @BaseBasicPay DECIMAL(18,2),
    @PresentDays DECIMAL(18,2),
    @TotalDaysInMonth TINYINT,
    @AllowancesDetail NVARCHAR(MAX),
    @DeductionsDetail NVARCHAR(MAX),
    @NetSalary DECIMAL(18,2), -- Calculated pro-rated basic
    @TotalAllowance DECIMAL(18,2),
    @TotalDeduction DECIMAL(18,2),
    @CreatedBy INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MasterId BIGINT;

    -- 1. Ensure a Master record exists for this Org/Year/Month (Handle Race Condition)
    SELECT @MasterId = SalaryMasterId FROM StaffSalaryMaster WITH (UPDLOCK, HOLDLOCK)
    WHERE OrganizationId = @OrganizationId AND SalaryYearId = @SalaryYearId AND [Month] = @Month;

    IF @MasterId IS NULL
    BEGIN
        BEGIN TRY
            INSERT INTO StaffSalaryMaster (OrganizationId, SalaryYearId, [Month], IsFinalized, CreatedBy, CreatedDate)
            VALUES (@OrganizationId, @SalaryYearId, @Month, 0, @CreatedBy, GETDATE());
            
            SET @MasterId = SCOPE_IDENTITY();
        END TRY
        BEGIN CATCH
            -- If another thread just inserted it, grab the ID
            SELECT @MasterId = SalaryMasterId FROM StaffSalaryMaster 
            WHERE OrganizationId = @OrganizationId AND SalaryYearId = @SalaryYearId AND [Month] = @Month;
            
            IF @MasterId IS NULL THROW; -- Re-throw if it wasn't a duplicate key issue
        END CATCH
    END

    -- 2. Check if Master is already finalized
    IF (SELECT IsFinalized FROM StaffSalaryMaster WHERE SalaryMasterId = @MasterId) = 1
    BEGIN
        RAISERROR('Cannot update salary because this payroll run has already been finalized.', 16, 1);
        RETURN;
    END

    -- 3. Upsert individual record
    IF EXISTS (SELECT 1 FROM StaffSalary WHERE EmployeeId = @EmployeeId AND SalaryMasterId = @MasterId)
    BEGIN
        UPDATE StaffSalary
        SET BaseBasicPay = @BaseBasicPay,
            PresentDays = @PresentDays,
            TotalDaysInMonth = @TotalDaysInMonth,
            AllowancesDetail = @AllowancesDetail,
            DeductionsDetail = @DeductionsDetail,
            NetSalary = @NetSalary,
            TotalAllowance = @TotalAllowance,
            TotalDeduction = @TotalDeduction,
            CreatedBy = @CreatedBy,
            CreatedDate = GETDATE()
        WHERE EmployeeId = @EmployeeId AND SalaryMasterId = @MasterId;
    END
    ELSE
    BEGIN
        INSERT INTO StaffSalary (
            SalaryMasterId, EmployeeId, 
            BaseBasicPay, PresentDays, TotalDaysInMonth, 
            AllowancesDetail, DeductionsDetail,
            NetSalary, TotalAllowance, TotalDeduction, 
            CreatedBy
        )
        VALUES (
            @MasterId, @EmployeeId, 
            @BaseBasicPay, @PresentDays, @TotalDaysInMonth, 
            @AllowancesDetail, @DeductionsDetail,
            @NetSalary, @TotalAllowance, @TotalDeduction, 
            @CreatedBy
        );
    END
END
GO

CREATE OR ALTER PROCEDURE sp_FinalizeStaffSalary
    @OrganizationId INT,
    @SalaryYearId INT,
    @Month TINYINT,
    @EmployeeId INT, 
    @IsFinalized BIT,
    @UpdatedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Batch finalize the Master record (all employees in this run)
    UPDATE StaffSalaryMaster
    SET IsFinalized = @IsFinalized,
        CreatedBy = @UpdatedBy,
        CreatedDate = GETDATE()
    WHERE [Month] = @Month 
      AND SalaryYearId = @SalaryYearId 
      AND OrganizationId = @OrganizationId;
END
GO