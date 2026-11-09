USE [NineDragons_Account];
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_News_Categories
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DISTINCT LOWER(LTRIM(RTRIM(Category))) AS Category
    FROM dbo.News
    WHERE IsPublished=1 AND NULLIF(LTRIM(RTRIM(Category)),'') IS NOT NULL;
END;
GO
