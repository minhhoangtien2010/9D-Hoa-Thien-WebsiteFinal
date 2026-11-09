-- Actual offline-only rename. All mutations across the account/game databases commit together.
-- Reuses the installed game rename and master/pupil naming procedures. Never simulates a disconnect.
SET XACT_ABORT ON;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Rename_Apply
 @Username nvarchar(60),@CharacterId int,@NewName nvarchar(60),@RequestId uniqueidentifier,
 @PriceId int,@PriceVersion varchar(18),@IPAddress nvarchar(45)=N'' AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @CharacterId<=0 OR @RequestId IS NULL OR LEN(@NewName)<3 OR LEN(@NewName)>12 OR DATALENGTH(@NewName)<>DATALENGTH(LTRIM(RTRIM(@NewName)))
 OR @NewName COLLATE Latin1_General_BIN LIKE N'%[^A-Za-z0-9_]%' THROW 51400,N'Tên mới cần từ 3 đến 12 chữ cái không dấu, chữ số hoặc dấu gạch dưới.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
  DECLARE @lock int,@resource nvarchar(255)=@Username;
  -- Uses the same wallet resource as other new spending operations, plus actual wallet row locks below.
  EXEC @lock=sys.sp_getapplock @Resource=@resource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=5000;
  IF @lock<0 THROW 51401,N'Tài khoản đang có giao dịch. Vui lòng thử lại.',1;
  SET @resource=N'WebRename:Name:'+LOWER(@NewName);
  EXEC @lock=sys.sp_getapplock @Resource=@resource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=5000;
  IF @lock<0 THROW 51401,N'Tên đang được kiểm tra. Vui lòng thử lại.',1;
  IF EXISTS(SELECT 1 FROM dbo.Tbl_Web_Rename_Requests WITH(UPDLOCK,HOLDLOCK) WHERE RequestId=@RequestId)
  BEGIN
   IF NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_Rename_Requests WHERE RequestId=@RequestId AND Username=@Username AND CharacterId=@CharacterId AND NewName=@NewName AND Status='Applied')
    THROW 51402,N'Mã giao dịch không hợp lệ hoặc đã được sử dụng.',1;
   SELECT RequestId,Username,CharacterId,OldName,NewName,QuotedPrice,ChargedPrice,Status,CompletedAt,PurchaseId FROM dbo.Tbl_Web_Rename_Requests WHERE RequestId=@RequestId;
   COMMIT;RETURN;
  END;
  DECLARE @member int,@old varchar(12),@name varchar(12)=CONVERT(varchar(12),@NewName),@price int,@balance decimal(18,2),@purchase int;
  SELECT @member=m.member_guid FROM dbo.Tbl_ND_Member_Login m WITH(UPDLOCK,HOLDLOCK)
  JOIN dbo.Tbl_ND_Web_Member w ON w.member_id=m.member_id
  WHERE m.member_id=@Username AND COALESCE(NULLIF(w.status,N''),N'Active')=N'Active' AND m.member_class NOT IN(1,254,255)
  AND NOT EXISTS(SELECT 1 FROM dbo.Tbl_Blocking b WHERE b.member_id=m.member_id);
  IF @member IS NULL THROW 51403,N'Tài khoản chưa sẵn sàng cho dịch vụ đổi tên.',1;
  -- _prDS_Logout clears both fields; duplicate login only clears cur_state.
  IF NOT EXISTS(SELECT 1 FROM dbo.Tbl_ND_GameConnect WITH(UPDLOCK,HOLDLOCK)
    WHERE member_guid=@member AND member_id=@Username AND cur_state=0 AND temp_id=0
    AND logout_time>=login_time AND logout_time<=DATEADD(SECOND,-30,GETDATE()))
   THROW 51415,N'Vui lòng thoát hoàn toàn game trước khi đổi tên nhân vật. Chờ ít nhất 30 giây rồi tải lại trang; giữ game đóng đến khi đổi tên thành công.',1;
  SELECT @old=chr_name FROM ND_GAME_0.dbo.ND_V01_Charac WITH(UPDLOCK,HOLDLOCK) WHERE unique_id=@CharacterId AND acc_id=@member AND delete_flag=0;
  IF @old IS NULL THROW 51404,N'Nhân vật không thuộc tài khoản của bạn hoặc đã bị xóa.',1;
  IF @old=@name THROW 51405,N'Tên mới cần khác tên hiện tại.',1;
  IF EXISTS(SELECT 1 FROM ND_GAME_0.dbo.ND_V01_Charac WITH(UPDLOCK,HOLDLOCK) WHERE chr_name=@name)
   THROW 51406,N'Tên nhân vật đã được sử dụng.',1;
  IF EXISTS(SELECT 1 FROM dbo.Tbl_Web_Rename_Requests WITH(UPDLOCK,HOLDLOCK) WHERE NewName=@name AND Status='WaitingForServer' AND ExpiresAt>SYSUTCDATETIME())
   THROW 51409,N'Tên này đang có yêu cầu chờ xử lý. Vui lòng chọn tên khác.',1;
  SELECT @price=Price FROM dbo.Tbl_Web_Rename_Pricing WITH(UPDLOCK,HOLDLOCK) WHERE PriceId=@PriceId AND IsCurrent=1 AND IsArchived=0 AND IsEnabled=1
   AND master.dbo.fn_varbintohexstr(Revision)=@PriceVersion;
  IF @price IS NULL THROW 51407,N'Phí hoặc trạng thái dịch vụ đã thay đổi. Vui lòng tải lại trang.',1;
  SELECT @balance=balance FROM dbo.Tbl_ND_Web_Member WITH(UPDLOCK,HOLDLOCK) WHERE member_id=@Username AND COALESCE(NULLIF(status,N''),N'Active')=N'Active';
  IF @balance IS NULL OR @balance<@price THROW 51416,N'Bạn không đủ xu để đổi tên nhân vật.',1;
  IF EXISTS(SELECT 1 FROM dbo.ND_9DF_HWID_BAN_2 WHERE acc_id=@Username AND block_hwid=1)
   OR EXISTS(SELECT 1 FROM dbo.ND_9DF_HWID_BAN_2 b JOIN dbo.ND_9DF_HWID_BAN_2 a ON a.HWID=b.HWID WHERE a.acc_id=@Username AND b.block_hwid=1)
   THROW 51403,N'Tài khoản chưa sẵn sàng cho dịch vụ đổi tên.',1;
  UPDATE dbo.Tbl_ND_Web_Member SET balance=balance-@price,
    character_name=CASE WHEN character_name=CONVERT(nvarchar(12),@old) THEN CONVERT(nvarchar(12),@name) ELSE character_name END,updated_at=GETDATE()
   WHERE member_id=@Username AND balance>=@price;
  IF @@ROWCOUNT<>1 THROW 51416,N'Bạn không đủ xu để đổi tên nhân vật.',1;
  EXEC ND_GAME_0.dbo._prDS_CharacRename @CurName=@old,@NewName=@name;
  IF NOT EXISTS(SELECT 1 FROM ND_GAME_0.dbo.ND_V01_Charac WHERE unique_id=@CharacterId AND acc_id=@member AND chr_name=@name)
   THROW 51417,N'Không thể xác nhận tên mới. Giao dịch đã được hoàn tác.',1;
  EXEC ND_GAME_0.dbo._prDS_MP_UpdateName @index=@CharacterId,@where=0,@name=@name;
  EXEC ND_GAME_0.dbo._prDS_MP_UpdateName @index=@CharacterId,@where=1,@name=@name;
  -- Current display indexes only. Historical battle/master/pupil logs remain original records.
  UPDATE ND_GAME_0.dbo.ND_V01_Organization SET captain_name=@name WHERE captain_name=@old;
  UPDATE ND_GAME_0.dbo.ND_V01_Ranking_Level SET chr_name=@name WHERE chr_name=@old;
  INSERT dbo.Tbl_Web_Shop_Purchases(Username,MemberGuid,ItemId,ItemName,Price,Quantity,PurchaseType,Status,IPAddress,CreatedDate)
   VALUES(@Username,CONVERT(varchar(50),@member),0,N'Đổi tên nhân vật: '+CONVERT(nvarchar(12),@old)+N' → '+@NewName,@price,1,N'CharacterRename',N'Completed',@IPAddress,GETDATE());
  SET @purchase=SCOPE_IDENTITY();
  INSERT dbo.Tbl_Web_Rename_Requests(RequestId,Username,MemberGuid,CharacterId,OldName,NewName,PriceId,QuotedPrice,ChargedPrice,Status,ExpiresAt,UpdatedBy,IPAddress,CompletedAt,PurchaseId)
   VALUES(@RequestId,@Username,@member,@CharacterId,@old,@name,@PriceId,@price,@price,'Applied',SYSUTCDATETIME(),@Username,ISNULL(@IPAddress,N''),SYSUTCDATETIME(),@purchase);
  INSERT dbo.Tbl_Web_Rename_Audit(RequestId,PriceId,Action,Actor,Details)
   VALUES(@RequestId,@PriceId,'Applied',@Username,N'Đổi tên khi tài khoản đã thoát game; thu '+CONVERT(nvarchar(20),@price)+N' xu. Không dùng cơ chế đá/khóa tài khoản.');
  SELECT RequestId,Username,CharacterId,OldName,NewName,QuotedPrice,ChargedPrice,Status,CompletedAt,PurchaseId FROM dbo.Tbl_Web_Rename_Requests WHERE RequestId=@RequestId;
  COMMIT;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK;THROW;END CATCH;
END;
GO
