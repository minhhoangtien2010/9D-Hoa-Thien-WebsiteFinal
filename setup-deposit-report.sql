-- Reporting only. Existing wallet, conversion, payment and CIS procedures stay unchanged.
SET XACT_ABORT ON;
IF COL_LENGTH('dbo.Tbl_Web_Telegram_Settings','ManualInstalledAt') IS NULL
 ALTER TABLE dbo.Tbl_Web_Telegram_Settings ADD ManualInstalledAt datetime NOT NULL CONSTRAINT DF_Web_Telegram_ManualInstalled DEFAULT(GETDATE());
IF COL_LENGTH('dbo.Tbl_Web_Telegram_Outbox','PaymentMethod') IS NULL
 ALTER TABLE dbo.Tbl_Web_Telegram_Outbox ADD PaymentMethod nvarchar(30) NOT NULL CONSTRAINT DF_Web_Telegram_Method DEFAULT('BankTransfer');
IF OBJECT_ID('dbo.Tbl_Web_DepositReport_Settings','U') IS NULL
BEGIN
 CREATE TABLE dbo.Tbl_Web_DepositReport_Settings(SettingsId int NOT NULL PRIMARY KEY CHECK(SettingsId=1),
  SheetUrl nvarchar(350) NOT NULL,EndpointUrl nvarchar(350) NULL,IsEnabled bit NOT NULL DEFAULT(0),
  CollectFrom datetime NOT NULL DEFAULT(GETDATE()),UpdatedAt datetime NOT NULL DEFAULT(GETDATE()),UpdatedBy nvarchar(60) NULL,Version rowversion);
 INSERT dbo.Tbl_Web_DepositReport_Settings(SettingsId,SheetUrl) VALUES(1,N'https://docs.google.com/spreadsheets/d/16MDII88EkoR1aA7heSRXobU9CKf2lOLdd_bEQWLstE8/edit');
END;
IF OBJECT_ID('dbo.Tbl_Web_DepositReport_Outbox','U') IS NULL
BEGIN
 CREATE TABLE dbo.Tbl_Web_DepositReport_Outbox(TransactionId int NOT NULL PRIMARY KEY,
  Username nvarchar(60) NOT NULL,OrderCode nvarchar(50) NULL,PaymentMethod nvarchar(30) NOT NULL,
  AmountVnd decimal(18,2) NULL,Coins int NOT NULL,Bonus int NOT NULL,PaymentStatus nvarchar(30) NOT NULL,OccurredAt datetime NOT NULL,
  Status varchar(16) NOT NULL DEFAULT('Pending'),Attempts int NOT NULL DEFAULT(0),NextAttemptAt datetime NOT NULL DEFAULT(GETDATE()),
  LeaseId uniqueidentifier NULL,LeaseUntil datetime NULL,SentAt datetime NULL,LastError nvarchar(250) NULL,
  DataRevision int NOT NULL DEFAULT(1));
 CREATE INDEX IX_Web_DepositReport_Pending ON dbo.Tbl_Web_DepositReport_Outbox(Status,NextAttemptAt);
END;
IF COL_LENGTH('dbo.Tbl_Web_DepositReport_Outbox','DataRevision') IS NULL
 ALTER TABLE dbo.Tbl_Web_DepositReport_Outbox ADD DataRevision int NOT NULL CONSTRAINT DF_Web_DepositReport_DataRevision DEFAULT(1);
