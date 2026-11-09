using WebPage.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Localization;
using Microsoft.Extensions.Logging;

namespace WebPage.Areas.Profile.Controllers
{
    [Area("Profile")]
    [Authorize]
    public class ShopController : Controller
    {
        private readonly IGameRepository _gameRepository;
        private readonly IShopDeliveryService _deliveryService;
        private readonly IFeatureService _featureService;
        private readonly ISpendingMilestoneService _spendingMilestoneService;
        private readonly IStringLocalizer<SharedResource> _localizer;
        private readonly ILogger<ShopController> _logger;

        public ShopController(
            IGameRepository gameRepository,
            IShopDeliveryService deliveryService,
            IFeatureService featureService,
            ISpendingMilestoneService spendingMilestoneService,
            IStringLocalizer<SharedResource> localizer,
            ILogger<ShopController> logger)
        {
            _gameRepository = gameRepository;
            _deliveryService = deliveryService;
            _featureService = featureService;
            _spendingMilestoneService = spendingMilestoneService;
            _localizer = localizer;
            _logger = logger;
        }

        // GET: /Profile/Shop
        public async Task<IActionResult> Index(int? categoryId = null, int page = 1)
        {
            if (!_featureService.IsEnabled("Shop"))
                return NotFound();

            if (WebPage.Helper.LegacyGameBrowser.IsMshtml(Request))
                return RedirectToAction("Shop", "InGame", new { area = "", categoryId, page });

            var username = User.Identity?.Name;
            if (string.IsNullOrEmpty(username))
                return RedirectToAction("Login", "Account", new { area = "" });

            var categories = await _gameRepository.GetShopCategoriesAsync();
            var (items, totalCount) = await _gameRepository.GetShopItemsAsync(categoryId, page, 20);
            var balance = await _gameRepository.GetUserBalanceAsync(username);

            ViewBag.Categories = categories;
            ViewBag.Items = items;
            ViewBag.TotalCount = totalCount;
            ViewBag.TotalPages = (int)Math.Ceiling(totalCount / 20.0);
            ViewBag.CurrentPage = page;
            ViewBag.CurrentCategory = categoryId;
            ViewBag.Balance = balance;

            return View();
        }

        // GET: /Profile/Shop/Items (AJAX partial)
        [HttpGet]
        public async Task<IActionResult> Items(int? categoryId = null, int page = 1)
        {
            if (!_featureService.IsEnabled("Shop"))
                return NotFound();

            var (items, totalCount) = await _gameRepository.GetShopItemsAsync(categoryId, page, 20);

            ViewBag.Items = items;
            ViewBag.TotalCount = totalCount;
            ViewBag.TotalPages = (int)Math.Ceiling(totalCount / 20.0);
            ViewBag.CurrentPage = page;
            ViewBag.CurrentCategory = categoryId;

            return PartialView("_ShopItemsPartial");
        }

        // POST: /Profile/Shop/Purchase
        [HttpPost]
        [ValidateAntiForgeryToken]
        [EnableRateLimiting("ShopPurchase")]
        public async Task<IActionResult> Purchase(int itemId, int quantity = 1)
        {
            var username = User.Identity?.Name;
            if (string.IsNullOrEmpty(username))
                return Json(new { success = false, message = "Unauthorized" });

            if (itemId <= 0 || quantity <= 0 || quantity > 99)
                return Json(new { success = false, message = "Invalid parameters" });

            var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

            var result = await _gameRepository.PurchaseShopItemAsync(username, itemId, quantity, ipAddress);

            if (result.ResultCode == 1)
            {
                _logger.LogInformation("Shop purchase: user={User}, itemId={ItemId}, qty={Qty}, purchaseId={PurchaseId}, ip={IP}",
                    username, itemId, quantity, result.PurchaseId, ipAddress);

                // Deliver to CIS_DB cash inventory
                var item = await _gameRepository.GetShopItemByIdAsync(itemId);
                if (item != null)
                {
                    // Get member_guid for delivery
                    var delivered = await _deliveryService.DeliverItemToCashInventoryAsync(
                        username, item.CashItemId, item.CashItemCount * quantity);

                    if (!delivered)
                    {
                        _logger.LogWarning("Cash item delivery failed for purchaseId={PurchaseId}. Manual intervention may be needed.", result.PurchaseId);
                    }
                }

                // Auto-grant spending milestones (no-op if feature disabled)
                await _spendingMilestoneService.ProcessAfterPurchaseAsync(username);

                return Json(new { success = true, message = _localizer["Shop_PurchaseSuccess"].Value, newBalance = result.NewBalance });
            }

            var errorMessage = result.ResultCode switch
            {
                -1 => _localizer["Shop_InsufficientBalance"].Value,
                -2 => _localizer["Shop_DailyLimitReached"].Value,
                -3 => _localizer["Shop_ItemNotAvailable"].Value,
                -5 => "User not found",
                _ => _localizer["Shop_PurchaseFailed"].Value
            };

            return Json(new { success = false, message = errorMessage, newBalance = result.NewBalance });
        }

