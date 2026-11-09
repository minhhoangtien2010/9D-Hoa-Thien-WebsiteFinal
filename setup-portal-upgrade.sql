-- Cửu Long Hỏa Thiên. Run in the existing NineDragons_Account database.
-- Additive module schema. Existing payment, account and CIS procedures are retained.
SET XACT_ABORT ON;
IF OBJECT_ID('dbo.Tbl_Web_Gacha_Config','U') IS NULL
 CREATE TABLE dbo.Tbl_Web_Gacha_Config(GameType nvarchar(20) NOT NULL PRIMARY KEY,Name nvarchar(120) NOT NULL,Cost int NOT NULL CHECK(Cost>0),TenCost int NOT NULL CHECK(TenCost>0),IsActive bit NOT NULL DEFAULT 1);
IF OBJECT_ID('dbo.Tbl_Web_Gacha_Play','U') IS NULL
 CREATE TABLE dbo.Tbl_Web_Gacha_Play(RequestId uniqueidentifier NOT NULL PRIMARY KEY,Username nvarchar(60) NOT NULL,GameType nvarchar(20) NOT NULL,NewBalance int NOT NULL,CreatedDate datetime2 NOT NULL DEFAULT SYSUTCDATETIME());
IF OBJECT_ID('dbo.Tbl_Web_Gacha_History','U') IS NULL
BEGIN
 CREATE TABLE dbo.Tbl_Web_Gacha_History(LogId bigint IDENTITY PRIMARY KEY,RequestId uniqueidentifier NOT NULL REFERENCES dbo.Tbl_Web_Gacha_Play(RequestId),Username nvarchar(60) NOT NULL,GameType nvarchar(20) NOT NULL,PrizeName nvarchar(250) NOT NULL,Cost int NOT NULL,XuAmount int NOT NULL,CashItemId int NOT NULL,ItemCount int NOT NULL,DeliveryStatus nvarchar(20) NOT NULL,CreatedDate datetime2 NOT NULL DEFAULT SYSUTCDATETIME());
 CREATE INDEX IX_Web_Gacha_History_User ON dbo.Tbl_Web_Gacha_History(Username,LogId DESC);
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_GetTopOnline @top int=100,@faction int=NULL AS
BEGIN SET NOCOUNT ON;
 SELECT TOP (@top) ROW_NUMBER() OVER(ORDER BY c.play_time DESC) Rank,c.chr_name CharacterName,c.play_time PlayTime,c.party Faction,c.class Class
 FROM ND_GAME_0.dbo.ND_V01_Charac c WHERE c.delete_flag=0 AND c.play_time>0 AND (@faction IS NULL OR c.party=@faction) ORDER BY c.play_time DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_GetTopInfamy @top int=100,@faction int=NULL AS
BEGIN SET NOCOUNT ON;
 SELECT TOP (@top) ROW_NUMBER() OVER(ORDER BY s.gong DESC) Rank,c.chr_name CharacterName,s.gong Gong,c.party Faction,c.class Class
 FROM ND_GAME_0.dbo.ND_V01_CharacState s JOIN ND_GAME_0.dbo.ND_V01_Charac c ON c.unique_id=s.unique_id WHERE c.delete_flag=0 AND s.gong>0 AND (@faction IS NULL OR c.party=@faction) ORDER BY s.gong DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_GetTopHonor @top int=100,@faction int=NULL AS
BEGIN SET NOCOUNT ON;
 SELECT TOP (@top) ROW_NUMBER() OVER(ORDER BY s.honor DESC) Rank,c.chr_name CharacterName,s.honor Honor,c.party Faction,c.class Class
 FROM ND_GAME_0.dbo.ND_V01_CharacState s JOIN ND_GAME_0.dbo.ND_V01_Charac c ON c.unique_id=s.unique_id WHERE c.delete_flag=0 AND s.honor>0 AND (@faction IS NULL OR c.party=@faction) ORDER BY s.honor DESC;
END;
GO
IF NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_Gacha_Config WHERE GameType='chest') INSERT dbo.Tbl_Web_Gacha_Config VALUES('chest',N'Rương Kỳ Trân',100,900,1);
IF NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_Gacha_Config WHERE GameType='box') INSERT dbo.Tbl_Web_Gacha_Config VALUES('box',N'Đập Hộp Kỳ Trân',50,500,1);
IF NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_Gacha_Config WHERE GameType='lotto') INSERT dbo.Tbl_Web_Gacha_Config VALUES('lotto',N'Xổ Số Thiên Cơ',20,200,1);
IF NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_Gacha_Prizes WHERE GameType='chest')
 INSERT dbo.Tbl_Web_Gacha_Prizes(GameType,Name,Tier,Weight,CashItemId,ItemCount,XuAmount,IsActive) VALUES('chest',N'50 xu','c',90,0,1,50,1),('chest',N'200 xu','b',9,0,1,200,1),('chest',N'500 xu','a',1,0,1,500,1);
