-- Public bank receiver configuration in the existing account database.
-- This migration never changes balances, deposit completion procedures, provider keys or old transactions.
SET XACT_ABORT ON;
IF OBJECT_ID('dbo.Tbl_Web_Deposit_Receivers','U') IS NULL
 CREATE TABLE dbo.Tbl_Web_Deposit_Receivers (
  ReceiverId int NOT NULL CONSTRAINT PK_Web_Deposit_Receivers PRIMARY KEY CHECK(ReceiverId=1),
  BankName nvarchar(50) NOT NULL, AccountNumber varchar(64) NOT NULL, AccountName nvarchar(150) NOT NULL,
  OrderPrefix varchar(12) NOT NULL, QrTemplate varchar(30) NOT NULL,
  IsEnabled bit NOT NULL DEFAULT(1), EnableGateway bit NOT NULL DEFAULT(0),
  UpdatedAt datetime NOT NULL DEFAULT(GETDATE()), UpdatedBy nvarchar(60) NULL,
  Version rowversion NOT NULL,
  CONSTRAINT CK_Web_Deposit_ReceiverFields CHECK (
   LEN(LTRIM(RTRIM(BankName)))>0 AND BankName COLLATE Latin1_General_BIN NOT LIKE '%[^a-zA-Z0-9]%' AND
   LEN(AccountNumber)>0 AND AccountNumber COLLATE Latin1_General_BIN NOT LIKE '%[^a-zA-Z0-9]%' AND
   LEN(LTRIM(RTRIM(AccountName)))>0 AND LEN(OrderPrefix)>0 AND
   OrderPrefix COLLATE Latin1_General_BIN NOT LIKE '%[^a-zA-Z]%' AND
   QrTemplate IN('compact','compact2','qr_only','print'))
 );
IF OBJECT_ID('dbo.Tbl_Web_Deposit_ReceiverHistory','U') IS NULL
 CREATE TABLE dbo.Tbl_Web_Deposit_ReceiverHistory (
  RevisionId bigint IDENTITY NOT NULL CONSTRAINT PK_Web_Deposit_ReceiverHistory PRIMARY KEY,
  ReceiverId int NOT NULL, BankName nvarchar(50) NOT NULL, AccountNumber varchar(64) NOT NULL, AccountName nvarchar(150) NOT NULL,
  OrderPrefix varchar(12) NOT NULL, QrTemplate varchar(30) NOT NULL, IsEnabled bit NOT NULL, EnableGateway bit NOT NULL,
  Version binary(8) NOT NULL CONSTRAINT UQ_Web_Deposit_ReceiverVersion UNIQUE,
  UpdatedAt datetime NOT NULL, UpdatedBy nvarchar(60) NULL,
  ChangeSource varchar(12) NOT NULL, SqlLogin nvarchar(128) NOT NULL, IsInitial bit NOT NULL
 );
IF OBJECT_ID('dbo.Tbl_Web_Deposit_OrderReceivers','U') IS NULL
 CREATE TABLE dbo.Tbl_Web_Deposit_OrderReceivers (
  TransactionId int NOT NULL CONSTRAINT PK_Web_Deposit_OrderReceivers PRIMARY KEY,
  ReceiverId int NOT NULL, RevisionId bigint NOT NULL, Version binary(8) NOT NULL,
  BankName nvarchar(50) NOT NULL, AccountNumber varchar(64) NOT NULL, AccountName nvarchar(150) NOT NULL,
  OrderPrefix varchar(12) NOT NULL, QrTemplate varchar(30) NOT NULL,
  IsEnabled bit NOT NULL, EnableGateway bit NOT NULL,
  OrderCode nvarchar(50) NOT NULL, IsGateway bit NOT NULL,
  CreatedAt datetime NOT NULL DEFAULT(GETDATE()), UpdatedAt datetime NOT NULL, UpdatedBy nvarchar(60) NULL,
  CONSTRAINT FK_Web_Deposit_OrderReceiverRevision FOREIGN KEY(RevisionId) REFERENCES dbo.Tbl_Web_Deposit_ReceiverHistory(RevisionId),
  CONSTRAINT UQ_Web_Deposit_OrderReceiverCode UNIQUE(OrderCode)
 );
