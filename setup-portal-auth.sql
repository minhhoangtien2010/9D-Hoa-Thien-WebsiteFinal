-- Website admin membership is independent of game account level.
-- Add/remove an existing account's MemberId in Tbl_Web_SiteAdmins using SQL.
CREATE OR ALTER PROCEDURE dbo.sp_Web_Portal_UserDetails @username nvarchar(60) AS
BEGIN SET NOCOUNT ON;
 SELECT m.member_guid UserID,m.member_id UserName,COALESCE(NULLIF(w.fullname,''),w.character_name,'') FullName,
 ISNULL(w.email,'') Email,ISNULL(w.phone,'') Phone,ISNULL(w.address,'') Address,'' realPwdForOtpUpdate,
 ISNULL(w.account_code,'') AccountCode,ISNULL(w.question,'') Question,ISNULL(w.answer,'') Answer,m.input_date TimeCre,
 CASE WHEN m.member_class>=19 OR EXISTS(SELECT 1 FROM dbo.Tbl_Web_SiteAdmins a WHERE a.MemberId=m.member_id) THEN N'Admin' ELSE N'User' END Role,
 CASE WHEN EXISTS(SELECT 1 FROM dbo.Tbl_Blocking b WHERE b.member_id=m.member_id) THEN CAST(0 AS bit) ELSE CAST(1 AS bit) END IsActive,w.updated_at LastLoginDate
 FROM dbo.Tbl_ND_Member_Login m LEFT JOIN dbo.Tbl_ND_Web_Member w ON w.member_id=m.member_id WHERE m.member_id=@username;
END;
