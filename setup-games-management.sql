-- Cửu Long Hỏa Thiên: shared website/SQL reward management for all five games.
-- Existing credit, spending ledger and CIS delivery paths remain in place.
SET XACT_ABORT ON;
IF COL_LENGTH('dbo.Tbl_Web_GiftBox_Gift','Weight') IS NULL
 ALTER TABLE dbo.Tbl_Web_GiftBox_Gift ADD Weight int NOT NULL CONSTRAINT DF_Web_GiftBox_Gift_Weight DEFAULT 1;
IF COL_LENGTH('dbo.Tbl_Web_Gacha_Prizes','MatchDigits') IS NULL
 ALTER TABLE dbo.Tbl_Web_Gacha_Prizes ADD MatchDigits int NOT NULL CONSTRAINT DF_Web_Gacha_Prizes_MatchDigits DEFAULT 0;
GO
IF NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_Gacha_Prizes WHERE GameType='lotto')
 INSERT dbo.Tbl_Web_Gacha_Prizes(GameType,Name,Tier,Weight,CashItemId,ItemCount,XuAmount,IsActive,MatchDigits)
 VALUES('lotto',N'Trùng 3 số','s',1,0,1,10000,1,3),('lotto',N'Trùng 2 số cuối','a',9,0,1,300,1,2),('lotto',N'Trùng 1 số cuối','b',90,0,1,30,1,1),('lotto',N'Chưa trúng thưởng','c',900,0,1,0,1,0);
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Games_Admin_ConfigureReward
 @GameType nvarchar(20),@Id int,@Weight int,@IsActive bit
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @Weight<0 OR @Weight>1000000 THROW 50001,N'Trọng số phải từ 0 đến 1.000.000.',1;
 IF @GameType='wheel' UPDATE dbo.Tbl_Web_LuckyWheel_Prize SET Weight=@Weight,IsActive=@IsActive WHERE PrizeId=@Id;
 ELSE IF @GameType='card' UPDATE dbo.Tbl_Web_GiftBox_Gift SET Weight=@Weight,IsActive=@IsActive WHERE GiftId=@Id;
 ELSE IF @GameType IN('chest','box','lotto') UPDATE dbo.Tbl_Web_Gacha_Prizes SET Weight=@Weight,IsActive=@IsActive WHERE PrizeId=@Id AND GameType=@GameType;
 ELSE THROW 50001,N'Trò chơi không hợp lệ.',1;
 IF @@ROWCOUNT=0 THROW 50001,N'Phần thưởng không còn tồn tại.',1;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Games_Catalog @admin bit=0 AS
