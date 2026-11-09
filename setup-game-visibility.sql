-- Public game visibility in the existing account database; no changes to prices, rewards or balances.
SET XACT_ABORT ON;
IF OBJECT_ID('dbo.Tbl_Web_Games_Visibility','U') IS NULL
 CREATE TABLE dbo.Tbl_Web_Games_Visibility (
  GameType varchar(12) NOT NULL CONSTRAINT PK_Web_Games_Visibility PRIMARY KEY,
  IsVisible bit NOT NULL DEFAULT(1), UpdatedAt datetime NOT NULL DEFAULT(GETDATE()),
  UpdatedBy nvarchar(60) NULL, Version rowversion NOT NULL,
  CONSTRAINT CK_Web_Games_VisibilityType CHECK(GameType IN('wheel','card','chest','box','lotto'))
 );
INSERT dbo.Tbl_Web_Games_Visibility(GameType)
SELECT n.GameType FROM (SELECT 'wheel' GameType UNION ALL SELECT 'card' UNION ALL SELECT 'chest' UNION ALL SELECT 'box' UNION ALL SELECT 'lotto') n
WHERE NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_Games_Visibility v WHERE v.GameType=n.GameType);
IF OBJECT_ID('dbo.Tbl_Web_Games_VisibilityAudit','U') IS NULL
 CREATE TABLE dbo.Tbl_Web_Games_VisibilityAudit (
  AuditId bigint IDENTITY NOT NULL PRIMARY KEY, GameType varchar(12) NOT NULL,
  WasVisible bit NOT NULL, IsVisible bit NOT NULL, Actor nvarchar(128) NOT NULL,
  SqlLogin nvarchar(128) NOT NULL, ChangedAt datetime NOT NULL DEFAULT(GETDATE())
 );
GO
CREATE OR ALTER TRIGGER dbo.tr_Web_Games_VisibilityAudit ON dbo.Tbl_Web_Games_Visibility
AFTER UPDATE,DELETE
AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM deleted d WHERE NOT EXISTS(SELECT 1 FROM inserted i WHERE i.GameType=d.GameType))
  THROW 51310,'Use IsVisible to hide games; visibility rows cannot be deleted or renamed.',1;
 INSERT dbo.Tbl_Web_Games_VisibilityAudit(GameType,WasVisible,IsVisible,Actor,SqlLogin)
 SELECT i.GameType,d.IsVisible,i.IsVisible,CASE WHEN UPDATE(UpdatedBy) THEN COALESCE(i.UpdatedBy,ORIGINAL_LOGIN()) ELSE ORIGINAL_LOGIN() END,ORIGINAL_LOGIN()
 FROM inserted i INNER JOIN deleted d ON d.GameType=i.GameType WHERE i.IsVisible<>d.IsVisible;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Games_Visibility
AS
BEGIN
 SET NOCOUNT ON;
 SELECT v.GameType,v.IsVisible,v.Version,COALESCE(a.ChangedAt,v.UpdatedAt) UpdatedAt,COALESCE(a.Actor,v.UpdatedBy) UpdatedBy
 FROM dbo.Tbl_Web_Games_Visibility v OUTER APPLY(SELECT TOP(1) ChangedAt,Actor FROM dbo.Tbl_Web_Games_VisibilityAudit a WHERE a.GameType=v.GameType ORDER BY AuditId DESC) a
 ORDER BY CASE v.GameType WHEN 'wheel' THEN 1 WHEN 'chest' THEN 2 WHEN 'card' THEN 3 WHEN 'box' THEN 4 ELSE 5 END;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Games_Visible @gameType varchar(12)
AS
BEGIN
 SET NOCOUNT ON;
 SELECT CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.Tbl_Web_Games_Visibility WHERE GameType=@gameType AND IsVisible=1) THEN 1 ELSE 0 END AS bit);
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Games_Admin_Visibility
 @gameType varchar(12),@isVisible bit,@actor nvarchar(60),@expectedVersion binary(8)=NULL
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @gameType NOT IN('wheel','card','chest','box','lotto') OR NULLIF(@actor,N'') IS NULL THROW 51310,'Invalid game visibility change.',1;
 BEGIN TRAN;
 IF NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_Games_Visibility WITH(UPDLOCK,HOLDLOCK) WHERE GameType=@gameType AND (@expectedVersion IS NULL OR Version=@expectedVersion))
  BEGIN ROLLBACK;THROW 51311,'Game visibility changed. Reload before saving.',1;END;
 UPDATE dbo.Tbl_Web_Games_Visibility SET IsVisible=@isVisible,UpdatedAt=GETDATE(),UpdatedBy=@actor WHERE GameType=@gameType AND IsVisible<>@isVisible;
 COMMIT;
END;
