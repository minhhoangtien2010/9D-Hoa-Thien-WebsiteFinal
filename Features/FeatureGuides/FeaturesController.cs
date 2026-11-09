using WebPage.Services;
using Microsoft.AspNetCore.Mvc;

namespace WebPage.Controllers
{
    public class FeaturesController : Controller
    {
        private readonly IGameRepository _gameRepository;

        public FeaturesController(IGameRepository gameRepository)
        {
            _gameRepository = gameRepository;
        }

        // GET /Features — Show all feature categories
        public async Task<IActionResult> Index()
        {
            var categories = await _gameRepository.GetFeatureCategoriesAsync();
            return View(categories);
        }

        // GET /Features/Category/{slug} — Show guides in a category
        public async Task<IActionResult> Category(string slug, int page = 1)
        {
            if (string.IsNullOrEmpty(slug))
                return RedirectToAction("Index");

            var category = await _gameRepository.GetFeatureCategoryBySlugAsync(slug);
            if (category == null)
                return NotFound();

            int pageSize = 12;
            var (items, totalCount) = await _gameRepository.GetFeatureGuidesAsync(category.CategoryID, page, pageSize);

            ViewBag.Category = category;
            ViewBag.CurrentPage = page;
            ViewBag.TotalPages = (int)Math.Ceiling((double)totalCount / pageSize);

            return View(items);
        }

        // GET /Features/Guide/{slug} — Show guide detail
        public async Task<IActionResult> Guide(string slug)
        {
            if (string.IsNullOrEmpty(slug))
                return RedirectToAction("Index");

            var guide = await _gameRepository.GetFeatureGuideBySlugAsync(slug);
            if (guide == null)
                return NotFound();

            // Get other guides in same category for sidebar navigation
            var relatedGuides = await _gameRepository.GetGuidesByCategoryAsync(guide.CategoryID);
            ViewBag.RelatedGuides = relatedGuides;

            return View(guide);
        }
    }
}
