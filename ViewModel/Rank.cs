using WebPage.ConfigurationModels;
using WebPage.Models;
using WebPage.Services;

namespace WebPage.ViewModel
{
    public class RankItemViewModel
    {
        public int? Gender { get; set; }
        public string Rank { get; set; } = string.Empty;
        public string CharacterName { get; set; } = string.Empty;
        public string Level { get; set; } = string.Empty;
        public string Responsibility { get; set; } = string.Empty;
        public string Faction { get; set; } = string.Empty;
        public string GuildName { get; set; } = string.Empty;
        public string PlayTime { get; set; } = string.Empty;
        public string Balance { get; set; } = string.Empty;
        public string Gong { get; set; } = string.Empty;
        public string Honor { get; set; } = string.Empty;
    }

    public class BossSpawnItemViewModel
    {
        public string BossName { get; set; } = string.Empty;
        public int Level { get; set; }
        public string Description { get; set; } = string.Empty;
        public string ImageUrl { get; set; } = string.Empty;
        public List<string> SpawnTimes { get; set; } = new();
    }

    public class BossSpawnMapViewModel
    {
        public string MapName { get; set; } = string.Empty;
        public List<BossSpawnItemViewModel> Bosses { get; set; } = new();
    }

    public class HomePageViewModel
    {
        public List<RankItemViewModel> TopRankings { get; set; } = new();
        public List<RankItemViewModel> TopRichest { get; set; } = new();
        public List<RankItemViewModel> TopOnline { get; set; } = new();
        public List<NewsItem> LatestNews { get; set; } = new();
        public List<NewsItem> LatestEvents { get; set; } = new();
        public List<NewsItem> CommunityPosts { get; set; } = new();
        public List<CharacterClass> Factions { get; set; } = new();
        public ServerStatus ServerStatus { get; set; } = new();

        // Configurable game sections (populated when FeatureFlags are enabled)
        public ServerInfoSettings? ServerInfo { get; set; }
        public WeaponRefiningSettings? WeaponRefining { get; set; }
        public ClothRefiningSettings? ClothRefining { get; set; }
        public MapInfoSettings? MapInfo { get; set; }
        public WeeklyActivitiesSettings? WeeklyActivities { get; set; }
        public DownloadSettings? DownloadConfig { get; set; }
        public SlideShowSettings? SlideShow { get; set; }
        public string? YoutubeVideoUrl { get; set; }

        // Boss spawn timer (populated when FeatureFlags:EnableBossSpawnTimer is true)
        public List<BossSpawnMapViewModel>? BossSpawnMaps { get; set; }

        // Server Info Items (populated when FeatureFlags:EnableServerInfo is true)
        public List<ServerInfoItemPoco> ServerInfoItems { get; set; } = new();
    }
}