BEGIN
 SET NOCOUNT ON;
 ;WITH wheel AS(
  SELECT p.*,SUM(CASE WHEN p.IsActive=1 AND p.Weight>0 AND(p.StockTotal=0 OR p.StockRemaining>0) THEN CAST(p.Weight AS bigint) ELSE 0 END) OVER(PARTITION BY p.WheelId) TotalWeight
  FROM dbo.Tbl_Web_LuckyWheel_Prize p),
 card AS(
  SELECT g.*,r.ConfigId,r.RoundNumber,r.BoxCount,r.AdvanceMode,
   SUM(CASE WHEN g.IsActive=1 AND g.Weight>0 THEN CAST(g.Weight AS bigint) ELSE 0 END) OVER(PARTITION BY g.RoundId) TotalWeight,
   SUM(CASE WHEN g.IsActive=1 AND g.Weight>0 THEN CAST(g.Weight AS bigint) ELSE 0 END) OVER(PARTITION BY g.RoundId,g.IsAdvance) ClassWeight
  FROM dbo.Tbl_Web_GiftBox_Gift g JOIN dbo.Tbl_Web_GiftBox_Round r ON r.RoundId=g.RoundId),
 portal AS(
  SELECT p.*,SUM(CASE WHEN p.IsActive=1 AND p.Weight>0 AND p.CashItemId>=0 AND p.XuAmount>=0 AND p.ItemCount BETWEEN 1 AND 100 THEN CAST(p.Weight AS bigint) ELSE 0 END) OVER(PARTITION BY p.GameType) TotalWeight
  FROM dbo.Tbl_Web_Gacha_Prizes p)
 SELECT 'wheel' GameType,p.PrizeId Id,p.WheelId ParentId,c.WheelName ParentLabel,p.PrizeName Name,p.Weight,p.IsActive,p.CashItemId,p.CashItemCount ItemCount,p.CoinAmount XuAmount,p.RewardType,p.StockTotal,p.StockRemaining,p.IsJackpot IsAdvance,CAST(0 AS int) MatchDigits,
  CAST(CASE WHEN p.IsActive=1 AND p.Weight>0 AND(p.StockTotal=0 OR p.StockRemaining>0) THEN 100.0*p.Weight/NULLIF(p.TotalWeight,0) ELSE 0 END AS decimal(12,6)) OddsPercent,
  CAST(0 AS int) AdvanceMode,c.IsActive GameIsActive
 FROM wheel p JOIN dbo.Tbl_Web_LuckyWheel_Config c ON c.WheelId=p.WheelId WHERE @admin=1 OR(c.IsActive=1 AND c.ShowOdds=1 AND p.IsActive=1 AND p.Weight>0 AND(p.StockTotal=0 OR p.StockRemaining>0))
 UNION ALL
 SELECT 'card',p.GiftId,p.RoundId,c.EventName+N' · Vòng '+CONVERT(nvarchar(10),p.RoundNumber),p.GiftName,p.Weight,p.IsActive,p.CashItemId,p.CashItemCount,p.CoinAmount,p.RewardType,0,0,p.IsAdvance,0,
  CAST(CASE WHEN p.IsActive=1 AND p.Weight>0 THEN CASE WHEN p.AdvanceMode=1 THEN 100.0*p.Weight/NULLIF(p.TotalWeight,0) WHEN p.IsAdvance=1 THEN 100.0*p.Weight/NULLIF(p.ClassWeight,0)/NULLIF(p.BoxCount,0) ELSE 100.0*p.Weight/NULLIF(p.ClassWeight,0)*(p.BoxCount-1)/NULLIF(p.BoxCount,0) END ELSE 0 END AS decimal(12,6)),p.AdvanceMode,c.IsActive
 FROM card p JOIN dbo.Tbl_Web_GiftBox_Config c ON c.ConfigId=p.ConfigId WHERE @admin=1 OR(c.IsActive=1 AND p.IsActive=1 AND p.Weight>0)
 UNION ALL
 SELECT p.GameType,p.PrizeId,0,c.Name,p.Name,p.Weight,p.IsActive,p.CashItemId,p.ItemCount,p.XuAmount,CASE WHEN p.CashItemId>0 THEN 1 ELSE 2 END,0,0,CAST(0 AS bit),p.MatchDigits,
  CAST(CASE WHEN p.IsActive=1 AND p.Weight>0 THEN 100.0*p.Weight/NULLIF(p.TotalWeight,0) ELSE 0 END AS decimal(12,6)),1,c.IsActive
 FROM portal p JOIN dbo.Tbl_Web_Gacha_Config c ON c.GameType=p.GameType WHERE @admin=1 OR(c.IsActive=1 AND p.IsActive=1 AND p.Weight>0)
 ORDER BY GameType,ParentId,Id;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Games_Prices AS
BEGIN
 SET NOCOUNT ON;
 SELECT GameType,Name,Cost,TenCost,IsActive FROM dbo.Tbl_Web_Gacha_Config
 UNION ALL
 SELECT 'wheel',WheelName,CostCoin,CostCoin,IsActive FROM dbo.Tbl_Web_LuckyWheel_Config WHERE IsActive=1
 UNION ALL
 SELECT 'card',c.EventName,CASE WHEN c.CostType=0 THEN 0 ELSE ISNULL(r.CostAmount,c.CostAmount) END,CASE WHEN c.CostType=0 THEN 0 ELSE ISNULL(r.CostAmount,c.CostAmount) END,c.IsActive
 FROM dbo.Tbl_Web_GiftBox_Config c OUTER APPLY(SELECT TOP 1 CostAmount FROM dbo.Tbl_Web_GiftBox_Round WHERE ConfigId=c.ConfigId ORDER BY RoundNumber) r WHERE c.IsActive=1;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Gacha_Admin_Prizes AS
 SELECT * FROM dbo.Tbl_Web_Gacha_Prizes WHERE GameType IN('chest','box','lotto') ORDER BY GameType,PrizeId;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Gacha_Admin_SavePrize
 @PrizeId int,@GameType nvarchar(20),@Name nvarchar(200),@Tier nvarchar(10),@Weight int,@CashItemId int,@ItemCount int,@XuAmount int,@IsActive bit,@MatchDigits int=0
