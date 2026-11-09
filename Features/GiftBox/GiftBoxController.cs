using WebPage.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Logging;

namespace WebPage.Areas.Profile.Controllers
{
    [Area("Profile")]
    [Authorize]
    [TypeFilter(typeof(GameVisibilityFilter))]
    public class GiftBoxController : Controller
    {
        private readonly IGameRepository _gameRepository;
        private readonly IShopDeliveryService _deliveryService;
        private readonly IFeatureService _featureService;
        private readonly ISpendingMilestoneService _spendingMilestoneService;
        private readonly ILogger<GiftBoxController> _logger;

        public GiftBoxController(
            IGameRepository gameRepository,
            IShopDeliveryService deliveryService,
            IFeatureService featureService,
            ISpendingMilestoneService spendingMilestoneService,
            ILogger<GiftBoxController> logger)
        {
            _gameRepository = gameRepository;
            _deliveryService = deliveryService;
            _featureService = featureService;
            _spendingMilestoneService = spendingMilestoneService;
            _logger = logger;
        }

        // GET: /Profile/GiftBox
        public async Task<IActionResult> Index()
        {
            if (!_featureService.IsEnabled("GiftBox"))
                return NotFound();

            var username = User.Identity?.Name;
            if (string.IsNullOrEmpty(username))
                return RedirectToAction("Login", "Account", new { area = "" });

            var state = await _gameRepository.GetGiftBoxStateAsync(username);
            return View(state);
        }

        // POST: /Profile/GiftBox/Open
        [HttpPost]
        [ValidateAntiForgeryToken]
        [EnableRateLimiting("GiftBoxOpen")]
        public async Task<IActionResult> Open(int boxIndex)
        {
            if (!_featureService.IsEnabled("GiftBox"))
                return NotFound();

            var username = User.Identity?.Name;
            if (string.IsNullOrEmpty(username))
                return Json(new { success = false, message = "Unauthorized" });

            if (boxIndex <= 0)
                return Json(new { success = false, message = "Hộp không hợp lệ" });

            var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();
            var result = await _gameRepository.OpenGiftBoxAsync(username, boxIndex, ipAddress);

            if (result.ResultCode == 1)
            {
                // Quà vật phẩm in-game → giao vào Cash Inventory (CIS_DB)
                if (result.RewardType == 1 && result.CashItemId > 0)
                {
                    var count = result.CashItemCount > 0 ? result.CashItemCount : 1;
                    for (int i = 0; i < count; i++)
                    {
                        var delivered = await _deliveryService.DeliverItemToCashInventoryAsync(
                            username, result.CashItemId, 1);
                        if (!delivered)
                        {
                            _logger.LogWarning(
                                "GiftBox item delivery failed: user={User}, cashItemId={CashItemId}. Manual intervention may be needed.",
                                username, result.CashItemId);
                            break;
                        }
                    }
                }

                _logger.LogInformation(
                    "GiftBox open: user={User}, box={Box}, gift={Gift}, rewardType={RewardType}, advance={Advance}, ip={IP}",
                    username, boxIndex, result.GiftName, result.RewardType, result.IsAdvance, ipAddress);

                // Tính khoản tiêu Coin của lần mở này vào Mốc Tiêu Xu (no-op nếu feature tắt / không tốn phí)
                await _spendingMilestoneService.ProcessAfterPurchaseAsync(username);

                return Json(new
                {
                    success = true,
                    giftName = result.GiftName,
                    iconPath = result.IconPath,
                    rewardType = result.RewardType,       // 1 = item, 2 = coin
                    cashItemCount = result.CashItemCount,
                    coinAmount = result.CoinAmount,
                    isAdvance = result.IsAdvance,
                    newBalance = result.NewBalance,
                    nextRound = result.NextRound,          // > 0 nếu qua vòng mới
                    isLastRound = result.IsLastRound,      // true nếu vừa hoàn thành vòng cuối
                    replayed = result.Replayed,            // true nếu được chơi lại từ đầu
                    newRoundBoxCount = result.NewRoundBoxCount,
                    nextCost = result.NextCost             // chi phí mở hộp tiếp theo
                });
            }

            var errorMessage = result.ResultCode switch
            {
                -1 => "Bạn không đủ Coin để mở hộp",
                -2 => "Hộp này đã được mở",
                -3 => "Hộp không hợp lệ",
                -5 => "Hiện không có sự kiện mở hộp nào đang diễn ra",
                -6 => "Bạn đã hoàn thành sự kiện này",
                -7 => "Bạn thao tác quá nhanh, vui lòng chờ 3 giây giữa mỗi lần mở",
                _ => "Mở hộp thất bại, vui lòng thử lại"
            };

            return Json(new
            {
                success = false,
                message = errorMessage,
                newBalance = result.NewBalance,
                cooldown = result.ResultCode == -7   // báo client bật lại đồng hồ đếm ngược
            });
        }
    }
}
