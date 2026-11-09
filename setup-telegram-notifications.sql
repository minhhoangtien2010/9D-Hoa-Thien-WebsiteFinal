-- Install in the existing NineDragons_Account database. Financial procedures are unchanged.
-- InstalledAt is a one-time watermark: previous completed deposits are never backfilled.
SET XACT_ABORT ON;
IF OBJECT_ID('dbo.Tbl_Web_Telegram_Settings','U') IS NULL
BEGIN
 CREATE TABLE dbo.Tbl_Web_Telegram_Settings (
  SettingsId int NOT NULL CONSTRAINT PK_Web_Telegram_Settings PRIMARY KEY CHECK(SettingsId=1),
  ChatId nvarchar(64) NULL, IsEnabled bit NOT NULL DEFAULT(0),
  InstalledAt datetime NOT NULL DEFAULT(GETDATE()),
  UpdatedAt datetime NOT NULL DEFAULT(GETDATE()), UpdatedBy nvarchar(60) NULL
 );
 INSERT dbo.Tbl_Web_Telegram_Settings(SettingsId) VALUES(1);
END;
IF OBJECT_ID('dbo.Tbl_Web_Telegram_Outbox','U') IS NULL
BEGIN
 CREATE TABLE dbo.Tbl_Web_Telegram_Outbox (
  NotificationId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Web_Telegram_Outbox PRIMARY KEY,
  TransactionId int NOT NULL CONSTRAINT UQ_Web_Telegram_Transaction UNIQUE,
  Username nvarchar(60) NOT NULL, OrderCode nvarchar(50) NULL,
  Amount decimal(18,0) NOT NULL, Coins int NOT NULL, Bonus int NOT NULL,
  CompletedAt datetime NOT NULL, CreatedAt datetime NOT NULL DEFAULT(GETDATE()),
  Status varchar(16) NOT NULL DEFAULT('Pending'), Attempts int NOT NULL DEFAULT(0),
  NextAttemptAt datetime NOT NULL DEFAULT(GETDATE()), LeaseId uniqueidentifier NULL,
  LeaseUntil datetime NULL, ChatId nvarchar(64) NULL, MessageId bigint NULL,
  SentAt datetime NULL, LastError nvarchar(250) NULL
 );
 CREATE INDEX IX_Web_Telegram_Pending ON dbo.Tbl_Web_Telegram_Outbox(Status,NextAttemptAt);
END;
IF OBJECT_ID('dbo.Tbl_Web_Telegram_Audit','U') IS NULL
 CREATE TABLE dbo.Tbl_Web_Telegram_Audit (
  AuditId bigint IDENTITY PRIMARY KEY, Actor nvarchar(60) NOT NULL,
  Action nvarchar(40) NOT NULL, Detail nvarchar(250) NULL,
  CreatedAt datetime NOT NULL DEFAULT(GETDATE())
 );
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Telegram_Admin_Status
 @page int=1
