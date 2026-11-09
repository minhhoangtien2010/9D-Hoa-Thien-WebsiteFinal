using WebPage.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace WebPage.Areas.Profile.Controllers
{
    [Area("Profile")]
    [Authorize]
    public class SpendingMilestoneController : Controller
    {
        private readonly IGameRepository _gameRepository;
        private readonly IFeatureService _featureService;
        private readonly ISpendingMilestoneService _spendingMilestoneService;
        private readonly ILogger<SpendingMilestoneController> _logger;

        public SpendingMilestoneController(
            IGameRepository gameRepository,
            IFeatureService featureService,
            ISpendingMilestoneService spendingMilestoneService,
            ILogger<SpendingMilestoneController> logger)
        {
            _gameRepository = gameRepository;
            _featureService = featureService;
            _spendingMilestoneService = spendingMilestoneService;
            _logger = logger;
        }

        // GET: /Profile/SpendingMilestone
        public async Task<IActionResult> Index()
        {
            if (!_featureService.IsEnabled("SpendingMilestone"))
                return NotFound();

            var username = User.Identity?.Name;
            if (string.IsNullOrEmpty(username))
                return RedirectToAction("Login", "Account", new { area = "" });

            // Defensive: trigger any pending grants on page load (safety net in case shop hook missed)
            await _spendingMilestoneService.ProcessAfterPurchaseAsync(username);

            var milestones = await _gameRepository.GetActiveSpendingMilestonesAsync();
            var claims = await _gameRepository.GetUserSpendingClaimsAsync(username);

            var now = DateTime.Now;
            var progress = new List<SpendingMilestoneProgressItem>();

            foreach (var m in milestones)
            {
                if (!GameRepository.TryComputePeriod(m, now, out var key, out var rs, out var re))
                    continue;

                if (!m.CountHistoricalPurchases && rs < m.CreatedDate)
                    rs = m.CreatedDate;

                var spent = await _gameRepository.GetUserSpendingInRangeAsync(username, rs, re);
                var existingClaim = claims.FirstOrDefault(c => c.MilestoneID == m.MilestoneID && c.PeriodKey == key);

                progress.Add(new SpendingMilestoneProgressItem
                {
                    Milestone               = m,
                    PeriodKey               = key,
                    PeriodRangeStart        = rs,
                    PeriodRangeEnd          = re,
                    CurrentSpending         = spent,
                    ClaimedInCurrentPeriod  = existingClaim != null,
                    ClaimedDate             = existingClaim?.ClaimedDate,
                    DeliveryStatus          = existingClaim?.DeliveryStatus
                });
            }

            ViewBag.History = claims;
            return View(progress);
        }
    }
}