IF NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_Gacha_Prizes WHERE GameType='box')
 INSERT dbo.Tbl_Web_Gacha_Prizes(GameType,Name,Tier,Weight,CashItemId,ItemCount,XuAmount,IsActive) VALUES('box',N'10 xu','c',90,0,1,10,1),('box',N'100 xu','b',9,0,1,100,1),('box',N'300 xu','a',1,0,1,300,1);
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_About_List @admin bit=0 AS
BEGIN SET NOCOUNT ON; SELECT SectionId Id,Eyebrow,Title,Content,ImageUrl,ImagePosition,ButtonText,ButtonUrl,SortOrder,IsPublished FROM dbo.Tbl_Web_AboutSections WHERE @admin=1 OR IsPublished=1 ORDER BY SortOrder,SectionId; END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_About_Admin_Save @Id int,@Title nvarchar(250),@Content nvarchar(max),@Eyebrow nvarchar(120),@ImageUrl nvarchar(1000),@ImagePosition nvarchar(10),@ButtonText nvarchar(100),@ButtonUrl nvarchar(1000),@SortOrder int,@IsPublished bit AS
BEGIN SET NOCOUNT ON;
 IF @Id=0 INSERT dbo.Tbl_Web_AboutSections(Title,Content,Eyebrow,ImageUrl,ImagePosition,ButtonText,ButtonUrl,SortOrder,IsPublished) VALUES(@Title,ISNULL(@Content,''),ISNULL(@Eyebrow,''),ISNULL(@ImageUrl,''),@ImagePosition,ISNULL(@ButtonText,''),ISNULL(@ButtonUrl,''),@SortOrder,@IsPublished);
 ELSE UPDATE dbo.Tbl_Web_AboutSections SET Title=@Title,Content=ISNULL(@Content,''),Eyebrow=ISNULL(@Eyebrow,''),ImageUrl=ISNULL(@ImageUrl,''),ImagePosition=@ImagePosition,ButtonText=ISNULL(@ButtonText,''),ButtonUrl=ISNULL(@ButtonUrl,''),SortOrder=@SortOrder,IsPublished=@IsPublished,UpdatedAt=SYSUTCDATETIME() WHERE SectionId=@Id;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_About_Admin_Delete @id int AS DELETE dbo.Tbl_Web_AboutSections WHERE SectionId=@id;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Gacha_Configs AS SELECT GameType,Name,Cost,TenCost,IsActive FROM dbo.Tbl_Web_Gacha_Config ORDER BY GameType;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Gacha_Admin_Config @GameType nvarchar(20),@Name nvarchar(120),@Cost int,@TenCost int,@IsActive bit AS
 UPDATE dbo.Tbl_Web_Gacha_Config SET Name=@Name,Cost=@Cost,TenCost=@TenCost,IsActive=@IsActive WHERE GameType=@GameType;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Gacha_Admin_Prizes AS SELECT * FROM dbo.Tbl_Web_Gacha_Prizes WHERE GameType IN('chest','box') ORDER BY GameType,PrizeId;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Gacha_Admin_SavePrize @PrizeId int,@GameType nvarchar(20),@Name nvarchar(250),@Tier nvarchar(10),@Weight int,@CashItemId int,@ItemCount int,@XuAmount int,@IsActive bit AS
