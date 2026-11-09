using System.Text;
using System.Text.Json;
using WebPage.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace WebPage.Areas.Profile.Controllers
{
    [Area("Profile")]
    [Authorize]
    public class DepositMilestoneController : Controller
    {
        private static readonly JsonSerializerOptions JsonOpts = new() { PropertyNameCaseInsensitive = true };

        private readonly IGameRepository _gameRepository;
        private readonly IShopDeliveryService _shopDeliveryService;
        private readonly IFeatureService _featureService;
        private readonly ILogger<DepositMilestoneController> _logger;

        public DepositMilestoneController(
            IGameRepository gameRepository,
            IShopDeliveryService shopDeliveryService,
            IFeatureService featureService,
            ILogger<DepositMilestoneController> logger)
        {
            _gameRepository = gameRepository;
            _shopDeliveryService = shopDeliveryService;
            _featureService = featureService;
            _logger = logger;
        }

        // GET: /Profile/DepositMilestone
        public async Task<IActionResult> Index()
        {
            if (!_featureService.IsEnabled("DepositMilestone"))
                return NotFound();

            var username = User.Identity?.Name;
            if (string.IsNullOrEmpty(username))
                return RedirectToAction("Login", "Account", new { area = "" });

            var (milestones, totalDeposited) = await _gameRepository.GetDepositMilestonesAsync(username);
            ViewBag.TotalDeposited = totalDeposited;
            ViewBag.History = await _gameRepository.GetUserDepositClaimsAsync(username);
            ViewBag.SpinTickets = _featureService.IsEnabled("LuckyWheel")
                ? await _gameRepository.GetLuckyWheelTicketsAsync(username)
                : 0;
            return View(milestones);
        }

        // POST: /Profile/DepositMilestone/Claim
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Claim(int milestoneId)
        {
            if (!_featureService.IsEnabled("DepositMilestone"))
                return NotFound();

            var username = User.Identity?.Name;
            if (string.IsNullOrEmpty(username))
                return RedirectToAction("Login", "Account", new { area = "" });

            var result = await _gameRepository.ClaimDepositMilestoneAsync(username, milestoneId);

            switch (result.ResultCode)
            {
                case 1:
                    _logger.LogInformation(
                        "User {User} claimed deposit milestone {MilestoneId} (lần {Index}): coins={Coins}, spins={Spins}",
                        username, milestoneId, result.ClaimIndex, result.RewardCoins, result.RewardSpins);

                    // Vật phẩm in-game: giao sang CIS_DB rồi chốt trạng thái giao hàng.
                    // Claim đã ghi ở DB với DeliveryStatus='Pending' nên nếu giao lỗi,
                    // admin vẫn thấy được và xử lý tay — không mất lặng lẽ như trước.
                    if (!string.IsNullOrWhiteSpace(result.RewardItems))
                        await DeliverRewardItemsAsync(username, milestoneId, result);

                    TempData["Success"] = BuildSuccessMessage(result);
                    break;

                case -1:
                    TempData["Error"] = "Mốc nạp không tồn tại hoặc đã bị tắt.";
                    break;
                case -2:
                    TempData["Error"] = "Bạn đã nhận mốc này trong chu kỳ hiện tại rồi.";
                    break;
                case -3:
                    TempData["Error"] = "Bạn chưa nạp đủ mức yêu cầu của mốc này.";
                    break;
                case -4:
                    TempData["Error"] = "Mốc nạp này hiện không trong thời gian hiệu lực.";
                    break;
                case -5:
                    TempData["Error"] = "Bạn phải nhận các mốc thấp hơn trong chuỗi trước đã.";
                    break;
                default:
                    TempData["Error"] = "Nhận thưởng thất bại, vui lòng thử lại.";
                    break;
            }

            return RedirectToAction("Index");
        }

        /// <summary>
        /// Giao vật phẩm của một claim sang Cash Inventory (CIS_DB) rồi ghi lại
        /// Delivered/Failed + lý do. Cùng pattern 2 giai đoạn với SpendingMilestoneService.
        /// </summary>
        private async Task DeliverRewardItemsAsync(string username, int milestoneId, DepositMilestoneClaimResult result)
        {
            var status = "Delivered";
            string note = null;

            try
            {
                var items = JsonSerializer.Deserialize<List<GiftcodeRewardItem>>(result.RewardItems, JsonOpts);
                if (items == null || items.Count == 0)
                {
                    note = "RewardItems rỗng sau khi parse";
                }
                else
                {
                    var failed = 0;
                    foreach (var item in items)
                    {
                        // DeliverItemToCashInventoryAsync chèn 1 dòng mỗi lần gọi —
                        // lặp theo Quantity giống GiftBoxController.
                        var count = item.Quantity > 0 ? item.Quantity : 1;
                        for (var i = 0; i < count; i++)
                        {
                            if (!await _shopDeliveryService.DeliverItemToCashInventoryAsync(username, item.CashItemId, 1))
                            {
                                failed++;
                                break;
                            }
                        }
                    }

                    if (failed > 0)
                    {
                        status = "Failed";
                        note = $"{failed}/{items.Count} vật phẩm giao thất bại vào Cash Inventory";
                        _logger.LogWarning(
                            "Deposit milestone delivery failed: user={User}, milestone={MilestoneId}, claim={ClaimId}, failed={Failed}/{Total}",
                            username, milestoneId, result.ClaimID, failed, items.Count);
                    }
                    else
                    {
                        _logger.LogInformation(
                            "Delivered {Count} milestone item line(s) for user {User}, milestone {MilestoneId}",
                            items.Count, username, milestoneId);
                    }
                }
            }
            catch (JsonException jex)
            {
                status = "Failed";
                note = "RewardItems JSON không hợp lệ: " + jex.Message;
                _logger.LogError(jex, "Invalid RewardItems JSON on deposit milestone {MilestoneId}", milestoneId);
            }
            catch (Exception ex)
            {
                status = "Failed";
                note = "Lỗi khi giao vật phẩm: " + ex.Message;
                _logger.LogError(ex, "Failed to deliver milestone items for user {User}, milestone {MilestoneId}",
                    username, milestoneId);
            }

            if (result.ClaimID > 0)
                await _gameRepository.UpdateDepositClaimStatusAsync(result.ClaimID, status, note);

            if (status == "Failed")
                TempData["Warning"] = "Phần thưởng vật phẩm chưa gửi được vào tài khoản game. "
                                    + "Ban quản trị đã được ghi nhận và sẽ gửi lại cho bạn.";
        }

        private static string BuildSuccessMessage(DepositMilestoneClaimResult result)
        {
            var sb = new StringBuilder("Nhận thưởng thành công!");
            if (result.RewardCoins > 0) sb.Append($" +{result.RewardCoins:N0} xu.");
            if (result.RewardSpins > 0) sb.Append($" +{result.RewardSpins:N0} lượt Vòng Quay.");
            if (!string.IsNullOrWhiteSpace(result.RewardItems))
                sb.Append(" Vật phẩm đã được gửi vào tài khoản game.");
            return sb.ToString();
        }
    }
}