IF OBJECT_ID('dbo.Tbl_Web_Deposit_ConfigNotifications','U') IS NULL
BEGIN
 CREATE TABLE dbo.Tbl_Web_Deposit_ConfigNotifications (
  NotificationId bigint IDENTITY NOT NULL CONSTRAINT PK_Web_Deposit_ConfigNotifications PRIMARY KEY,
  RevisionId bigint NOT NULL CONSTRAINT UQ_Web_Deposit_ConfigNotificationRevision UNIQUE,
  Status varchar(16) NOT NULL DEFAULT('Pending'), Attempts int NOT NULL DEFAULT(0),
  CreatedAt datetime NOT NULL DEFAULT(GETDATE()), NextAttemptAt datetime NOT NULL DEFAULT(GETDATE()),
  LeaseId uniqueidentifier NULL, LeaseUntil datetime NULL, ChatId nvarchar(64) NULL,
  MessageId bigint NULL, SentAt datetime NULL, LastError nvarchar(250) NULL,
  CONSTRAINT FK_Web_Deposit_NotificationRevision FOREIGN KEY(RevisionId) REFERENCES dbo.Tbl_Web_Deposit_ReceiverHistory(RevisionId)
 );
 CREATE INDEX IX_Web_Deposit_ConfigNotificationsPending ON dbo.Tbl_Web_Deposit_ConfigNotifications(Status,NextAttemptAt);
END;
-- Public visibility is independent of provider callbacks and receiver identity.
-- First installation keeps topup hidden as requested; later reruns preserve the administrator's choice.
IF COL_LENGTH('dbo.Tbl_Web_Deposit_Receivers','IsVisible') IS NULL
 ALTER TABLE dbo.Tbl_Web_Deposit_Receivers ADD IsVisible bit NOT NULL CONSTRAINT DF_Web_Deposit_ReceiverVisible DEFAULT(0) WITH VALUES;
IF COL_LENGTH('dbo.Tbl_Web_Deposit_ReceiverHistory','IsVisible') IS NULL
 ALTER TABLE dbo.Tbl_Web_Deposit_ReceiverHistory ADD IsVisible bit NOT NULL CONSTRAINT DF_Web_Deposit_ReceiverHistoryVisible DEFAULT(1) WITH VALUES;
IF COL_LENGTH('dbo.Tbl_Web_Deposit_OrderReceivers','IsVisible') IS NULL
 ALTER TABLE dbo.Tbl_Web_Deposit_OrderReceivers ADD IsVisible bit NOT NULL CONSTRAINT DF_Web_Deposit_OrderReceiverVisible DEFAULT(1) WITH VALUES;