BEGIN
 IF @Weight<1 OR @Weight>1000000 OR @XuAmount<0 OR @ItemCount<1 OR @ItemCount>100 OR @CashItemId<0 THROW 50001,N'Cấu hình phần thưởng không hợp lệ.',1;
 IF @PrizeId=0 INSERT dbo.Tbl_Web_Gacha_Prizes(GameType,Name,Tier,Weight,CashItemId,ItemCount,XuAmount,IsActive) VALUES(@GameType,@Name,@Tier,@Weight,@CashItemId,@ItemCount,@XuAmount,@IsActive);
 ELSE UPDATE dbo.Tbl_Web_Gacha_Prizes SET GameType=@GameType,Name=@Name,Tier=@Tier,Weight=@Weight,CashItemId=@CashItemId,ItemCount=@ItemCount,XuAmount=@XuAmount,IsActive=@IsActive WHERE PrizeId=@PrizeId;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Gacha_Admin_DeletePrize @id int AS DELETE dbo.Tbl_Web_Gacha_Prizes WHERE PrizeId=@id AND GameType IN('chest','box');
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Gacha_Play @username nvarchar(60),@gameType nvarchar(20),@count int,@pick varchar(3),@requestId uniqueidentifier AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @gameType NOT IN('chest','box','lotto') OR @count NOT IN(1,10) OR (@gameType<>'chest' AND @count<>1) OR LEN(@pick)<>3 OR @pick LIKE '%[^0-9]%' THROW 50001,N'Lượt chơi không hợp lệ.',1;
 BEGIN TRANSACTION;
 DECLARE @lock int;
 EXEC @lock=sys.sp_getapplock @Resource=@username,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=5000;
 IF @lock<0 THROW 50002,N'Tài khoản đang có giao dịch, vui lòng thử lại.',1;
 IF EXISTS(SELECT 1 FROM dbo.Tbl_Web_Gacha_Play WHERE RequestId=@requestId)
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_Gacha_Play WHERE RequestId=@requestId AND Username=@username AND GameType=@gameType) THROW 50003,N'Mã lượt chơi không hợp lệ.',1;
  SELECT h.*,p.NewBalance FROM dbo.Tbl_Web_Gacha_History h JOIN dbo.Tbl_Web_Gacha_Play p ON p.RequestId=h.RequestId WHERE h.RequestId=@requestId ORDER BY h.LogId;
  COMMIT; RETURN;
 END;
 DECLARE @balance int,@cost int,@memberGuid int,@total int;
 SELECT @balance=CAST(balance AS int),@memberGuid=member_guid FROM dbo.Tbl_ND_Web_Member WITH(UPDLOCK,HOLDLOCK) WHERE member_id=@username;
 IF @balance IS NULL THROW 50004,N'Tài khoản chưa có ví xu.',1;
 SELECT @cost=CASE WHEN @count=10 THEN TenCost ELSE Cost END FROM dbo.Tbl_Web_Gacha_Config WHERE GameType=@gameType AND IsActive=1;
 IF @cost IS NULL THROW 50005,N'Trò chơi hiện chưa mở.',1;
 IF @balance<@cost THROW 50006,N'Bạn không đủ xu cho lượt chơi này.',1;
 IF EXISTS(SELECT 1 FROM dbo.Tbl_Web_Gacha_Play WHERE Username=@username AND CreatedDate>DATEADD(SECOND,-2,SYSUTCDATETIME())) THROW 50007,N'Vui lòng chờ 2 giây giữa các lượt chơi.',1;
 INSERT dbo.Tbl_Web_Gacha_Play(RequestId,Username,GameType,NewBalance) VALUES(@requestId,@username,@gameType,@balance);
 DECLARE @i int=0,@name nvarchar(250),@xu int,@item int,@qty int,@draw int,@sum bigint,@roll bigint;
 WHILE @i<@count
 BEGIN
  SET @xu=0;SET @item=0;SET @qty=1;SET @name=NULL;
  IF @gameType='lotto'
  BEGIN
   SET @draw=CAST(CAST(CRYPT_GEN_RANDOM(4) AS bigint)%1000 AS int);
   DECLARE @digits varchar(3)=RIGHT('000'+CAST(@draw AS varchar(3)),3);
   SET @xu=CASE WHEN @digits=@pick THEN 10000 WHEN RIGHT(@digits,2)=RIGHT(@pick,2) THEN 300 WHEN RIGHT(@digits,1)=RIGHT(@pick,1) THEN 30 ELSE 0 END;
   SET @name=N'Số '+@pick+N' · Kết quả '+@digits+N' · '+CAST(@xu AS nvarchar(20))+N' xu';
  END ELSE
  BEGIN
   SELECT @sum=SUM(CAST(Weight AS bigint)) FROM dbo.Tbl_Web_Gacha_Prizes WITH(HOLDLOCK) WHERE GameType=@gameType AND IsActive=1 AND Weight>0 AND CashItemId>=0 AND XuAmount>=0 AND ItemCount BETWEEN 1 AND 100;
   IF ISNULL(@sum,0)<=0 THROW 50008,N'Trò chơi chưa có phần thưởng hợp lệ.',1;
   SET @roll=CAST(CRYPT_GEN_RANDOM(4) AS bigint)%@sum;
   ;WITH weighted AS(SELECT *,SUM(CAST(Weight AS bigint)) OVER(ORDER BY PrizeId ROWS UNBOUNDED PRECEDING) upperBound FROM dbo.Tbl_Web_Gacha_Prizes WHERE GameType=@gameType AND IsActive=1 AND Weight>0 AND CashItemId>=0 AND XuAmount>=0 AND ItemCount BETWEEN 1 AND 100)
   SELECT TOP 1 @name=Name,@xu=XuAmount,@item=CashItemId,@qty=ItemCount FROM weighted WHERE upperBound>@roll ORDER BY upperBound;
  END;
  IF @name IS NULL THROW 50008,N'Không chọn được phần thưởng.',1;
  INSERT dbo.Tbl_Web_Gacha_History(RequestId,Username,GameType,PrizeName,Cost,XuAmount,CashItemId,ItemCount,DeliveryStatus) VALUES(@requestId,@username,@gameType,@name,CASE WHEN @i=0 THEN @cost ELSE 0 END,@xu,@item,@qty,CASE WHEN @item>0 THEN 'Pending' ELSE 'Delivered' END);
  SET @i+=1;
 END;
 SELECT @total=SUM(XuAmount) FROM dbo.Tbl_Web_Gacha_History WHERE RequestId=@requestId;
 UPDATE dbo.Tbl_ND_Web_Member SET balance=balance-@cost+@total,updated_at=GETDATE() WHERE member_id=@username;
 SELECT @balance=CAST(balance AS int) FROM dbo.Tbl_ND_Web_Member WHERE member_id=@username;
 UPDATE dbo.Tbl_Web_Gacha_Play SET NewBalance=@balance WHERE RequestId=@requestId;
 INSERT dbo.Tbl_Web_Shop_Purchases(Username,MemberGuid,ItemId,ItemName,Price,Quantity,PurchaseType,Status,CreatedDate) VALUES(@username,CAST(@memberGuid AS varchar(50)),0,N'Tiên Duyên Các · '+@gameType,@cost,1,'Gacha','Completed',GETDATE());
 SELECT h.*,@balance NewBalance FROM dbo.Tbl_Web_Gacha_History h WHERE RequestId=@requestId ORDER BY LogId;
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Gacha_BeginDelivery @id bigint,@username nvarchar(60) AS
BEGIN SET NOCOUNT ON;UPDATE dbo.Tbl_Web_Gacha_History SET DeliveryStatus='Processing' WHERE LogId=@id AND Username=@username AND DeliveryStatus='Pending';SELECT @@ROWCOUNT;END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Gacha_EndDelivery @id bigint,@success bit AS UPDATE dbo.Tbl_Web_Gacha_History SET DeliveryStatus=CASE WHEN @success=1 THEN 'Delivered' ELSE 'Review' END WHERE LogId=@id AND DeliveryStatus='Processing';
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Gacha_History @username nvarchar(60)=NULL,@page int=1 AS
BEGIN SET NOCOUNT ON;
 ;WITH logs AS(
 SELECT LogId,Username,GameType,PrizeName,Cost,XuAmount,CashItemId,ItemCount,DeliveryStatus,CAST(CreatedDate AS datetime2) CreatedDate FROM dbo.Tbl_Web_Gacha_History
 UNION ALL SELECT LogId,Username,'wheel',ISNULL(PrizeName,N'Vòng quay'),CostAmount,CoinAmount,CashItemId,CashItemCount,CASE WHEN CashItemId>0 THEN 'Legacy' ELSE 'Delivered' END,CAST(CreatedDate AS datetime2) FROM dbo.Tbl_Web_LuckyWheel_SpinLog
 UNION ALL SELECT LogId,Username,'card',ISNULL(GiftName,N'Lật thẻ'),CostAmount,CoinAmount,CashItemId,CashItemCount,CASE WHEN CashItemId>0 THEN 'Legacy' ELSE 'Delivered' END,CAST(CreatedDate AS datetime2) FROM dbo.Tbl_Web_GiftBox_OpenLog)
 SELECT * FROM logs WHERE @username IS NULL OR Username=@username ORDER BY CreatedDate DESC,LogId DESC OFFSET ((CASE WHEN @page<1 THEN 1 ELSE @page END)-1)*30 ROWS FETCH NEXT 30 ROWS ONLY;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_DailyCheckIn_Claim @username nvarchar(60) AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 DECLARE @today date=CONVERT(date,DATEADD(HOUR,7,SYSUTCDATETIME())),@last date,@streak int=0,@reward int=0,@balance int,@guid int;
 SELECT @guid=member_guid FROM dbo.Tbl_ND_Member_Login WHERE member_id=@username;
 IF @guid IS NULL THROW 50004,N'Tài khoản không tồn tại.',1;
 -- Lock the account before checking the daily unique key or crediting coins.
 SELECT @balance=CAST(balance AS int) FROM dbo.Tbl_ND_Web_Member WITH(UPDLOCK,HOLDLOCK) WHERE member_id=@username;
 IF @balance IS NULL BEGIN INSERT dbo.Tbl_ND_Web_Member(member_id,member_guid,balance) VALUES(@username,@guid,0);SET @balance=0;END;
 SELECT TOP 1 @last=CheckInDate,@streak=StreakDay FROM dbo.Web_DailyCheckIn WITH(UPDLOCK,HOLDLOCK) WHERE Username=@username ORDER BY CheckInDate DESC;
 IF @last=@today BEGIN SELECT -2 ResultCode,N'Bạn đã điểm danh hôm nay rồi.' Message,@balance NewBalance,@today CheckInDate,CAST(1 AS bit) CheckedInToday;COMMIT;RETURN;END;
 SET @streak=CASE WHEN @last=DATEADD(DAY,-1,@today) THEN @streak+1 ELSE 1 END;
 SELECT TOP 1 @reward=RewardCoins FROM dbo.Web_DailyCheckInRewardRule WHERE IsActive=1 AND DayNumber<=@streak ORDER BY DayNumber DESC;
 INSERT dbo.Web_DailyCheckIn(Username,CheckInDate,StreakDay,RewardCoins,CreatedDate) VALUES(@username,@today,@streak,@reward,DATEADD(HOUR,7,SYSUTCDATETIME()));
 UPDATE dbo.Tbl_ND_Web_Member SET balance=balance+@reward,updated_at=GETDATE() WHERE member_id=@username;
 SET @balance+=@reward;
 SELECT 1 ResultCode,@reward RewardCoins,@streak StreakDay,@balance NewBalance,@today CheckInDate,CAST(1 AS bit) CheckedInToday,N'Điểm danh thành công.' Message;
 COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Portal_Characters @username nvarchar(60) AS
