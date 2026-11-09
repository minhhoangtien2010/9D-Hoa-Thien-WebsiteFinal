-- Apply setup-news-media.sql before this script on a fresh database.
-- Admin CMS includes drafts. Public News procedures keep their published-only behavior.
CREATE OR ALTER PROCEDURE dbo.sp_Web_Portal_Admin_News @category nvarchar(50)=NULL,@page int=1 AS
BEGIN SET NOCOUNT ON;
 SELECT * FROM dbo.News WHERE @category IS NULL OR Category=@category ORDER BY PublishedDate DESC,NewsID DESC OFFSET (@page-1)*20 ROWS FETCH NEXT 20 ROWS ONLY;
 SELECT COUNT(*) FROM dbo.News WHERE @category IS NULL OR Category=@category;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_Portal_Admin_NewsDetail @id int AS SELECT * FROM dbo.News WHERE NewsID=@id;
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
CREATE OR ALTER PROCEDURE dbo.sp_Web_Portal_Admin_DeleteNews @id int AS DELETE dbo.News WHERE NewsID=@id;