AS
BEGIN
 SET NOCOUNT ON;
 IF @GameType NOT IN('chest','box','lotto') OR LEN(LTRIM(RTRIM(ISNULL(@Name,''))))=0 OR @Tier NOT IN('c','b','a','s') OR @Weight<0 OR @Weight>1000000 OR @XuAmount<0 OR @ItemCount<1 OR @ItemCount>100 OR @CashItemId<0 OR @MatchDigits NOT BETWEEN 0 AND 3 THROW 50001,N'Cấu hình phần thưởng không hợp lệ.',1;
 IF @GameType<>'lotto' SET @MatchDigits=0;
 IF @PrizeId=0 INSERT dbo.Tbl_Web_Gacha_Prizes(GameType,Name,Tier,Weight,CashItemId,ItemCount,XuAmount,IsActive,MatchDigits) VALUES(@GameType,@Name,@Tier,@Weight,@CashItemId,@ItemCount,@XuAmount,@IsActive,@MatchDigits);
 ELSE BEGIN
  UPDATE dbo.Tbl_Web_Gacha_Prizes SET GameType=@GameType,Name=@Name,Tier=@Tier,Weight=@Weight,CashItemId=@CashItemId,ItemCount=@ItemCount,XuAmount=@XuAmount,IsActive=@IsActive,MatchDigits=@MatchDigits WHERE PrizeId=@PrizeId;
  IF @@ROWCOUNT=0 THROW 50001,N'Phần thưởng không tồn tại.',1;
 END;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Gacha_Admin_DeletePrize @id int AS
 DELETE dbo.Tbl_Web_Gacha_Prizes WHERE PrizeId=@id AND GameType IN('chest','box','lotto');
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_GiftBox_GenerateBoard
 @username nvarchar(60),@configId int,@roundNumber int
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @roundId int,@boxCount int,@advanceMode int;
 SELECT @roundId=RoundId,@boxCount=BoxCount,@advanceMode=AdvanceMode FROM dbo.Tbl_Web_GiftBox_Round WHERE ConfigId=@configId AND RoundNumber=@roundNumber;
 IF @roundId IS NULL OR @boxCount<1 RETURN;
 IF EXISTS(SELECT 1 FROM dbo.Tbl_Web_GiftBox_UserBox WHERE Username=@username AND ConfigId=@configId AND RoundNumber=@roundNumber) RETURN;
 DECLARE @keySum bigint=0,@normalSum bigint=0,@allSum bigint=0;
 SELECT @keySum=SUM(CASE WHEN IsAdvance=1 THEN CAST(Weight AS bigint) ELSE 0 END),@normalSum=SUM(CASE WHEN IsAdvance=0 THEN CAST(Weight AS bigint) ELSE 0 END),@allSum=SUM(CAST(Weight AS bigint)) FROM dbo.Tbl_Web_GiftBox_Gift WHERE RoundId=@roundId AND IsActive=1 AND Weight>0;
 IF ISNULL(@allSum,0)<=0 OR(@advanceMode=0 AND(ISNULL(@keySum,0)<=0 OR(@boxCount>1 AND ISNULL(@normalSum,0)<=0))) RETURN;
 DECLARE @keyPos int=CASE WHEN @advanceMode=0 THEN CAST(CAST(CRYPT_GEN_RANDOM(4) AS bigint)%@boxCount AS int)+1 ELSE 0 END;
 DECLARE @pos int=1,@roll bigint,@sum bigint,@giftId int,@isKey bit;
 WHILE @pos<=@boxCount
 BEGIN
  SET @isKey=CASE WHEN @pos=@keyPos THEN 1 ELSE 0 END;
  SET @sum=CASE WHEN @advanceMode=1 THEN @allSum WHEN @isKey=1 THEN @keySum ELSE @normalSum END;
  SET @roll=(CAST(CRYPT_GEN_RANDOM(8) AS bigint)&CAST(9223372036854775807 AS bigint))%@sum;
  SET @giftId=NULL;
  ;WITH weighted AS(SELECT GiftId,SUM(CAST(Weight AS bigint)) OVER(ORDER BY GiftId ROWS UNBOUNDED PRECEDING) UpperBound FROM dbo.Tbl_Web_GiftBox_Gift WHERE RoundId=@roundId AND IsActive=1 AND Weight>0 AND(@advanceMode=1 OR IsAdvance=@isKey))
  SELECT TOP 1 @giftId=GiftId FROM weighted WHERE UpperBound>@roll ORDER BY UpperBound;
  IF @giftId IS NULL THROW 50001,N'Vòng lật bài chưa có phần thưởng hợp lệ.',1;
  INSERT dbo.Tbl_Web_GiftBox_UserBox(Username,ConfigId,RoundNumber,BoxIndex,GiftId,IsAdvance,IsOpened,CreatedDate) VALUES(@username,@configId,@roundNumber,@pos,@giftId,@isKey,0,GETDATE());
  SET @pos+=1;
 END;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Gacha_Play @username nvarchar(60),@gameType nvarchar(20),@count int,@pick varchar(3),@requestId uniqueidentifier AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @gameType NOT IN('chest','box','lotto') OR @count NOT IN(1,10) OR(@gameType<>'chest' AND @count<>1) OR LEN(@pick)<>3 OR @pick LIKE '%[^0-9]%' THROW 50001,N'Lượt chơi không hợp lệ.',1;
 BEGIN TRY
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
 DECLARE @i int=0,@name nvarchar(250),@xu int,@item int,@qty int,@sum bigint,@roll bigint,@match int,@digits varchar(3),@mismatch char(1),@prefix varchar(3);
 WHILE @i<@count
 BEGIN
  SET @name=NULL;SET @xu=0;SET @item=0;SET @qty=1;SET @match=0;
  SELECT @sum=SUM(CAST(Weight AS bigint)) FROM dbo.Tbl_Web_Gacha_Prizes WITH(HOLDLOCK) WHERE GameType=@gameType AND IsActive=1 AND Weight>0 AND CashItemId>=0 AND XuAmount>=0 AND ItemCount BETWEEN 1 AND 100 AND(@gameType<>'lotto' OR MatchDigits BETWEEN 0 AND 3);
  IF ISNULL(@sum,0)<=0 THROW 50008,N'Trò chơi chưa có phần thưởng hợp lệ.',1;
  SET @roll=(CAST(CRYPT_GEN_RANDOM(8) AS bigint)&CAST(9223372036854775807 AS bigint))%@sum;
  ;WITH weighted AS(SELECT *,SUM(CAST(Weight AS bigint)) OVER(ORDER BY PrizeId ROWS UNBOUNDED PRECEDING) UpperBound FROM dbo.Tbl_Web_Gacha_Prizes WHERE GameType=@gameType AND IsActive=1 AND Weight>0 AND CashItemId>=0 AND XuAmount>=0 AND ItemCount BETWEEN 1 AND 100 AND(@gameType<>'lotto' OR MatchDigits BETWEEN 0 AND 3))
  SELECT TOP 1 @name=Name,@xu=XuAmount,@item=CashItemId,@qty=ItemCount,@match=MatchDigits FROM weighted WHERE UpperBound>@roll ORDER BY UpperBound;
  IF @name IS NULL THROW 50008,N'Không chọn được phần thưởng.',1;
  IF @gameType='lotto'
  BEGIN
   IF @match=3 SET @digits=@pick;
   ELSE BEGIN
    -- The first unmatched digit is chosen from the other nine digits.
    SET @mismatch=CONVERT(char(1),(CONVERT(int,SUBSTRING(@pick,3-@match,1))+1+CAST(CAST(CRYPT_GEN_RANDOM(4) AS bigint)%9 AS int))%10);
    SET @prefix=RIGHT('000'+CONVERT(varchar(3),CAST(CAST(CRYPT_GEN_RANDOM(4) AS bigint)%1000 AS int)),3);
    SET @digits=LEFT(@prefix,2-@match)+@mismatch+RIGHT(@pick,@match);
   END;
   SET @name=N'Số '+@pick+N' · Kết quả '+@digits+N' · '+@name+CASE WHEN @xu>0 THEN N' · '+CONVERT(nvarchar(20),@xu)+N' xu' ELSE N'' END;
  END;
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
 END TRY
 BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK;
  THROW;
 END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE sp_Web_GiftBox_Admin_GetGiftById @giftId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT GiftId, RoundId, GiftName, IconPath, RewardType, CashItemId, CashItemCount,
        CoinAmount, IsAdvance, IsActive, DisplayOrder, Weight, CreatedDate
    FROM Tbl_Web_GiftBox_Gift WHERE GiftId = @giftId;