BEGIN SET NOCOUNT ON;
 SELECT c.chr_name Name,s.inner_level Level,CASE c.party WHEN 1 THEN N'Cái Bang' WHEN 2 THEN N'Bí Cung' WHEN 3 THEN N'Thiếu Lâm' WHEN 4 THEN N'Lục Lâm' WHEN 5 THEN N'Võ Đang' WHEN 6 THEN N'Ma Giáo' ELSE N'Lãng Nhân' END Faction,
 CASE c.class WHEN 1 THEN N'Cận Chiến' WHEN 2 THEN N'Hỗ Trợ' WHEN 3 THEN N'Hoàn Hảo' WHEN 4 THEN N'Khí Công' ELSE N'Chưa chọn' END Responsibility,c.d_date LastLogin
 FROM ND_GAME_0.dbo.ND_V01_Charac c LEFT JOIN ND_GAME_0.dbo.ND_V01_CharacState s ON s.unique_id=c.unique_id
 WHERE c.user_id=@username AND c.delete_flag=0 ORDER BY s.inner_level DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Portal_Admin_Users @search nvarchar(60)=NULL AS
 SELECT TOP 100 m.member_id Username,ISNULL(w.fullname,'') FullName,ISNULL(w.email,'') Email,ISNULL(w.phone,'') Phone,ISNULL(w.balance,0) Balance,CASE WHEN EXISTS(SELECT 1 FROM dbo.Tbl_Blocking b WHERE b.member_id=m.member_id) THEN 'Locked' ELSE 'Active' END Status FROM dbo.Tbl_ND_Member_Login m LEFT JOIN dbo.Tbl_ND_Web_Member w ON m.member_id=w.member_id WHERE @search IS NULL OR m.member_id LIKE '%'+@search+'%' ORDER BY m.member_id;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Portal_Admin_SaveUser @Username nvarchar(60),@Email nvarchar(250),@FullName nvarchar(100),@Phone nvarchar(50),@Status nvarchar(20) AS
BEGIN SET NOCOUNT ON;
 UPDATE dbo.Tbl_ND_Web_Member SET email=@Email,fullname=@FullName,phone=@Phone,updated_at=GETDATE() WHERE member_id=@Username;
 -- The existing game block table has server-specific required fields. Locking stays in the original GM tools.
END;