GO
CREATE OR ALTER TRIGGER dbo.tr_Web_Deposit_ReceiverAudit ON dbo.Tbl_Web_Deposit_Receivers
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM deleted) AND NOT EXISTS(SELECT 1 FROM inserted)
  THROW 51300,'Receiver cannot be deleted; disable new orders instead.',1;
 -- Capture the entire new version even for direct SQL edits. Order snapshots never depend on the mutable current row.
 INSERT dbo.Tbl_Web_Deposit_ReceiverHistory
  (ReceiverId,BankName,AccountNumber,AccountName,OrderPrefix,QrTemplate,IsEnabled,EnableGateway,IsVisible,Version,UpdatedAt,UpdatedBy,ChangeSource,SqlLogin,IsInitial)
 SELECT i.ReceiverId,i.BankName,i.AccountNumber,i.AccountName,i.OrderPrefix,i.QrTemplate,i.IsEnabled,i.EnableGateway,i.IsVisible,i.Version,
  GETDATE(),CASE WHEN UPDATE(UpdatedBy) THEN COALESCE(i.UpdatedBy,ORIGINAL_LOGIN()) ELSE ORIGINAL_LOGIN() END,
  CASE WHEN NOT EXISTS(SELECT 1 FROM deleted) THEN 'Install' WHEN UPDATE(UpdatedBy) THEN 'Website' ELSE 'SQL' END,
  ORIGINAL_LOGIN(),CASE WHEN EXISTS(SELECT 1 FROM deleted) THEN 0 ELSE 1 END
 FROM inserted i;
 INSERT dbo.Tbl_Web_Deposit_ConfigNotifications(RevisionId)
 SELECT h.RevisionId FROM inserted i INNER JOIN deleted d ON i.ReceiverId=d.ReceiverId
 INNER JOIN dbo.Tbl_Web_Deposit_ReceiverHistory h ON h.Version=i.Version
 WHERE i.BankName COLLATE Latin1_General_BIN<>d.BankName COLLATE Latin1_General_BIN
  OR i.AccountNumber COLLATE Latin1_General_BIN<>d.AccountNumber COLLATE Latin1_General_BIN
  OR i.AccountName COLLATE Latin1_General_BIN<>d.AccountName COLLATE Latin1_General_BIN
  OR i.OrderPrefix COLLATE Latin1_General_BIN<>d.OrderPrefix COLLATE Latin1_General_BIN
  OR i.QrTemplate<>d.QrTemplate OR i.IsEnabled<>d.IsEnabled OR i.EnableGateway<>d.EnableGateway OR i.IsVisible<>d.IsVisible;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Deposit_Admin_SeedReceiver
 @bankName nvarchar(50),@accountNumber varchar(64),@accountName nvarchar(150),
 @orderPrefix varchar(12),@qrTemplate varchar(30),@enableGateway bit,@isVisible bit=0
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 BEGIN TRAN;
 IF NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_Deposit_Receivers WITH(UPDLOCK,HOLDLOCK) WHERE ReceiverId=1)
  INSERT dbo.Tbl_Web_Deposit_Receivers(ReceiverId,BankName,AccountNumber,AccountName,OrderPrefix,QrTemplate,EnableGateway,IsVisible,UpdatedBy)
  VALUES(1,@bankName,@accountNumber,@accountName,@orderPrefix,@qrTemplate,@enableGateway,@isVisible,N'Installation');
 COMMIT;
 SELECT COUNT(*) SeededReceiverCount FROM dbo.Tbl_Web_Deposit_Receivers WHERE ReceiverId=1;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Deposit_Receiver
AS
BEGIN
 SET NOCOUNT ON;
 SELECT r.ReceiverId,r.BankName,r.AccountNumber,r.AccountName,r.OrderPrefix,r.QrTemplate,r.IsEnabled,r.EnableGateway,r.IsVisible,r.Version,
  h.UpdatedAt,h.UpdatedBy
 FROM dbo.Tbl_Web_Deposit_Receivers r INNER JOIN dbo.Tbl_Web_Deposit_ReceiverHistory h ON h.Version=r.Version WHERE r.ReceiverId=1;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Deposit_Admin_ReceiverHistory @page int=1
AS
BEGIN
 SET NOCOUNT ON;
 SELECT * FROM dbo.Tbl_Web_Deposit_ReceiverHistory ORDER BY RevisionId DESC
 OFFSET ((CASE WHEN @page<1 THEN 1 ELSE @page END)-1)*30 ROWS FETCH NEXT 30 ROWS ONLY;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Deposit_LegacyReceiver
AS
BEGIN
 SET NOCOUNT ON;
 SELECT TOP(1) * FROM dbo.Tbl_Web_Deposit_ReceiverHistory WHERE IsInitial=1 ORDER BY RevisionId;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Deposit_LegacyOrder @transactionId int