END
GO
CREATE OR ALTER PROCEDURE sp_Web_GiftBox_Admin_GetGifts @roundId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT GiftId, RoundId, GiftName, IconPath, RewardType, CashItemId, CashItemCount,
        CoinAmount, IsAdvance, IsActive, DisplayOrder, Weight, CreatedDate
    FROM Tbl_Web_GiftBox_Gift
    WHERE RoundId = @roundId
    ORDER BY IsAdvance DESC, DisplayOrder ASC, GiftId ASC;
END
GO
CREATE OR ALTER PROCEDURE sp_Web_GiftBox_Admin_InsertGift
    @roundId INT, @giftName NVARCHAR(150), @iconPath NVARCHAR(300), @rewardType INT,
    @cashItemId INT, @cashItemCount INT, @coinAmount INT, @isAdvance BIT,
    @isActive BIT, @displayOrder INT, @newId INT OUTPUT, @weight INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    IF @weight<0 OR @weight>1000000 THROW 50001,N'Trọng số không hợp lệ.',1;
    -- Mỗi vòng chỉ 1 quà chìa khóa: nếu thêm quà chìa khóa mới, bỏ cờ quà cũ
    IF @isAdvance = 1
        UPDATE Tbl_Web_GiftBox_Gift SET IsAdvance = 0 WHERE RoundId = @roundId AND IsAdvance = 1;

    INSERT INTO Tbl_Web_GiftBox_Gift
        (RoundId, GiftName, IconPath, RewardType, CashItemId, CashItemCount, CoinAmount, IsAdvance, IsActive, DisplayOrder, Weight)
    VALUES
        (@roundId, @giftName, @iconPath, @rewardType, @cashItemId, @cashItemCount, @coinAmount, @isAdvance, @isActive, @displayOrder, @weight);
    SET @newId = SCOPE_IDENTITY();
