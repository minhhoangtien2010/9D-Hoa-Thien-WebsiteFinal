-- Apply after setup-about-content.sql. Adds per-image layout without replacing any text or URL.
SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.Tbl_Web_About_Content',N'U') IS NULL THROW 51000,N'Run setup-about-content.sql first.',1;
IF EXISTS(SELECT 1 FROM sys.check_constraints WHERE name=N'CK_AboutContent_Kind')
    ALTER TABLE dbo.Tbl_Web_About_Content DROP CONSTRAINT CK_AboutContent_Kind;
ALTER TABLE dbo.Tbl_Web_About_Content ADD CONSTRAINT CK_AboutContent_Kind
    CHECK(Kind IN('short','multiline','image','url','toggle','image-x','image-y','image-zoom','image-fit'));
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE name=N'CK_AboutContent_ImageLayout')
    ALTER TABLE dbo.Tbl_Web_About_Content ADD CONSTRAINT CK_AboutContent_ImageLayout CHECK
    (Kind NOT IN('image-x','image-y','image-zoom','image-fit')
        OR (Kind IN('image-x','image-y') AND CASE WHEN LEN(Value) BETWEEN 1 AND 3 AND Value NOT LIKE N'%[^0-9]%' THEN CONVERT(int,Value) ELSE -1 END BETWEEN 0 AND 100)
        OR (Kind='image-zoom' AND CASE WHEN LEN(Value) BETWEEN 1 AND 3 AND Value NOT LIKE N'%[^0-9]%' THEN CONVERT(int,Value) ELSE -1 END BETWEEN 50 AND 300)
        OR (Kind='image-fit' AND Value IN(N'contain',N'cover')));
GO
INSERT dbo.Tbl_Web_About_Content(FieldKey,GroupKey,GroupName,Label,Value,DefaultValue,Kind,SortOrder)
SELECT image.FieldKey+optionData.Suffix,image.GroupKey,image.GroupName,image.Label+optionData.Label,
    valueData.InitialValue,valueData.InitialValue,optionData.Kind,image.SortOrder
FROM dbo.Tbl_Web_About_Content image
CROSS JOIN(VALUES(N'.layout.x',N' · Vị trí ngang','image-x',N'50'),
                 (N'.layout.y',N' · Vị trí dọc','image-y',N'50'),
                 (N'.layout.zoom',N' · Kích thước','image-zoom',N'100'),
                 (N'.layout.fit',N' · Cách hiển thị','image-fit',N'cover')) optionData(Suffix,Label,Kind,InitialValue)
CROSS APPLY(SELECT CASE WHEN optionData.Kind='image-fit' AND (image.FieldKey LIKE N'faction.%' OR image.FieldKey=N'story.image')
    THEN N'contain' ELSE optionData.InitialValue END InitialValue) valueData
WHERE image.Kind='image' AND NOT EXISTS(SELECT 1 FROM dbo.Tbl_Web_About_Content existing WHERE existing.FieldKey=image.FieldKey+optionData.Suffix);
GO
SELECT COUNT(*) ImageLayoutFields FROM dbo.Tbl_Web_About_Content WHERE Kind LIKE 'image-%';
GO
IF COL_LENGTH('dbo.Tbl_Web_AboutSections','ImageX') IS NULL ALTER TABLE dbo.Tbl_Web_AboutSections ADD ImageX int NOT NULL CONSTRAINT DF_AboutSections_ImageX DEFAULT(50) WITH VALUES;
IF COL_LENGTH('dbo.Tbl_Web_AboutSections','ImageY') IS NULL ALTER TABLE dbo.Tbl_Web_AboutSections ADD ImageY int NOT NULL CONSTRAINT DF_AboutSections_ImageY DEFAULT(50) WITH VALUES;
IF COL_LENGTH('dbo.Tbl_Web_AboutSections','ImageZoom') IS NULL ALTER TABLE dbo.Tbl_Web_AboutSections ADD ImageZoom int NOT NULL CONSTRAINT DF_AboutSections_ImageZoom DEFAULT(100) WITH VALUES;
IF COL_LENGTH('dbo.Tbl_Web_AboutSections','ImageFit') IS NULL ALTER TABLE dbo.Tbl_Web_AboutSections ADD ImageFit varchar(10) NOT NULL CONSTRAINT DF_AboutSections_ImageFit DEFAULT('contain') WITH VALUES;
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE name=N'CK_AboutSections_ImageLayout')
 ALTER TABLE dbo.Tbl_Web_AboutSections ADD CONSTRAINT CK_AboutSections_ImageLayout CHECK(ImageX BETWEEN 0 AND 100 AND ImageY BETWEEN 0 AND 100 AND ImageZoom BETWEEN 50 AND 300 AND ImageFit IN('cover','contain'));
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_About_List @admin bit=0 AS
BEGIN
 SET NOCOUNT ON;
 SELECT SectionId Id,Eyebrow,Title,Content,ImageUrl,ImagePosition,ButtonText,ButtonUrl,SortOrder,IsPublished,ImageX,ImageY,ImageZoom,ImageFit
 FROM dbo.Tbl_Web_AboutSections WHERE @admin=1 OR IsPublished=1 ORDER BY SortOrder,SectionId;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_About_Admin_Save
 @Id int,@Title nvarchar(250),@Content nvarchar(max),@Eyebrow nvarchar(120),@ImageUrl nvarchar(1000),
 @ImagePosition nvarchar(10),@ButtonText nvarchar(100),@ButtonUrl nvarchar(1000),@SortOrder int,@IsPublished bit,
 @ImageX int=50,@ImageY int=50,@ImageZoom int=100,@ImageFit varchar(10)='contain'
AS
BEGIN
 SET NOCOUNT ON;
 IF @ImageX IS NULL OR @ImageX NOT BETWEEN 0 AND 100 OR @ImageY IS NULL OR @ImageY NOT BETWEEN 0 AND 100
    OR @ImageZoom IS NULL OR @ImageZoom NOT BETWEEN 50 AND 300 OR @ImageFit IS NULL OR @ImageFit NOT IN('cover','contain')
  THROW 51000,N'Thông số bố cục ảnh không hợp lệ.',1;
 IF @Id=0
  INSERT dbo.Tbl_Web_AboutSections(Title,Content,Eyebrow,ImageUrl,ImagePosition,ButtonText,ButtonUrl,SortOrder,IsPublished,ImageX,ImageY,ImageZoom,ImageFit)
  VALUES(@Title,ISNULL(@Content,N''),ISNULL(@Eyebrow,N''),ISNULL(@ImageUrl,N''),@ImagePosition,ISNULL(@ButtonText,N''),ISNULL(@ButtonUrl,N''),@SortOrder,@IsPublished,@ImageX,@ImageY,@ImageZoom,@ImageFit);
 ELSE
  UPDATE dbo.Tbl_Web_AboutSections SET Title=@Title,Content=ISNULL(@Content,N''),Eyebrow=ISNULL(@Eyebrow,N''),ImageUrl=ISNULL(@ImageUrl,N''),
   ImagePosition=@ImagePosition,ButtonText=ISNULL(@ButtonText,N''),ButtonUrl=ISNULL(@ButtonUrl,N''),SortOrder=@SortOrder,IsPublished=@IsPublished,
   ImageX=@ImageX,ImageY=@ImageY,ImageZoom=@ImageZoom,ImageFit=@ImageFit,UpdatedAt=SYSUTCDATETIME() WHERE SectionId=@Id;
END;
GO