AS
BEGIN
 SET NOCOUNT ON;
 SELECT h.ReceiverId,h.RevisionId,h.Version,h.BankName,h.AccountNumber,h.AccountName,h.OrderPrefix,h.QrTemplate,
  h.IsEnabled,h.EnableGateway,h.IsVisible,h.UpdatedAt,h.UpdatedBy,t.id TransactionId,
  h.OrderPrefix+CONVERT(varchar(12),t.id) OrderCode,CAST(0 AS bit) IsGateway,CAST(1 AS bit) IsLegacy,
  t.created_at CreatedAt,t.username Username,t.amount Amount,t.status Status,t.completed_date CompletedAt
 FROM dbo.Tbl_ND_Web_Transactions t CROSS JOIN
  (SELECT TOP(1) * FROM dbo.Tbl_Web_Deposit_ReceiverHistory WHERE IsInitial=1 ORDER BY RevisionId) h
 WHERE t.id=@transactionId AND t.created_at<h.UpdatedAt AND t.payment_method='BankTransfer'
  AND NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_Deposit_OrderReceivers o WHERE o.TransactionId=t.id);
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Deposit_Admin_SaveReceiver
 @bankName nvarchar(50),@accountNumber varchar(64),@accountName nvarchar(150),@orderPrefix varchar(12),@qrTemplate varchar(30),
 @isEnabled bit,@enableGateway bit,@expectedVersion binary(8),@actor nvarchar(60),@isVisible bit=0
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 SET @bankName=LTRIM(RTRIM(@bankName));SET @accountNumber=LTRIM(RTRIM(@accountNumber));
 SET @accountName=LTRIM(RTRIM(@accountName));SET @orderPrefix=UPPER(LTRIM(RTRIM(@orderPrefix)));
 IF NULLIF(@actor,N'') IS NULL THROW 51302,'An administrator is required.',1;
 IF LEN(@bankName)=0 OR @bankName COLLATE Latin1_General_BIN LIKE '%[^a-zA-Z0-9]%'
  OR LEN(@accountNumber)=0 OR @accountNumber COLLATE Latin1_General_BIN LIKE '%[^a-zA-Z0-9]%'
  OR LEN(@accountName)=0 OR LEN(@orderPrefix)=0 OR @orderPrefix COLLATE Latin1_General_BIN LIKE '%[^a-zA-Z]%'
  OR @qrTemplate NOT IN('compact','compact2','qr_only','print') THROW 51302,'Invalid receiver details.',1;
 BEGIN TRAN;
 IF NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_Deposit_Receivers WITH(UPDLOCK,HOLDLOCK) WHERE ReceiverId=1 AND Version=@expectedVersion)
 BEGIN ROLLBACK;THROW 51301,'Receiver settings changed. Reload before saving.',1;END;
 UPDATE dbo.Tbl_Web_Deposit_Receivers SET BankName=@bankName,AccountNumber=@accountNumber,AccountName=@accountName,
  OrderPrefix=@orderPrefix,QrTemplate=@qrTemplate,IsEnabled=@isEnabled,EnableGateway=@enableGateway,IsVisible=@isVisible,UpdatedAt=GETDATE(),UpdatedBy=@actor
 WHERE ReceiverId=1 AND (BankName COLLATE Latin1_General_BIN<>@bankName COLLATE Latin1_General_BIN
  OR AccountNumber COLLATE Latin1_General_BIN<>@accountNumber COLLATE Latin1_General_BIN
  OR AccountName COLLATE Latin1_General_BIN<>@accountName COLLATE Latin1_General_BIN
  OR OrderPrefix COLLATE Latin1_General_BIN<>@orderPrefix COLLATE Latin1_General_BIN
  OR QrTemplate<>@qrTemplate OR IsEnabled<>@isEnabled OR EnableGateway<>@enableGateway OR IsVisible<>@isVisible);
 COMMIT;
 EXEC dbo.sp_Web_Deposit_Receiver;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Deposit_CaptureOrder
 @transactionId int,@receiverVersion binary(8),@orderCode nvarchar(50),@isGateway bit=0
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 BEGIN TRAN;
 IF EXISTS(SELECT 1 FROM dbo.Tbl_Web_Deposit_OrderReceivers WITH(UPDLOCK,HOLDLOCK) WHERE TransactionId=@transactionId)
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_Deposit_OrderReceivers WHERE TransactionId=@transactionId AND Version=@receiverVersion AND OrderCode=@orderCode AND IsGateway=@isGateway)
   BEGIN ROLLBACK;THROW 51303,'Order receiver has already been captured.',1;END;
  COMMIT;RETURN;
 END;
 IF NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_Deposit_Receivers WITH(HOLDLOCK) WHERE ReceiverId=1 AND IsVisible=1 AND IsEnabled=1)
  BEGIN ROLLBACK;THROW 51303,'New deposit orders are hidden or paused.',1;END;
 IF NOT EXISTS(SELECT 1 FROM dbo.Tbl_ND_Web_Transactions WHERE id=@transactionId AND status='Pending' AND amount>0)
  BEGIN ROLLBACK;THROW 51303,'Pending deposit not found.',1;END;
 IF NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_Deposit_ReceiverHistory WHERE Version=@receiverVersion AND IsEnabled=1 AND (@isGateway=0 OR EnableGateway=1)
   AND LEFT(@orderCode,LEN(OrderPrefix)+LEN(CONVERT(varchar(12),@transactionId))+1)=OrderPrefix+CONVERT(varchar(12),@transactionId)+' '
   AND LEN(@orderCode)=LEN(OrderPrefix)+LEN(CONVERT(varchar(12),@transactionId))+5
   AND RIGHT(@orderCode,4) COLLATE Latin1_General_BIN NOT LIKE '%[^A-HJ-NP-Z2-9]%')
  BEGIN ROLLBACK;THROW 51303,'Invalid order receiver version or order code.',1;END;
 INSERT dbo.Tbl_Web_Deposit_OrderReceivers
  (TransactionId,ReceiverId,RevisionId,Version,BankName,AccountNumber,AccountName,OrderPrefix,QrTemplate,IsEnabled,EnableGateway,IsVisible,OrderCode,IsGateway,UpdatedAt,UpdatedBy)
 SELECT @transactionId,ReceiverId,RevisionId,Version,BankName,AccountNumber,AccountName,OrderPrefix,QrTemplate,IsEnabled,EnableGateway,IsVisible,@orderCode,@isGateway,UpdatedAt,UpdatedBy
 FROM dbo.Tbl_Web_Deposit_ReceiverHistory WHERE Version=@receiverVersion;
 COMMIT;
