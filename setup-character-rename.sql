-- Additive rename request/pricing module in NineDragons_Account.
-- Offline-only completion: the user must close the game first. No kick or ban fields are changed.
-- Both cur_state=0 and temp_id=0 plus a stable real logout are required; cur_state alone is insufficient.
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.Tbl_Web_Rename_Pricing',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.Tbl_Web_Rename_Pricing(
  PriceId int IDENTITY(1,1) NOT NULL PRIMARY KEY,Name nvarchar(120) NOT NULL,
  Price int NOT NULL CHECK(Price BETWEEN 1 AND 1000000),IsEnabled bit NOT NULL DEFAULT 1,
  IsCurrent bit NOT NULL DEFAULT 0,IsArchived bit NOT NULL DEFAULT 0,
  CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),UpdatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
  UpdatedBy nvarchar(100) NOT NULL,Revision rowversion NOT NULL
 );
 CREATE UNIQUE INDEX UX_Web_Rename_CurrentPrice ON dbo.Tbl_Web_Rename_Pricing(IsCurrent) WHERE IsCurrent=1;
END;
IF OBJECT_ID(N'dbo.Tbl_Web_Rename_Requests',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.Tbl_Web_Rename_Requests(
  RequestId uniqueidentifier NOT NULL PRIMARY KEY,Username nvarchar(60) NOT NULL,MemberGuid int NOT NULL,
  CharacterId int NOT NULL,OldName varchar(12) NOT NULL,NewName varchar(12) NOT NULL,
  PriceId int NOT NULL REFERENCES dbo.Tbl_Web_Rename_Pricing(PriceId),QuotedPrice int NOT NULL,
  ChargedPrice int NOT NULL DEFAULT 0,Status varchar(30) NOT NULL DEFAULT 'WaitingForServer',
  CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),ExpiresAt datetime2 NOT NULL,
  UpdatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),UpdatedBy nvarchar(100) NOT NULL,
  AdminNote nvarchar(1000) NOT NULL DEFAULT N'',IPAddress nvarchar(45) NOT NULL DEFAULT N'',
  CompletedAt datetime2 NULL,LoginAllowedAt datetime2 NULL,PurchaseId int NULL,Revision rowversion NOT NULL,
  CONSTRAINT CK_Rename_RequestStatus CHECK(Status IN('WaitingForServer','Cancelled','Rejected','Expired','Applied')),
  CONSTRAINT CK_Rename_RequestCharge CHECK((Status='Applied' AND ChargedPrice=QuotedPrice AND PurchaseId IS NOT NULL) OR (Status<>'Applied' AND ChargedPrice=0 AND PurchaseId IS NULL))
 );
 CREATE INDEX IX_Web_Rename_User ON dbo.Tbl_Web_Rename_Requests(Username,CreatedAt DESC);
 CREATE INDEX IX_Web_Rename_Character ON dbo.Tbl_Web_Rename_Requests(CharacterId,Status,ExpiresAt);
 CREATE INDEX IX_Web_Rename_NewName ON dbo.Tbl_Web_Rename_Requests(NewName,Status,ExpiresAt);
END;
IF OBJECT_ID(N'dbo.Tbl_Web_Rename_Audit',N'U') IS NULL
 CREATE TABLE dbo.Tbl_Web_Rename_Audit(
  AuditId bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,RequestId uniqueidentifier NULL,PriceId int NULL,
  Action varchar(30) NOT NULL,Actor nvarchar(100) NOT NULL,Details nvarchar(1500) NOT NULL,
  CreatedAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME()
 );