END
GO
CREATE OR ALTER PROCEDURE sp_Web_GiftBox_Admin_UpdateGift
    @giftId INT, @giftName NVARCHAR(150), @iconPath NVARCHAR(300), @rewardType INT,
    @cashItemId INT, @cashItemCount INT, @coinAmount INT, @isAdvance BIT,
    @isActive BIT, @displayOrder INT, @weight INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    IF @weight<0 OR @weight>1000000 THROW 50001,N'Trọng số không hợp lệ.',1;
    DECLARE @roundId INT;
    SELECT @roundId = RoundId FROM Tbl_Web_GiftBox_Gift WHERE GiftId = @giftId;

    IF @isAdvance = 1 AND @roundId IS NOT NULL
        UPDATE Tbl_Web_GiftBox_Gift SET IsAdvance = 0 WHERE RoundId = @roundId AND IsAdvance = 1 AND GiftId <> @giftId;

    UPDATE Tbl_Web_GiftBox_Gift
    SET GiftName = @giftName, IconPath = @iconPath, RewardType = @rewardType,
        CashItemId = @cashItemId, CashItemCount = @cashItemCount, CoinAmount = @coinAmount,
        IsAdvance = @isAdvance, IsActive = @isActive, DisplayOrder = @displayOrder, Weight = @weight
    WHERE GiftId = @giftId;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Games_Admin_DeleteReward @GameType nvarchar(20),@Id int AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @archived bit=0;
 IF @GameType='wheel'
 BEGIN
  IF EXISTS(SELECT 1 FROM dbo.Tbl_Web_LuckyWheel_SpinLog WHERE PrizeId=@Id)
  BEGIN UPDATE dbo.Tbl_Web_LuckyWheel_Prize SET IsActive=0,Weight=0 WHERE PrizeId=@Id; SET @archived=1; END
  ELSE DELETE dbo.Tbl_Web_LuckyWheel_Prize WHERE PrizeId=@Id;
 END
 ELSE IF @GameType='card'
 BEGIN
  IF EXISTS(SELECT 1 FROM dbo.Tbl_Web_GiftBox_UserBox WHERE GiftId=@Id) OR EXISTS(SELECT 1 FROM dbo.Tbl_Web_GiftBox_OpenLog WHERE GiftId=@Id)
  BEGIN UPDATE dbo.Tbl_Web_GiftBox_Gift SET IsActive=0,Weight=0 WHERE GiftId=@Id;SET @archived=1;END
  ELSE DELETE dbo.Tbl_Web_GiftBox_Gift WHERE GiftId=@Id;
 END
 ELSE IF @GameType IN('chest','box','lotto') DELETE dbo.Tbl_Web_Gacha_Prizes WHERE PrizeId=@Id AND GameType=@GameType;
 ELSE THROW 50001,N'Trò chơi không hợp lệ.',1;
 SELECT @archived;
END;
GO