END;
GO
-- One-time metadata synchronization records the newly hidden state in a revision.
IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE major_id=OBJECT_ID('dbo.Tbl_Web_Deposit_Receivers') AND minor_id=0 AND name='VisibilityInitialized')
BEGIN
 UPDATE dbo.Tbl_Web_Deposit_Receivers SET IsVisible=0 WHERE ReceiverId=1;
 EXEC sys.sp_addextendedproperty @name=N'VisibilityInitialized',@value=N'1',@level0type=N'SCHEMA',@level0name=N'dbo',@level1type=N'TABLE',@level1name=N'Tbl_Web_Deposit_Receivers';
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Deposit_Order @transactionId int
AS
BEGIN
 SET NOCOUNT ON;
 SELECT o.*,t.username Username,t.amount Amount,t.status Status,t.completed_date CompletedAt
 FROM dbo.Tbl_Web_Deposit_OrderReceivers o INNER JOIN dbo.Tbl_ND_Web_Transactions t ON t.id=o.TransactionId WHERE o.TransactionId=@transactionId;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Deposit_OrderForContent @content nvarchar(4000),@isGateway bit=0
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @normalized nvarchar(4000)=UPPER(REPLACE(REPLACE(REPLACE(REPLACE(@content,' ',''),CHAR(9),''),CHAR(10),''),CHAR(13),''));
 -- Exact generated code, including the random suffix; bank descriptions may remove spaces.
 -- Return no result when a description contains more than one distinct order.
 IF (SELECT COUNT(*) FROM dbo.Tbl_Web_Deposit_OrderReceivers o WHERE o.IsGateway=@isGateway
  AND CHARINDEX(UPPER(REPLACE(o.OrderCode,' ','')),@normalized)>0)<>1 RETURN;
 SELECT o.*,t.username Username,t.amount Amount,t.status Status,t.completed_date CompletedAt
 FROM dbo.Tbl_Web_Deposit_OrderReceivers o INNER JOIN dbo.Tbl_ND_Web_Transactions t ON t.id=o.TransactionId
 WHERE o.IsGateway=@isGateway AND CHARINDEX(UPPER(REPLACE(o.OrderCode,' ','')),@normalized)>0;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Deposit_ClaimNotification @leaseId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 UPDATE dbo.Tbl_Web_Deposit_ConfigNotifications SET Status='Review',LeaseId=NULL,LeaseUntil=NULL,
  LastError=N'Phiên gửi bị gián đoạn. Kiểm tra Telegram trước khi gửi lại.' WHERE Status='Sending' AND LeaseUntil<GETDATE();
 DECLARE @jobs TABLE(NotificationId bigint);
 ;WITH nextJob AS (
  SELECT TOP(1) o.* FROM dbo.Tbl_Web_Deposit_ConfigNotifications o WITH(UPDLOCK,READPAST,ROWLOCK)
  WHERE o.Status IN('Pending','Retry') AND o.NextAttemptAt<=GETDATE() AND o.Attempts<8
   AND EXISTS(SELECT 1 FROM dbo.Tbl_Web_Telegram_Settings WHERE SettingsId=1 AND IsEnabled=1 AND NULLIF(ChatId,'') IS NOT NULL)
  ORDER BY o.NotificationId
 )
 UPDATE nextJob SET Status='Sending',Attempts=Attempts+1,LeaseId=@leaseId,LeaseUntil=DATEADD(minute,5,GETDATE()),
  ChatId=(SELECT ChatId FROM dbo.Tbl_Web_Telegram_Settings WHERE SettingsId=1)
 OUTPUT inserted.NotificationId INTO @jobs;
 SELECT n.NotificationId,n.Status,n.Attempts,n.ChatId,n.LastError,n.SentAt,h.*
 FROM @jobs j INNER JOIN dbo.Tbl_Web_Deposit_ConfigNotifications n ON n.NotificationId=j.NotificationId
 INNER JOIN dbo.Tbl_Web_Deposit_ReceiverHistory h ON h.RevisionId=n.RevisionId;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Deposit_FinishNotification
 @id bigint,@leaseId uniqueidentifier,@status varchar(16),@messageId bigint=NULL,@error nvarchar(250)=NULL,@retryAfter int=30
