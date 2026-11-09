using WebPage.Services;
using WebPage.ViewModel;
using Microsoft.AspNetCore.Mvc;

namespace WebPage.Controllers
{
    public class RankingController : Controller
    {
        private readonly IGameRepository _gameRepository;

        public RankingController(IGameRepository gameRepository)
        {
            _gameRepository = gameRepository;
        }

        private static readonly Dictionary<int, string> FactionMap = new()
        {
            { 0, "Lãng Nhân" },
            { 1, "Cái Bang" },
            { 2, "Bí Cung" },
            { 3, "Thiếu Lâm" },
            { 4, "Lục Lâm" },
            { 5, "Võ Đang" },
            { 6, "Ma Giáo" }
        };

        private static readonly Dictionary<int, string> ClassMap = new()
        {
            { 1, "Cận Chiến" },
            { 2, "Hỗ Trợ" },
            { 3, "Hoàn Hảo" },
            { 4, "Khí Công" }
        };

        public async Task<IActionResult> Index(string type = "player", int? faction = null)
        {
            ViewBag.CurrentType = type;
            ViewBag.CurrentFaction = faction;
            ViewBag.FactionMap = FactionMap;

            switch (type)
            {
                case "rich":
                    var richList = await _gameRepository.GetTopRichestAsync(100);
                    ViewBag.Rankings = richList.Select(r => new RankItemViewModel
                    {
                        Rank = r.Rank.ToString(),
                        CharacterName = r.CharacterName,
                        Balance = r.Balance.ToString("N0")
                    }).ToList();
                    break;

                case "online":
                    var onlineList = await _gameRepository.GetTopOnlineAsync(100, faction);
                    ViewBag.Rankings = onlineList.Select(r => new RankItemViewModel
                    {
                        Rank = r.Rank.ToString(),
                        CharacterName = r.CharacterName,
                        Gender = r.Gender,
                        PlayTime = FormatPlayTime(r.PlayTime),
                        Faction = FactionMap.GetValueOrDefault(r.Faction, "Không rõ"),
                        Responsibility = ClassMap.GetValueOrDefault(r.Class, "Không rõ")
                    }).ToList();
                    break;

                case "infamy":
                    var infamyList = await _gameRepository.GetTopInfamyAsync(100, faction);
                    ViewBag.Rankings = infamyList.Select(r => new RankItemViewModel
                    {
                        Rank = r.Rank.ToString(),
                        CharacterName = r.CharacterName,
                        Gender = r.Gender,
                        Gong = r.Gong.ToString("N0"),
                        Faction = FactionMap.GetValueOrDefault(r.Faction, "Không rõ"),
                        Responsibility = ClassMap.GetValueOrDefault(r.Class, "Không rõ")
                    }).ToList();
                    break;

                case "honor":
                    var honorList = await _gameRepository.GetTopHonorAsync(100, faction);
                    ViewBag.Rankings = honorList.Select(r => new RankItemViewModel
                    {
                        Rank = r.Rank.ToString(),
                        CharacterName = r.CharacterName,
                        Gender = r.Gender,
                        Honor = r.Honor.ToString("N0"),
                        Faction = FactionMap.GetValueOrDefault(r.Faction, "Không rõ"),
                        Responsibility = ClassMap.GetValueOrDefault(r.Class, "Không rõ")
                    }).ToList();
                    break;

                default: // "player"
                    var playerList = await _gameRepository.GetTopPlayersAsync(100, faction);
                    ViewBag.Rankings = playerList.Select(r => new RankItemViewModel
                    {
                        Rank = r.Rank.ToString(),
                        CharacterName = r.CharacterName,
                        Gender = r.Gender,
                        Level = r.Level.ToString(),
                        Faction = FactionMap.GetValueOrDefault(r.Faction, "Không rõ"),
                        Responsibility = ClassMap.GetValueOrDefault(r.Class, "Không rõ"),
                        GuildName = r.GuildName ?? ""
                    }).ToList();
                    break;
            }

            return View();
        }

        private static string FormatPlayTime(long totalSeconds)
        {
            var hours = totalSeconds / 3600;
            var minutes = (totalSeconds % 3600) / 60;
            if (hours > 0)
                return $"{hours}h {minutes}m";
            return $"{minutes}m";
        }
    }
}
