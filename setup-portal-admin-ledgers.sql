CREATE OR ALTER PROCEDURE dbo.sp_Web_Portal_Admin_Bonuses AS SELECT * FROM dbo.Tbl_Web_Deposit_Bonus ORDER BY MinAmount;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Portal_Admin_SaveBonus @BonusId int,@MinAmount decimal(18,0),@BonusPercent int,@MaxBonus decimal(18,0)=NULL,@IsActive bit=1 AS
BEGIN SET NOCOUNT ON;
 IF @MinAmount<10000 OR @BonusPercent<0 OR @BonusPercent>1000 OR @MaxBonus<0 THROW 50001,N'Ưu đãi không hợp lệ.',1;
 IF @BonusId=0 INSERT dbo.Tbl_Web_Deposit_Bonus(MinAmount,BonusPercent,MaxBonus,IsActive) VALUES(@MinAmount,@BonusPercent,@MaxBonus,@IsActive);
 ELSE UPDATE dbo.Tbl_Web_Deposit_Bonus SET MinAmount=@MinAmount,BonusPercent=@BonusPercent,MaxBonus=@MaxBonus,IsActive=@IsActive,UpdatedDate=GETDATE() WHERE BonusId=@BonusId;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Portal_Admin_DeleteBonus @id int AS DELETE dbo.Tbl_Web_Deposit_Bonus WHERE BonusId=@id;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Portal_Admin_Deposits @username nvarchar(60)=NULL,@page int=1 AS
 SELECT id Id,username Username,order_code OrderCode,amount Amount,coins Coins,bonus Bonus,status Status,payment_method PaymentMethod,created_at CreatedDate FROM dbo.Tbl_ND_Web_Transactions WHERE @username IS NULL OR username=@username ORDER BY id DESC OFFSET (@page-1)*30 ROWS FETCH NEXT 30 ROWS ONLY;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Portal_Admin_CheckIns @username nvarchar(60)=NULL,@page int=1 AS
 SELECT * FROM dbo.Web_DailyCheckIn WHERE @username IS NULL OR Username=@username ORDER BY CheckInDate DESC,Id DESC OFFSET (@page-1)*30 ROWS FETCH NEXT 30 ROWS ONLY;