IF NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_Rename_Pricing)
 INSERT dbo.Tbl_Web_Rename_Pricing(Name,Price,IsEnabled,IsCurrent,UpdatedBy) VALUES(N'Đổi tên nhân vật',200,1,1,N'migration');
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Rename_State @Username nvarchar(60) AS
BEGIN
 SET NOCOUNT ON;
 SELECT TOP 1 PriceId,Name,Price,IsEnabled,IsCurrent,IsArchived,UpdatedAt,UpdatedBy,master.dbo.fn_varbintohexstr(Revision) Version
 FROM dbo.Tbl_Web_Rename_Pricing WHERE IsCurrent=1 AND IsArchived=0;
 SELECT c.unique_id CharacterId,c.chr_name Name,c.party Faction,c.class Responsibility,c.sex Sex,
 CAST(CASE WHEN g.cur_state=1 OR ISNULL(g.temp_id,0)<>0 THEN 1 ELSE 0 END AS bit) IsOnline,
 CAST(CASE WHEN g.cur_state=0 AND g.temp_id=0 AND g.logout_time>=g.login_time AND g.logout_time<=DATEADD(SECOND,-30,GETDATE()) THEN 1 ELSE 0 END AS bit) CanRename
 FROM ND_GAME_0.dbo.ND_V01_Charac c JOIN dbo.Tbl_ND_Member_Login m ON m.member_guid=c.acc_id
 LEFT JOIN dbo.Tbl_ND_GameConnect g ON g.member_guid=m.member_guid
 WHERE m.member_id=@Username AND c.delete_flag=0 ORDER BY c.unique_id;
 SELECT TOP 50 RequestId,Username,MemberGuid,CharacterId,OldName,NewName,PriceId,QuotedPrice,ChargedPrice,
 CASE WHEN Status='WaitingForServer' AND ExpiresAt<=SYSUTCDATETIME() THEN 'Expired' ELSE Status END Status,
 CreatedAt,ExpiresAt,UpdatedAt,UpdatedBy,AdminNote,CompletedAt,LoginAllowedAt,PurchaseId,master.dbo.fn_varbintohexstr(Revision) Version
 FROM dbo.Tbl_Web_Rename_Requests WHERE Username=@Username ORDER BY CreatedAt DESC;
 SELECT ISNULL((SELECT balance FROM dbo.Tbl_ND_Web_Member WHERE member_id=@Username),0) Balance;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Rename_Request
 @Username nvarchar(60),@CharacterId int,@NewName nvarchar(60),@RequestId uniqueidentifier,
 @PriceId int,@PriceVersion varchar(18),@IPAddress nvarchar(45)=N'' AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @CharacterId<=0 OR @RequestId IS NULL OR LEN(@NewName)<3 OR LEN(@NewName)>12 OR DATALENGTH(@NewName)<>DATALENGTH(LTRIM(RTRIM(@NewName)))
 OR @NewName COLLATE Latin1_General_BIN LIKE N'%[^A-Za-z0-9_]%' THROW 51400,N'Tên mới cần từ 3 đến 12 chữ cái không dấu, chữ số hoặc dấu gạch dưới.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
  DECLARE @lock int,@resource nvarchar(255)=N'WebRename:User:'+@Username;
  EXEC @lock=sys.sp_getapplock @Resource=@resource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=5000;
  IF @lock<0 THROW 51401,N'Tài khoản đang có yêu cầu khác. Vui lòng thử lại.',1;
  SET @resource=N'WebRename:Name:'+LOWER(@NewName);
  EXEC @lock=sys.sp_getapplock @Resource=@resource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=5000;
  IF @lock<0 THROW 51401,N'Tên đang được kiểm tra. Vui lòng thử lại.',1;
  IF EXISTS(SELECT 1 FROM dbo.Tbl_Web_Rename_Requests WITH(UPDLOCK,HOLDLOCK) WHERE RequestId=@RequestId)
  BEGIN
   IF NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_Rename_Requests WHERE RequestId=@RequestId AND Username=@Username AND CharacterId=@CharacterId AND NewName=@NewName)
    THROW 51402,N'Mã yêu cầu không hợp lệ.',1;
   SELECT RequestId,Status,QuotedPrice,ChargedPrice FROM dbo.Tbl_Web_Rename_Requests WHERE RequestId=@RequestId;
   COMMIT;RETURN;
  END;
  DECLARE @member int,@old varchar(12),@price int;
  SELECT @member=m.member_guid FROM dbo.Tbl_ND_Member_Login m JOIN dbo.Tbl_ND_Web_Member w ON w.member_id=m.member_id
  WHERE m.member_id=@Username AND COALESCE(NULLIF(w.status,N''),N'Active')=N'Active' AND m.member_class NOT IN(1,254,255)
  AND NOT EXISTS(SELECT 1 FROM dbo.Tbl_Blocking b WHERE b.member_id=m.member_id);
  IF @member IS NULL THROW 51403,N'Tài khoản chưa sẵn sàng cho yêu cầu đổi tên.',1;
  SELECT @old=chr_name FROM ND_GAME_0.dbo.ND_V01_Charac WITH(UPDLOCK,HOLDLOCK) WHERE unique_id=@CharacterId AND acc_id=@member AND delete_flag=0;
  IF @old IS NULL THROW 51404,N'Nhân vật không thuộc tài khoản của bạn hoặc đã bị xóa.',1;
  IF @old=CONVERT(varchar(12),@NewName) THROW 51405,N'Tên mới cần khác tên hiện tại.',1;
  IF EXISTS(SELECT 1 FROM ND_GAME_0.dbo.ND_V01_Charac WHERE chr_name=CONVERT(varchar(12),@NewName)) THROW 51406,N'Tên nhân vật đã được sử dụng.',1;
  SELECT @price=Price FROM dbo.Tbl_Web_Rename_Pricing WITH(UPDLOCK,HOLDLOCK) WHERE PriceId=@PriceId AND IsCurrent=1 AND IsArchived=0 AND IsEnabled=1
  AND master.dbo.fn_varbintohexstr(Revision)=@PriceVersion;
  IF @price IS NULL THROW 51407,N'Phí hoặc trạng thái dịch vụ đã thay đổi. Vui lòng tải lại trang.',1;
  UPDATE dbo.Tbl_Web_Rename_Requests SET Status='Expired',UpdatedAt=SYSUTCDATETIME(),UpdatedBy=N'system'
  WHERE Status='WaitingForServer' AND ExpiresAt<=SYSUTCDATETIME() AND (Username=@Username OR NewName=CONVERT(varchar(12),@NewName));
  IF EXISTS(SELECT 1 FROM dbo.Tbl_Web_Rename_Requests WHERE CharacterId=@CharacterId AND Status='WaitingForServer' AND ExpiresAt>SYSUTCDATETIME())
   THROW 51408,N'Nhân vật đang có yêu cầu đổi tên chờ xử lý. Bạn có thể hủy yêu cầu cũ trước.',1;
  IF EXISTS(SELECT 1 FROM dbo.Tbl_Web_Rename_Requests WHERE NewName=CONVERT(varchar(12),@NewName) AND Status='WaitingForServer' AND ExpiresAt>SYSUTCDATETIME())
   THROW 51409,N'Tên này đang có yêu cầu chờ xử lý. Vui lòng chọn tên khác.',1;
  INSERT dbo.Tbl_Web_Rename_Requests(RequestId,Username,MemberGuid,CharacterId,OldName,NewName,PriceId,QuotedPrice,ExpiresAt,UpdatedBy,IPAddress)
  VALUES(@RequestId,@Username,@member,@CharacterId,@old,CONVERT(varchar(12),@NewName),@PriceId,@price,DATEADD(HOUR,24,SYSUTCDATETIME()),@Username,ISNULL(@IPAddress,N''));
  INSERT dbo.Tbl_Web_Rename_Audit(RequestId,PriceId,Action,Actor,Details) VALUES(@RequestId,@PriceId,'Request',@Username,N'Yêu cầu chờ xử lý; chưa trừ xu, chưa đổi tên, chưa khóa tài khoản.');
  SELECT RequestId,Status,QuotedPrice,ChargedPrice FROM dbo.Tbl_Web_Rename_Requests WHERE RequestId=@RequestId;
  COMMIT;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK;THROW;END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Rename_Cancel @Username nvarchar(60),@RequestId uniqueidentifier AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 UPDATE dbo.Tbl_Web_Rename_Requests SET Status='Cancelled',UpdatedAt=SYSUTCDATETIME(),UpdatedBy=@Username
 WHERE RequestId=@RequestId AND Username=@Username AND Status='WaitingForServer' AND ChargedPrice=0;
 IF @@ROWCOUNT<>1 BEGIN ROLLBACK;THROW 51410,N'Yêu cầu không còn ở trạng thái có thể hủy.',1;END;
 INSERT dbo.Tbl_Web_Rename_Audit(RequestId,Action,Actor,Details) VALUES(@RequestId,'Cancel',@Username,N'Người chơi hủy yêu cầu chưa thu phí.');
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Rename_Admin_Pricing AS
BEGIN SET NOCOUNT ON;
 SELECT PriceId,Name,Price,IsEnabled,IsCurrent,IsArchived,UpdatedAt,UpdatedBy,master.dbo.fn_varbintohexstr(Revision) Version FROM dbo.Tbl_Web_Rename_Pricing ORDER BY IsArchived,IsCurrent DESC,PriceId DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Rename_Admin_SavePrice
 @PriceId int,@Name nvarchar(120),@Price int,@IsEnabled bit,@IsCurrent bit,@Version varchar(18)=NULL,@Actor nvarchar(100) AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @Price<1 OR @Price>1000000 OR LEN(LTRIM(RTRIM(@Name)))=0 THROW 51411,N'Tên cấu hình và phí đổi tên không hợp lệ.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
  DECLARE @lock int;EXEC @lock=sys.sp_getapplock @Resource=N'WebRename:Pricing',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=5000;
  IF @lock<0 THROW 51401,N'Cấu hình đang được cập nhật. Vui lòng thử lại.',1;
  IF @PriceId<>0 AND NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_Rename_Pricing WITH(UPDLOCK,HOLDLOCK) WHERE PriceId=@PriceId AND IsArchived=0 AND master.dbo.fn_varbintohexstr(Revision)=@Version)
   THROW 51412,N'Cấu hình đã thay đổi. Vui lòng tải lại trang.',1;
  IF @IsCurrent=1 UPDATE dbo.Tbl_Web_Rename_Pricing SET IsCurrent=0,UpdatedAt=SYSUTCDATETIME(),UpdatedBy=@Actor WHERE IsCurrent=1 AND PriceId<>@PriceId;
  IF @PriceId=0
  BEGIN
   INSERT dbo.Tbl_Web_Rename_Pricing(Name,Price,IsEnabled,IsCurrent,UpdatedBy) VALUES(LTRIM(RTRIM(@Name)),@Price,@IsEnabled,@IsCurrent,@Actor);
   SET @PriceId=SCOPE_IDENTITY();
  END
  ELSE UPDATE dbo.Tbl_Web_Rename_Pricing SET Name=LTRIM(RTRIM(@Name)),Price=@Price,IsEnabled=@IsEnabled,IsCurrent=@IsCurrent,UpdatedAt=SYSUTCDATETIME(),UpdatedBy=@Actor WHERE PriceId=@PriceId;
  INSERT dbo.Tbl_Web_Rename_Audit(PriceId,Action,Actor,Details) VALUES(@PriceId,'SavePrice',@Actor,N'Phí '+CONVERT(nvarchar(20),@Price)+N' xu. Nhận yêu cầu: '+CONVERT(nvarchar(1),@IsEnabled)+N'. Đang áp dụng: '+CONVERT(nvarchar(1),@IsCurrent));
  COMMIT;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK;THROW;END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Rename_Admin_ArchivePrice @PriceId int,@Version varchar(18),@Actor nvarchar(100) AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 UPDATE dbo.Tbl_Web_Rename_Pricing SET IsArchived=1,IsCurrent=0,IsEnabled=0,UpdatedAt=SYSUTCDATETIME(),UpdatedBy=@Actor
 WHERE PriceId=@PriceId AND IsArchived=0 AND master.dbo.fn_varbintohexstr(Revision)=@Version;
 IF @@ROWCOUNT<>1 BEGIN ROLLBACK;THROW 51412,N'Cấu hình đã thay đổi. Vui lòng tải lại trang.',1;END;
 INSERT dbo.Tbl_Web_Rename_Audit(PriceId,Action,Actor,Details) VALUES(@PriceId,'ArchivePrice',@Actor,N'Xóa khỏi danh sách áp dụng; giữ lịch sử yêu cầu cũ.');
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Rename_Admin_Requests @Username nvarchar(60)=NULL,@Page int=1 AS
BEGIN
 SET NOCOUNT ON;IF @Page<1 SET @Page=1;
 ;WITH rows AS(SELECT *,ROW_NUMBER() OVER(ORDER BY CreatedAt DESC,RequestId) RowNumber FROM dbo.Tbl_Web_Rename_Requests WHERE @Username IS NULL OR Username=@Username)
 SELECT RequestId,Username,MemberGuid,CharacterId,OldName,NewName,PriceId,QuotedPrice,ChargedPrice,
 CASE WHEN Status='WaitingForServer' AND ExpiresAt<=SYSUTCDATETIME() THEN 'Expired' ELSE Status END Status,
 CreatedAt,ExpiresAt,UpdatedAt,UpdatedBy,AdminNote,CompletedAt,LoginAllowedAt,PurchaseId,master.dbo.fn_varbintohexstr(Revision) Version
 FROM rows WHERE RowNumber>(CONVERT(bigint,@Page)-1)*50 AND RowNumber<=CONVERT(bigint,@Page)*50 ORDER BY CreatedAt DESC,RequestId;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Rename_Admin_Reject @RequestId uniqueidentifier,@Version varchar(18),@Note nvarchar(1000),@Actor nvarchar(100) AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF LEN(LTRIM(RTRIM(@Note)))=0 THROW 51413,N'Vui lòng ghi lý do từ chối.',1;
 BEGIN TRANSACTION;
 UPDATE dbo.Tbl_Web_Rename_Requests SET Status='Rejected',AdminNote=@Note,UpdatedAt=SYSUTCDATETIME(),UpdatedBy=@Actor
 WHERE RequestId=@RequestId AND Status='WaitingForServer' AND ChargedPrice=0 AND master.dbo.fn_varbintohexstr(Revision)=@Version;
 IF @@ROWCOUNT<>1 BEGIN ROLLBACK;THROW 51414,N'Yêu cầu đã thay đổi hoặc không còn chờ xử lý.',1;END;
 INSERT dbo.Tbl_Web_Rename_Audit(RequestId,Action,Actor,Details) VALUES(@RequestId,'Reject',@Actor,@Note);
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Rename_Admin_Audit @Page int=1 AS
BEGIN SET NOCOUNT ON;IF @Page<1 SET @Page=1;
 ;WITH rows AS(SELECT *,ROW_NUMBER() OVER(ORDER BY AuditId DESC) RowNumber FROM dbo.Tbl_Web_Rename_Audit)
 SELECT AuditId,RequestId,PriceId,Action,Actor,Details,CreatedAt FROM rows WHERE RowNumber>(CONVERT(bigint,@Page)-1)*50 AND RowNumber<=CONVERT(bigint,@Page)*50 ORDER BY AuditId DESC;
END;
GO
SELECT PriceId,Name,Price,IsEnabled,IsCurrent FROM dbo.Tbl_Web_Rename_Pricing WHERE IsCurrent=1;
