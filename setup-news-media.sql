-- Persist article image layout with the article in NineDragons_Account.
-- Existing articles retain their previous wide cover and top-biased crop.
IF COL_LENGTH('dbo.News','ThumbnailFit') IS NULL
    ALTER TABLE dbo.News ADD ThumbnailFit varchar(10) NOT NULL CONSTRAINT DF_News_ThumbnailFit DEFAULT('cover') WITH VALUES;
IF COL_LENGTH('dbo.News','ThumbnailPositionX') IS NULL
    ALTER TABLE dbo.News ADD ThumbnailPositionX int NOT NULL CONSTRAINT DF_News_ThumbnailPositionX DEFAULT(50) WITH VALUES;
IF COL_LENGTH('dbo.News','ThumbnailPositionY') IS NULL
    ALTER TABLE dbo.News ADD ThumbnailPositionY int NOT NULL CONSTRAINT DF_News_ThumbnailPositionY DEFAULT(20) WITH VALUES;
IF COL_LENGTH('dbo.News','ThumbnailAspect') IS NULL
    ALTER TABLE dbo.News ADD ThumbnailAspect varchar(15) NOT NULL CONSTRAINT DF_News_ThumbnailAspect DEFAULT('wide') WITH VALUES;
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE name='CK_News_MediaLayout')
    ALTER TABLE dbo.News ADD CONSTRAINT CK_News_MediaLayout CHECK
    (ThumbnailFit IN('cover','contain') AND ThumbnailPositionX BETWEEN 0 AND 100 AND ThumbnailPositionY BETWEEN 0 AND 100
        AND ThumbnailAspect IN('wide','standard','square','portrait','original'));
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Portal_Admin_SaveNews
    @NewsID int,@Title nvarchar(500),@Excerpt nvarchar(1000)=NULL,@Content nvarchar(max)=NULL,
    @Category nvarchar(50)='news',@ThumbnailUrl nvarchar(500)=NULL,@AuthorName nvarchar(100)=NULL,
    @IsPublished bit=1,@IsFeatured bit=0,@ThumbnailFit varchar(10)='cover',
    @ThumbnailPositionX int=50,@ThumbnailPositionY int=20,@ThumbnailAspect varchar(15)='wide'
AS
BEGIN
    SET NOCOUNT ON;
    IF @ThumbnailFit IS NULL OR @ThumbnailFit NOT IN('cover','contain') OR @ThumbnailPositionX IS NULL
       OR @ThumbnailPositionX NOT BETWEEN 0 AND 100 OR @ThumbnailPositionY IS NULL OR @ThumbnailPositionY NOT BETWEEN 0 AND 100
       OR @ThumbnailAspect IS NULL OR @ThumbnailAspect NOT IN('wide','standard','square','portrait','original')
        THROW 51000,N'Thông số bố cục ảnh không hợp lệ.',1;
    IF @NewsID=0
        INSERT dbo.News(Title,Excerpt,Content,Category,ThumbnailUrl,AuthorName,IsPublished,IsFeatured,
                       ThumbnailFit,ThumbnailPositionX,ThumbnailPositionY,ThumbnailAspect)
        VALUES(@Title,@Excerpt,@Content,@Category,@ThumbnailUrl,@AuthorName,@IsPublished,@IsFeatured,
               @ThumbnailFit,@ThumbnailPositionX,@ThumbnailPositionY,@ThumbnailAspect);
    ELSE
        UPDATE dbo.News SET Title=@Title,Excerpt=@Excerpt,Content=@Content,Category=@Category,ThumbnailUrl=@ThumbnailUrl,
            IsPublished=@IsPublished,IsFeatured=@IsFeatured,UpdatedDate=GETDATE(),ThumbnailFit=@ThumbnailFit,
            ThumbnailPositionX=@ThumbnailPositionX,ThumbnailPositionY=@ThumbnailPositionY,ThumbnailAspect=@ThumbnailAspect
        WHERE NewsID=@NewsID;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_GetLatestNews @category nvarchar(50)=NULL,@top int=6
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP(@top) NewsID,Title,Excerpt,Category,ThumbnailUrl,AuthorName,PublishedDate,ViewCount,IsFeatured,
        ThumbnailFit,ThumbnailPositionX,ThumbnailPositionY,ThumbnailAspect
    FROM dbo.News WHERE IsPublished=1 AND (@category IS NULL OR Category=@category)
    ORDER BY IsFeatured DESC,PublishedDate DESC,NewsID DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_GetNewsList
    @category nvarchar(50)=NULL,@page int=1,@pageSize int=12,@totalCount int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @totalCount=COUNT(*) FROM dbo.News WHERE IsPublished=1 AND (@category IS NULL OR Category=@category);
    SELECT NewsID,Title,Excerpt,Category,ThumbnailUrl,AuthorName,PublishedDate,ViewCount,IsFeatured,
        ThumbnailFit,ThumbnailPositionX,ThumbnailPositionY,ThumbnailAspect
    FROM dbo.News WHERE IsPublished=1 AND (@category IS NULL OR Category=@category)
    ORDER BY PublishedDate DESC,NewsID DESC
    OFFSET ((@page-1)*@pageSize) ROWS FETCH NEXT @pageSize ROWS ONLY;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_GetNewsDetail @newsId int
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.News SET ViewCount=ViewCount+1 WHERE NewsID=@newsId AND IsPublished=1;
    SELECT NewsID,Title,Excerpt,Content,Category,ThumbnailUrl,AuthorName,PublishedDate,UpdatedDate,ViewCount,IsFeatured,
        IsPublished,ThumbnailFit,ThumbnailPositionX,ThumbnailPositionY,ThumbnailAspect
    FROM dbo.News WHERE NewsID=@newsId AND IsPublished=1;
END;
GO