AS
BEGIN
 SET NOCOUNT ON;
 IF @status NOT IN('Sent','Retry','Review','Failed') THROW 51304,'Invalid notification status.',1;
 UPDATE dbo.Tbl_Web_Deposit_ConfigNotifications
 SET Status=CASE WHEN @status='Retry' AND Attempts>=8 THEN 'Failed' ELSE @status END,
  MessageId=@messageId,SentAt=CASE WHEN @status='Sent' THEN GETDATE() ELSE NULL END,LastError=@error,
  NextAttemptAt=DATEADD(second,CASE WHEN @retryAfter<5 THEN 5 WHEN @retryAfter>86400 THEN 86400 ELSE @retryAfter END,GETDATE()),LeaseId=NULL,LeaseUntil=NULL
 WHERE NotificationId=@id AND LeaseId=@leaseId AND Status='Sending';
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Deposit_Admin_Notifications @page int=1
AS
BEGIN
 SET NOCOUNT ON;
 SELECT n.NotificationId,n.Status,n.Attempts,n.ChatId,n.LastError,n.SentAt,h.*
 FROM dbo.Tbl_Web_Deposit_ConfigNotifications n INNER JOIN dbo.Tbl_Web_Deposit_ReceiverHistory h ON h.RevisionId=n.RevisionId
 ORDER BY n.NotificationId DESC OFFSET ((CASE WHEN @page<1 THEN 1 ELSE @page END)-1)*30 ROWS FETCH NEXT 30 ROWS ONLY;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Deposit_Admin_RetryNotification @id bigint,@actor nvarchar(60)
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 BEGIN TRAN;
 UPDATE dbo.Tbl_Web_Deposit_ConfigNotifications SET Status='Pending',Attempts=0,NextAttemptAt=GETDATE(),LastError=NULL
 WHERE NotificationId=@id AND Status IN('Review','Failed','Retry');
 IF @@ROWCOUNT>0 INSERT dbo.Tbl_Web_Telegram_Audit(Actor,Action,Detail) VALUES(@actor,'Retry receiver notification',CONCAT('NotificationId=',@id));
 COMMIT;
END;