AS
BEGIN
 SET NOCOUNT ON;
 SELECT ChatId,IsEnabled,InstalledAt,UpdatedAt,UpdatedBy FROM dbo.Tbl_Web_Telegram_Settings WHERE SettingsId=1;
 SELECT Status,COUNT(*) AS Total FROM dbo.Tbl_Web_Telegram_Outbox GROUP BY Status;
 SELECT * FROM dbo.Tbl_Web_Telegram_Outbox ORDER BY NotificationId DESC OFFSET ((CASE WHEN @page<1 THEN 1 ELSE @page END)-1)*30 ROWS FETCH NEXT 30 ROWS ONLY;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Telegram_Admin_Save
 @chatId nvarchar(64), @isEnabled bit, @actor nvarchar(60)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @isEnabled=1 AND (NULLIF(@chatId,'') IS NULL OR LEN(@chatId)>20 OR REPLACE(@chatId,'-','') LIKE '%[^0-9]%' OR @chatId IN('0','-'))
  THROW 51200,'Invalid Telegram chat ID',1;
 BEGIN TRAN;
 UPDATE dbo.Tbl_Web_Telegram_Settings SET ChatId=NULLIF(@chatId,''),IsEnabled=@isEnabled,UpdatedAt=GETDATE(),UpdatedBy=@actor WHERE SettingsId=1;
 INSERT dbo.Tbl_Web_Telegram_Audit(Actor,Action,Detail) VALUES(@actor,'Save settings',CONCAT('Enabled=',@isEnabled,'; ChatId=',@chatId));
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Telegram_Collect
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 -- Only read the original ledger. No balance or payment mutations happen here.
 INSERT dbo.Tbl_Web_Telegram_Outbox(TransactionId,Username,OrderCode,Amount,Coins,Bonus,CompletedAt)
 SELECT t.id,t.username,t.order_code,t.amount,t.coins,t.bonus,t.completed_date
 FROM dbo.Tbl_ND_Web_Transactions t
 CROSS JOIN dbo.Tbl_Web_Telegram_Settings s
 WHERE s.SettingsId=1 AND t.payment_method='BankTransfer' AND t.status='Completed'
  AND t.completed_date>=s.InstalledAt AND t.amount>0 AND t.coins>0
  AND NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_Telegram_Outbox o WITH(UPDLOCK,HOLDLOCK) WHERE o.TransactionId=t.id);
 -- A process may have died after Telegram accepted a message. Require manual review.
 UPDATE dbo.Tbl_Web_Telegram_Outbox SET Status='Review',LeaseId=NULL,LeaseUntil=NULL,
  LastError=N'Tiến trình gửi bị gián đoạn. Kiểm tra Telegram trước khi gửi lại.'
 WHERE Status='Sending' AND LeaseUntil<GETDATE();
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Telegram_Claim
 @leaseId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 ;WITH nextJob AS (
  SELECT TOP(1) o.* FROM dbo.Tbl_Web_Telegram_Outbox o WITH(UPDLOCK,READPAST,ROWLOCK)
  WHERE o.Status IN('Pending','Retry') AND o.NextAttemptAt<=GETDATE() AND o.Attempts<8
   AND EXISTS(SELECT 1 FROM dbo.Tbl_Web_Telegram_Settings WHERE SettingsId=1 AND IsEnabled=1 AND NULLIF(ChatId,'') IS NOT NULL)
  ORDER BY o.NotificationId
 )
 UPDATE nextJob SET Status='Sending',Attempts=Attempts+1,LeaseId=@leaseId,
  LeaseUntil=DATEADD(minute,5,GETDATE()),ChatId=(SELECT ChatId FROM dbo.Tbl_Web_Telegram_Settings WHERE SettingsId=1)
 OUTPUT inserted.*;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Telegram_Finish
 @id bigint,@leaseId uniqueidentifier,@status varchar(16),@messageId bigint=NULL,@error nvarchar(250)=NULL,@retryAfter int=30
AS
BEGIN
 SET NOCOUNT ON;
 IF @status NOT IN('Sent','Retry','Review','Failed') THROW 51201,'Invalid notification status',1;
 UPDATE dbo.Tbl_Web_Telegram_Outbox
 SET Status=CASE WHEN @status='Retry' AND Attempts>=8 THEN 'Failed' ELSE @status END,
  MessageId=@messageId,SentAt=CASE WHEN @status='Sent' THEN GETDATE() ELSE NULL END,
  LastError=@error,NextAttemptAt=DATEADD(second,CASE WHEN @retryAfter<5 THEN 5 WHEN @retryAfter>86400 THEN 86400 ELSE @retryAfter END,GETDATE()),
  LeaseId=NULL,LeaseUntil=NULL
 WHERE NotificationId=@id AND LeaseId=@leaseId AND Status='Sending';
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Telegram_Admin_Retry
 @id bigint,@actor nvarchar(60)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRAN;
 UPDATE dbo.Tbl_Web_Telegram_Outbox SET Status='Pending',Attempts=0,NextAttemptAt=GETDATE(),LastError=NULL
 WHERE NotificationId=@id AND Status IN('Review','Failed','Retry');
 IF @@ROWCOUNT>0 INSERT dbo.Tbl_Web_Telegram_Audit(Actor,Action,Detail) VALUES(@actor,'Retry notification',CONCAT('NotificationId=',@id));
 COMMIT;
END;
