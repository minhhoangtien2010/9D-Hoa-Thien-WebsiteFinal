-- Enable a new basic coin-only Lật Thẻ configuration only if no event is active.
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_GiftBox_Config WITH(UPDLOCK,HOLDLOCK) WHERE IsActive=1)
BEGIN
 DECLARE @configId int,@roundId int;
 INSERT dbo.Tbl_Web_GiftBox_Config(EventName,Description,CostType,CostAmount,AllowReplay,IsActive)
 VALUES(N'Lật Bài Tiên Duyên',N'Bộ thưởng xu cơ bản. Quản trị có thể chỉnh sửa giá và phần thưởng.',1,40,1,1);
 SET @configId=SCOPE_IDENTITY();
 INSERT dbo.Tbl_Web_GiftBox_Round(ConfigId,RoundNumber,BoxCount,CostAmount,CostStep,AdvanceMode) VALUES(@configId,1,6,40,0,1);
 SET @roundId=SCOPE_IDENTITY();
 INSERT dbo.Tbl_Web_GiftBox_Gift(RoundId,GiftName,RewardType,CoinAmount,IsAdvance,IsActive,DisplayOrder)
 VALUES(@roundId,N'10 xu',2,10,1,1,1),(@roundId,N'10 xu',2,10,0,1,2),(@roundId,N'10 xu',2,10,0,1,3),(@roundId,N'20 xu',2,20,0,1,4),(@roundId,N'30 xu',2,30,0,1,5),(@roundId,N'100 xu',2,100,0,1,6);
END;
COMMIT;
