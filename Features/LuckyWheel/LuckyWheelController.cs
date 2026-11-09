using WebPage.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace WebPage.Areas.Profile.Controllers
{
    [Area("Profile")]
    [Authorize]
    [TypeFilter(typeof(GameVisibilityFilter))]
    public class LuckyWheelController : Controller
    {
        // Chặn cứng ở tầng web; DB còn chặn lần nữa bằng Config.MaxSpinsPerRequest.
        private const int HardMaxSpinsPerRequest = 20;

        private readonly IGameRepository _gameRepository;
        private readonly IShopDeliveryService _deliveryService;
        private readonly IFeatureService _featureService;
        private readonly ISpendingMilestoneService _spendingMilestoneService;
        private readonly ILogger<LuckyWheelController> _logger;

        public LuckyWheelController(
            IGameRepository gameRepository,
            IShopDeliveryService deliveryService,
            IFeatureService featureService,
            ISpendingMilestoneService spendingMilestoneService,
            ILogger<LuckyWheelController> logger)
        {
            _gameRepository = gameRepository;
            _deliveryService = deliveryService;
            _featureService = featureService;
            _spendingMilestoneService = spendingMilestoneService;
            _logger = logger;
        }

        // GET: /Profile/LuckyWheel
        public async Task<IActionResult> Index()
        {
            if (!_featureService.IsEnabled("LuckyWheel"))
                return NotFound();

            var username = User.Identity?.Name;
            if (string.IsNullOrEmpty(username))
                return RedirectToAction("Login", "Account", new { area = "" });

            var state = await _gameRepository.GetLuckyWheelStateAsync(username);
            return View(state);
        }

        // POST: /Profile/LuckyWheel/Spin
        [HttpPost]
        [ValidateAntiForgeryToken]
        [EnableRateLimiting("LuckyWheelSpin")]
        public async Task<IActionResult> Spin(int spinCount = 1)
        {
            if (!_featureService.IsEnabled("LuckyWheel"))
                return NotFound();

            var username = User.Identity?.Name;
            if (string.IsNullOrEmpty(username))
                return Json(new { success = false, message = "Unauthorized" });

            if (spinCount < 1 || spinCount > HardMaxSpinsPerRequest)
                return BadRequest(new { success = false, message = "Mỗi lần quay từ 1 đến 20 lượt." });

            var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();
            var result = await _gameRepository.SpinLuckyWheelAsync(username, spinCount, ipAddress);

            if (result.ResultCode != 1 || result.SpinsDone == 0)
            {
                var errorMessage = result.ResultCode switch
                {
                    -1  => "Bạn không còn lượt quay và không đủ Coin",
                    -5  => "Hiện không có vòng quay nào đang diễn ra",
                    -6  => "Bạn đã dùng hết số lượt quay trong ngày hôm nay",
                    -7  => "Bạn thao tác quá nhanh, vui lòng chờ một chút",
                    -8  => "Vòng quay chưa được cấu hình phần thưởng",
                    _   => "Quay thất bại, vui lòng thử lại"
                };

                return Json(new
                {
                    success = false,
                    message = errorMessage,
                    newBalance = result.NewBalance,
                    newTickets = result.NewTickets,
                    freeRemaining = result.FreeRemaining,
                    dayRemaining = result.DayRemaining,
                    cooldown = result.ResultCode == -7
                });
            }

            // Vật phẩm in-game → giao vào Cash Inventory (CIS_DB).
            // Coin / vé quay đã được SP cộng trong cùng transaction.
            var deliveryFailed = false;
            foreach (var spin in result.Spins)
            {
                if (spin.RewardType != LuckyWheelRewardType.Item || spin.CashItemId <= 0)
                    continue;

                var count = spin.CashItemCount > 0 ? spin.CashItemCount : 1;
                for (var i = 0; i < count; i++)
                {
                    if (!await _deliveryService.DeliverItemToCashInventoryAsync(username, spin.CashItemId, 1))
                    {
                        deliveryFailed = true;
                        _logger.LogWarning(
                            "LuckyWheel item delivery failed: user={User}, prize={PrizeId}, cashItemId={CashItemId}. Manual intervention may be needed.",
                            username, spin.PrizeId, spin.CashItemId);
                        break;
                    }
                }
            }

            _logger.LogInformation(
                "LuckyWheel spin: user={User}, requested={Requested}, done={Done}, prizes={Prizes}, ip={IP}",
                username, spinCount, result.SpinsDone,
                string.Join(",", result.Spins.Select(s => s.PrizeId)), ipAddress);

            // Lượt trừ Coin đã được ghi vào Tbl_Web_Shop_Purchases trong SP →
            // đánh thức Mốc tiêu phí (no-op nếu feature tắt / lượt quay không tốn Coin).
            await _spendingMilestoneService.ProcessAfterPurchaseAsync(username);

            return Json(new
            {
                success = true,
                spinsDone = result.SpinsDone,
                newBalance = result.NewBalance,
                newTickets = result.NewTickets,
                freeRemaining = result.FreeRemaining,
                dayRemaining = result.DayRemaining,
                deliveryWarning = deliveryFailed
                    ? "Một số vật phẩm chưa gửi được vào tài khoản game, ban quản trị sẽ xử lý."
                    : null,
                spins = result.Spins.Select(s => new
                {
                    prizeId = s.PrizeId,
                    prizeName = s.PrizeName,
                    iconPath = s.IconPath,
                    rewardType = s.RewardType,     // 1=item, 2=coin, 3=vé, 4=chúc may mắn
                    cashItemCount = s.CashItemCount,
                    coinAmount = s.CoinAmount,
                    spinAmount = s.SpinAmount,
                    costType = s.CostType,         // 0=free, 1=vé, 2=coin
                    costAmount = s.CostAmount,
                    isJackpot = s.IsJackpot
                })
            });
        }
    }
}