IF OBJECT_ID('dbo.Tbl_Web_DepositReport_Audit','U') IS NULL
 CREATE TABLE dbo.Tbl_Web_DepositReport_Audit(AuditId bigint IDENTITY PRIMARY KEY,Actor nvarchar(60) NOT NULL,Action nvarchar(50) NOT NULL,CreatedAt datetime NOT NULL DEFAULT(GETDATE()));
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Telegram_Collect AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 INSERT dbo.Tbl_Web_Telegram_Outbox(TransactionId,Username,OrderCode,Amount,Coins,Bonus,CompletedAt,PaymentMethod)
 SELECT t.id,t.username,t.order_code,CASE WHEN t.payment_method='AdminGrant' THEN 0 ELSE t.amount END,t.coins,t.bonus,COALESCE(t.completed_date,t.created_at),t.payment_method
 FROM dbo.Tbl_ND_Web_Transactions t CROSS JOIN dbo.Tbl_Web_Telegram_Settings s
 WHERE s.SettingsId=1 AND t.status='Completed' AND t.coins>0
 AND ((t.payment_method='BankTransfer' AND t.completed_date>=s.InstalledAt AND t.amount>0)
   OR(t.payment_method='AdminGrant' AND t.created_at>=s.ManualInstalledAt))
 AND NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_Telegram_Outbox o WITH(UPDLOCK,HOLDLOCK) WHERE o.TransactionId=t.id);
 UPDATE dbo.Tbl_Web_Telegram_Outbox SET Status='Review',LeaseId=NULL,LeaseUntil=NULL,LastError=N'Tiến trình gửi bị gián đoạn. Kiểm tra Telegram trước khi gửi lại.' WHERE Status='Sending' AND LeaseUntil<GETDATE();
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Telegram_Admin_Status @page int=1 AS
BEGIN
 SET NOCOUNT ON;
 SELECT ChatId,IsEnabled,InstalledAt,ManualInstalledAt,UpdatedAt,UpdatedBy FROM dbo.Tbl_Web_Telegram_Settings WHERE SettingsId=1;
 SELECT Status,COUNT(*) AS Total FROM dbo.Tbl_Web_Telegram_Outbox GROUP BY Status;
 SELECT * FROM dbo.Tbl_Web_Telegram_Outbox ORDER BY NotificationId DESC OFFSET ((CASE WHEN @page<1 THEN 1 ELSE @page END)-1)*30 ROWS FETCH NEXT 30 ROWS ONLY;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_DepositReport_Collect AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRAN;
 -- Acknowledgements are idempotent at the Sheet; a lost response may be retried safely.
 UPDATE dbo.Tbl_Web_DepositReport_Outbox SET Status='Retry',LeaseId=NULL,LeaseUntil=NULL,NextAttemptAt=GETDATE(),LastError=N'Kết nối bị gián đoạn; chờ đồng bộ lại theo mã giao dịch.' WHERE Status='Sending' AND LeaseUntil<GETDATE();
 UPDATE o SET Username=t.username,OrderCode=t.order_code,PaymentMethod=t.payment_method,AmountVnd=CASE WHEN t.payment_method='BankTransfer' THEN t.amount END,
  Coins=t.coins,Bonus=t.bonus,PaymentStatus=t.status,OccurredAt=COALESCE(t.completed_date,t.created_at),Status='Pending',Attempts=0,NextAttemptAt=GETDATE(),LastError=NULL,DataRevision=DataRevision+1
 FROM dbo.Tbl_Web_DepositReport_Outbox o JOIN dbo.Tbl_ND_Web_Transactions t ON t.id=o.TransactionId
 WHERE o.Status<>'Sending' AND t.payment_method IN('BankTransfer','AdminGrant')
 AND(t.status<>o.PaymentStatus OR t.coins<>o.Coins OR t.bonus<>o.Bonus OR ISNULL(t.order_code,'')<>ISNULL(o.OrderCode,'') OR t.username<>o.Username
 OR t.payment_method<>o.PaymentMethod OR COALESCE(t.completed_date,t.created_at)<>o.OccurredAt
 OR ISNULL(o.AmountVnd,-1)<>ISNULL(CASE WHEN t.payment_method='BankTransfer' THEN t.amount END,-1));
 INSERT dbo.Tbl_Web_DepositReport_Outbox(TransactionId,Username,OrderCode,PaymentMethod,AmountVnd,Coins,Bonus,PaymentStatus,OccurredAt)
 SELECT t.id,t.username,t.order_code,t.payment_method,CASE WHEN t.payment_method='BankTransfer' THEN t.amount END,t.coins,t.bonus,t.status,COALESCE(t.completed_date,t.created_at)
 FROM dbo.Tbl_ND_Web_Transactions t CROSS JOIN dbo.Tbl_Web_DepositReport_Settings s
 WHERE s.SettingsId=1 AND t.payment_method IN('BankTransfer','AdminGrant') AND COALESCE(t.completed_date,t.created_at)>=s.CollectFrom
 AND NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_DepositReport_Outbox o WITH(UPDLOCK,HOLDLOCK) WHERE o.TransactionId=t.id);
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_DepositReport_Admin_Status @page int=1 AS
BEGIN
 SET NOCOUNT ON;
 SELECT * FROM dbo.Tbl_Web_DepositReport_Settings WHERE SettingsId=1;
 SELECT Status,COUNT(*) Total FROM dbo.Tbl_Web_DepositReport_Outbox GROUP BY Status;
 SELECT * FROM dbo.Tbl_Web_DepositReport_Outbox ORDER BY TransactionId DESC OFFSET ((CASE WHEN @page<1 THEN 1 ELSE @page END)-1)*30 ROWS FETCH NEXT 30 ROWS ONLY;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_DepositReport_Admin_Save
 @sheetUrl nvarchar(350),@endpointUrl nvarchar(350)=NULL,@isEnabled bit,@collectFrom datetime,@actor nvarchar(60),@expectedVersion binary(8) AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRAN;
 BEGIN TRY
 IF NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_DepositReport_Settings WITH(UPDLOCK,HOLDLOCK) WHERE SettingsId=1 AND Version=@expectedVersion)
  THROW 51320,'Report settings changed; reload first.',1;
 IF @sheetUrl NOT LIKE 'https://docs.google.com/spreadsheets/d/%' OR @collectFrom IS NULL OR @collectFrom>DATEADD(DAY,1,GETDATE())
  THROW 51321,'Invalid report settings.',1;
 IF @isEnabled=1 AND NULLIF(@endpointUrl,'') IS NULL THROW 51321,'Configure the Apps Script endpoint first.',1;
 DECLARE @destinationChanged bit=0;
 IF EXISTS(SELECT 1 FROM dbo.Tbl_Web_DepositReport_Settings WHERE SettingsId=1 AND SheetUrl<>@sheetUrl) SET @destinationChanged=1;
 UPDATE dbo.Tbl_Web_DepositReport_Settings SET SheetUrl=@sheetUrl,EndpointUrl=NULLIF(@endpointUrl,''),IsEnabled=@isEnabled,CollectFrom=@collectFrom,UpdatedAt=GETDATE(),UpdatedBy=@actor WHERE SettingsId=1;
 IF @destinationChanged=1 UPDATE dbo.Tbl_Web_DepositReport_Outbox SET Status='Pending',Attempts=0,NextAttemptAt=GETDATE(),LeaseId=NULL,LeaseUntil=NULL,SentAt=NULL,LastError=NULL;
 INSERT dbo.Tbl_Web_DepositReport_Audit(Actor,Action) VALUES(@actor,'Save report settings');
 COMMIT;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK;THROW;END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_DepositReport_Claim @leaseId uniqueidentifier AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @id int;
 BEGIN TRAN;
 SELECT TOP(1) @id=o.TransactionId FROM dbo.Tbl_Web_DepositReport_Outbox o WITH(UPDLOCK,READPAST,ROWLOCK)
 CROSS JOIN dbo.Tbl_Web_DepositReport_Settings s WHERE s.SettingsId=1 AND s.IsEnabled=1 AND o.Status IN('Pending','Retry') AND o.NextAttemptAt<=GETDATE() ORDER BY o.TransactionId;
 UPDATE dbo.Tbl_Web_DepositReport_Outbox SET Status='Sending',Attempts=Attempts+1,LeaseId=@leaseId,LeaseUntil=DATEADD(SECOND,90,GETDATE()) WHERE TransactionId=@id;
 SELECT o.*,s.SheetUrl,s.EndpointUrl FROM dbo.Tbl_Web_DepositReport_Outbox o CROSS JOIN dbo.Tbl_Web_DepositReport_Settings s WHERE o.TransactionId=@id AND s.SettingsId=1;
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_DepositReport_Finish @id int,@leaseId uniqueidentifier,@success bit,@error nvarchar(250)=NULL AS
BEGIN
 SET NOCOUNT ON;
 UPDATE dbo.Tbl_Web_DepositReport_Outbox SET Status=CASE WHEN @success=1 THEN 'Sent' WHEN Attempts<5 THEN 'Retry' ELSE 'Failed' END,
  SentAt=CASE WHEN @success=1 THEN GETDATE() ELSE SentAt END,NextAttemptAt=DATEADD(MINUTE,2,GETDATE()),LastError=@error,LeaseId=NULL,LeaseUntil=NULL
 WHERE TransactionId=@id AND LeaseId=@leaseId AND Status='Sending';
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_DepositReport_Admin_Retry @id int,@actor nvarchar(60) AS
BEGIN
 SET NOCOUNT ON;
 UPDATE dbo.Tbl_Web_DepositReport_Outbox SET Status='Pending',Attempts=0,NextAttemptAt=GETDATE(),LastError=NULL WHERE TransactionId=@id AND Status IN('Failed','Retry','Sent');
 INSERT dbo.Tbl_Web_DepositReport_Audit(Actor,Action) VALUES(@actor,CONCAT('Retry report #',@id));
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_DepositReport_Export AS
BEGIN
 SET NOCOUNT ON;
 SELECT TOP(50000) * FROM dbo.Tbl_Web_DepositReport_Outbox ORDER BY TransactionId;
END;
GO
