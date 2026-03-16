-- Apply UserLoginSessions table changes to remove audit columns
-- Run this script against the proxPayroll database

-- First, check current table structure
SELECT 'Current UserLoginSessions columns:' as Info
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'UserLoginSessions'
ORDER BY ORDINAL_POSITION
GO

-- Drop the audit columns if they exist
BEGIN TRY
    ALTER TABLE UserLoginSessions DROP COLUMN created_by
    PRINT 'Dropped column: created_by'
END TRY
BEGIN CATCH
    PRINT 'Column created_by does not exist or already dropped'
END CATCH
GO

BEGIN TRY
    ALTER TABLE UserLoginSessions DROP COLUMN last_updated_by
    PRINT 'Dropped column: last_updated_by'
END TRY
BEGIN CATCH
    PRINT 'Column last_updated_by does not exist or already dropped'
END CATCH
GO

-- Verify final table structure
SELECT 'Final UserLoginSessions columns:' as Info
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'UserLoginSessions'
ORDER BY ORDINAL_POSITION
GO

-- Recreate stored procedures without audit column references
PRINT 'Recreating stored procedures...'
GO

-- 1. Update/Create sp_UpsertUserLoginSession
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

-- 2. Update/Create sp_GetUserLoginSessions
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

-- 3. Update/Create sp_LogoutUserSession
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

-- 4. Update/Create sp_CheckAndUpdateExpiredSessions
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

PRINT 'All stored procedures updated successfully!'
GO

-- Verify stored procedures exist
SELECT 'Stored Procedures:' as Info
SELECT ROUTINE_NAME 
FROM INFORMATION_SCHEMA.ROUTINES 
WHERE ROUTINE_TYPE = 'PROCEDURE' 
AND ROUTINE_NAME LIKE 'sp_%Session'
ORDER BY ROUTINE_NAME
GO
