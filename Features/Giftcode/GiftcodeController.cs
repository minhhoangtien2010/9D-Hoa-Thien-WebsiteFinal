using System.Text.Json;
using WebPage.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Localization;

namespace WebPage.Areas.Profile.Controllers
{
    [Area("Profile")]
    [Authorize]
    public class GiftcodeController : Controller
    {
        private readonly IGameRepository _gameRepository;
        private readonly IShopDeliveryService _shopDeliveryService;
        private readonly IStringLocalizer<SharedResource> _localizer;
        private readonly ILogger<GiftcodeController> _logger;

        public GiftcodeController(
            IGameRepository gameRepository,
            IShopDeliveryService shopDeliveryService,
            IStringLocalizer<SharedResource> localizer,
            ILogger<GiftcodeController> logger)
        {
            _gameRepository = gameRepository;
            _shopDeliveryService = shopDeliveryService;
            _localizer = localizer;
            _logger = logger;
        }

        // GET: /Profile/Giftcode
        public IActionResult Index()
        {
            return View();
        }

        // POST: /Profile/Giftcode/Redeem
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Redeem(string code)
        {
            var username = User.Identity?.Name;
            if (string.IsNullOrEmpty(username))
                return RedirectToAction("Login", "Account", new { area = "" });

            if (string.IsNullOrWhiteSpace(code))
            {
                TempData["Error"] = _localizer["Giftcode_EmptyCode"].Value;
                return RedirectToAction("Index");
            }

            code = code.Trim().ToUpperInvariant();

            var result = await _gameRepository.RedeemGiftcodeAsync(username, code);

            switch (result.ResultCode)
            {
                case 1:
                    _logger.LogInformation("User {User} redeemed giftcode {Code}: coins={Coins}",
                        username, code, result.RewardCoins);
                    TempData["Success"] = string.Format(_localizer["Giftcode_Success"].Value, result.RewardCoins);
                    if (!string.IsNullOrEmpty(result.RewardItems))
                    {
                        try
                        {
                            var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                            var items = JsonSerializer.Deserialize<List<GiftcodeRewardItem>>(result.RewardItems, options);
                            if (items != null)
                            {
                                foreach (var item in items)
                                {
                                    await _shopDeliveryService.DeliverItemToCashInventoryAsync(username, item.CashItemId, item.Quantity);
                                }
                                _logger.LogInformation("Delivered {Count} giftcode items for user {User}, code {Code}",
                                    items.Count, username, code);
                            }
                        }
                        catch (Exception ex)
                        {
                            _logger.LogError(ex, "Failed to deliver giftcode items for user {User}, code {Code}", username, code);
                        }
                        TempData["RewardItems"] = result.RewardItems;
                    }
                    break;
                case -1:
                    TempData["Error"] = _localizer["Giftcode_NotFound"].Value;
                    break;
                case -2:
                    TempData["Error"] = _localizer["Giftcode_Expired"].Value;
                    break;
                case -3:
                    TempData["Error"] = _localizer["Giftcode_MaxUses"].Value;
                    break;
                case -4:
                    TempData["Error"] = _localizer["Giftcode_AlreadyRedeemed"].Value;
                    break;
                default:
                    TempData["Error"] = _localizer["Giftcode_Failed"].Value;
                    break;
            }

            return RedirectToAction("Index");
        }
    }
}
