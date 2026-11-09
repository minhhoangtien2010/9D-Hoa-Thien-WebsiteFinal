-- Add gender to the existing read-only projections; filters and rank ordering are preserved.
CREATE OR ALTER PROCEDURE dbo.sp_Web_GetTopPlayers @top int=100,@faction int=NULL AS
BEGIN SET NOCOUNT ON;
 SELECT TOP (@top) ROW_NUMBER() OVER(ORDER BY v.inner_level DESC) [Rank],
 v.chr_name CharacterName,v.inner_level [Level],v.party Faction,v.[class] Class,
 v.[name] GuildName,v.captain_name CaptainName,v.sex Gender
 FROM ND_GAME_0.dbo.VIEW_CHARINFO4WEB v WHERE (@faction IS NULL OR v.party=@faction) ORDER BY v.inner_level DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_GetTopOnline @top int=100,@faction int=NULL AS
BEGIN SET NOCOUNT ON;
 SELECT TOP (@top) ROW_NUMBER() OVER(ORDER BY c.play_time DESC) [Rank],c.chr_name CharacterName,c.play_time PlayTime,c.party Faction,c.[class] Class,c.sex Gender
 FROM ND_GAME_0.dbo.ND_V01_Charac c WHERE c.delete_flag=0 AND c.play_time>0 AND (@faction IS NULL OR c.party=@faction) ORDER BY c.play_time DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_GetTopInfamy @top int=100,@faction int=NULL AS
BEGIN SET NOCOUNT ON;
 SELECT TOP (@top) ROW_NUMBER() OVER(ORDER BY s.gong DESC) [Rank],c.chr_name CharacterName,s.gong Gong,c.party Faction,c.[class] Class,c.sex Gender
 FROM ND_GAME_0.dbo.ND_V01_CharacState s JOIN ND_GAME_0.dbo.ND_V01_Charac c ON c.unique_id=s.unique_id WHERE c.delete_flag=0 AND s.gong>0 AND (@faction IS NULL OR c.party=@faction) ORDER BY s.gong DESC;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Web_GetTopHonor @top int=100,@faction int=NULL AS
BEGIN SET NOCOUNT ON;
 SELECT TOP (@top) ROW_NUMBER() OVER(ORDER BY s.honor DESC) [Rank],c.chr_name CharacterName,s.honor Honor,c.party Faction,c.[class] Class,c.sex Gender
 FROM ND_GAME_0.dbo.ND_V01_CharacState s JOIN ND_GAME_0.dbo.ND_V01_Charac c ON c.unique_id=s.unique_id WHERE c.delete_flag=0 AND s.honor>0 AND (@faction IS NULL OR c.party=@faction) ORDER BY s.honor DESC;
END;
GO
