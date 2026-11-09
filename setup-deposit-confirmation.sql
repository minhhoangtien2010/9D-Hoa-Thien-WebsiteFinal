-- Additive serialization around the original financial procedure; do not alter its conversion or bonuses.
CREATE OR ALTER PROCEDURE dbo.sp_Web_Deposit_Confirm
    @transaction_id int,
    @sepay_id int,
    @reference_code nvarchar(100),
    @transfer_amount decimal(18,2),
    @result int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @result=-1;
    IF @transaction_id IS NULL OR @sepay_id IS NULL OR @transfer_amount IS NULL
        OR @transaction_id<=0 OR @sepay_id<=0 OR @transfer_amount<10000 OR @transfer_amount>50000000
        OR @transfer_amount<>FLOOR(@transfer_amount) RETURN;

    DECLARE @ownsTransaction bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
    IF @ownsTransaction=1 BEGIN TRANSACTION;
    ELSE SAVE TRANSACTION WebDepositConfirm;
    BEGIN TRY
        -- One transaction-owned lock protects external payment IDs across different orders.
        -- It also keeps pending-check/update/balance-credit indivisible for all website callbacks.
        DECLARE @lockResult int;
        EXEC @lockResult=sys.sp_getapplock @Resource=N'HoaThien:DepositConfirmation',
            @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=15000;
        IF @lockResult<0 THROW 51310,'Deposit confirmation is busy. Retry the callback.',1;

        IF EXISTS(SELECT 1 FROM dbo.Tbl_ND_Web_Transactions WITH(UPDLOCK,HOLDLOCK)
            WHERE id=@transaction_id AND status='Pending' AND amount=@transfer_amount AND payment_method='BankTransfer')
        BEGIN
            EXEC dbo.sp_Web_CompleteDeposit @transaction_id=@transaction_id,@sepay_id=@sepay_id,
                @reference_code=@reference_code,@transfer_amount=@transfer_amount,@result=@result OUTPUT;
        END;

        IF @ownsTransaction=1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @ownsTransaction=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
        ELSE IF @ownsTransaction=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION WebDepositConfirm;
        THROW;
    END CATCH;
END;
GO