        // POST: /Profile/Shop/Gift
        [HttpPost]
        [ValidateAntiForgeryToken]
        [EnableRateLimiting("ShopPurchase")]
        public async Task<IActionResult> Gift(int itemId, string recipientUsername)
        {
            var username = User.Identity?.Name;
            if (string.IsNullOrEmpty(username))
                return Json(new { success = false, message = "Unauthorized" });

            if (itemId <= 0 || string.IsNullOrWhiteSpace(recipientUsername))
                return Json(new { success = false, message = "Invalid parameters" });

            recipientUsername = recipientUsername.Trim();

            // Prevent self-gifting
            if (string.Equals(username, recipientUsername, StringComparison.OrdinalIgnoreCase))
                return Json(new { success = false, message = _localizer["Shop_CannotGiftSelf"].Value });

            var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

            var result = await _gameRepository.GiftShopItemAsync(username, itemId, recipientUsername, ipAddress);

            if (result.ResultCode == 1)
            {
                _logger.LogInformation("Shop gift: user={User}, itemId={ItemId}, recipient={Recipient}, purchaseId={PurchaseId}, ip={IP}",
                    username, itemId, recipientUsername, result.PurchaseId, ipAddress);

                // Deliver to recipient's cash inventory
                var item = await _gameRepository.GetShopItemByIdAsync(itemId);
                if (item != null)
                {
                    var delivered = await _deliveryService.DeliverItemToCashInventoryAsync(
                        recipientUsername, item.CashItemId, item.CashItemCount);

                    if (!delivered)
                    {
                        _logger.LogWarning("Gift delivery failed for purchaseId={PurchaseId}. Manual intervention may be needed.", result.PurchaseId);
                    }
                }

                // Auto-grant spending milestones for the buyer (gifts count as spending too)
                await _spendingMilestoneService.ProcessAfterPurchaseAsync(username);

                return Json(new { success = true, message = _localizer["Shop_GiftSuccess"].Value, newBalance = result.NewBalance });
            }

            var errorMessage = result.ResultCode switch
            {
                -1 => _localizer["Shop_InsufficientBalance"].Value,
                -2 => _localizer["Shop_DailyLimitReached"].Value,
                -3 => _localizer["Shop_ItemNotAvailable"].Value,
                -6 => _localizer["Shop_CannotGiftSelf"].Value,
                -7 => _localizer["Shop_RecipientNotFound"].Value,
                _ => _localizer["Shop_PurchaseFailed"].Value
            };

            return Json(new { success = false, message = errorMessage, newBalance = result.NewBalance });
        }

        // GET: /Profile/Shop/PurchaseHistory
        public async Task<IActionResult> PurchaseHistory(int page = 1)
        {
            if (!_featureService.IsEnabled("Shop"))
                return NotFound();

            var username = User.Identity?.Name;
            if (string.IsNullOrEmpty(username))
                return RedirectToAction("Login", "Account", new { area = "" });

            var (items, totalCount) = await _gameRepository.GetShopPurchaseHistoryAsync(username, page, 20);

            ViewBag.Items = items;
            ViewBag.TotalCount = totalCount;
            ViewBag.TotalPages = (int)Math.Ceiling(totalCount / 20.0);
            ViewBag.CurrentPage = page;

            return View();
        }

        // GET: /Profile/Shop/CheckRecipient (AJAX)
        [HttpGet]
        public async Task<IActionResult> CheckRecipient(string username)
        {
            if (string.IsNullOrWhiteSpace(username))
                return Json(new { exists = false });

            var exists = await _gameRepository.CheckUserExistsAsync(username.Trim());
            return Json(new { exists });
        }
    }
}
