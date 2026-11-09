-- Enable the requested batch sizes on the currently active wheel.
-- sp_Web_LuckyWheel_Spin already executes the complete batch in one SQL transaction.
-- Coin price, free plays, tickets, daily limit, stock and spending ledger are unchanged.
SET XACT_ABORT ON;
BEGIN TRANSACTION;
UPDATE dbo.Tbl_Web_LuckyWheel_Config
SET MaxSpinsPerRequest=20,UpdatedDate=GETDATE()
WHERE IsActive=1 AND MaxSpinsPerRequest<20;
COMMIT TRANSACTION;
SELECT WheelId,WheelName,MaxSpinsPerRequest,MaxSpinsPerDay,CostCoin,FreeSpinsPerDay
FROM dbo.Tbl_Web_LuckyWheel_Config WHERE IsActive=1;
