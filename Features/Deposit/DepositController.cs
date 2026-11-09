using System.Globalization;
using System.Text.Json;
using WebPage.ConfigurationModels;
using WebPage.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Localization;
using Microsoft.Extensions.Options;

namespace WebPage.Areas.Profile.Controllers;

[Area("Profile"), Authorize]
public class DepositController(IOptions<SePaySettings> payment, IGameRepository game,
    SePayGatewayService gateway, IStringLocalizer<SharedResource> localizer,
    ILogger<DepositController> logger, DepositCheckoutService checkout,
    DepositSettingsRepository receivers, DepositIpnSecretStore ipnSecrets, DepositConfirmationRepository confirmations) : Controller
{
    public async Task<IActionResult> Index()
    {
        var receiver = await receivers.GetCurrentAsync();
        if (!receiver.IsVisible) return RedirectToAction("Topup", "Home", new { area = "" });
        ViewBag.EnableGateway = receiver.EnableGateway && checkout.GatewayReady;
        ViewBag.DepositEnabled = receiver.IsEnabled;
        ViewBag.BonusTiers = await game.GetActiveBonusTiersAsync();
        return View();
    }
    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> CreatePayment(decimal amount)
    {
        try
        {
            var order = await checkout.CreateAsync(User.Identity!.Name!, amount);
            ViewBag.ShowQR = true; ViewBag.QrUrl = order.QrUrl; ViewBag.Amount = order.Amount;
            ViewBag.OrderCode = order.OrderCode; ViewBag.TransferContent = order.OrderCode;
            ViewBag.TransactionId = order.TransactionId; ViewBag.BankName = order.Receiver.BankName;
            ViewBag.AccountNumber = order.Receiver.AccountNumber; ViewBag.AccountName = order.Receiver.AccountName;
            return View("Index");
        }
        catch (DepositRequestException e) { TempData["Error"] = e.Message; return RedirectToAction(nameof(Index)); }
    }
    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> CreateDepositJson(decimal amount)
    {
        try
        {
            var order = await checkout.CreateAsync(User.Identity!.Name!, amount);
            return Json(new { success = true, order.TransactionId, order.QrUrl, order.Amount, order.OrderCode,
                order.Receiver.BankName, order.Receiver.AccountNumber, order.Receiver.AccountName });
        }
        catch (DepositRequestException e) { return Json(new { success = false, message = e.Message }); }
    }
    [AllowAnonymous, IgnoreAntiforgeryToken, HttpPost]
    public async Task<IActionResult> SePayWebhook()
    {
        var auth = Request.Headers.Authorization.ToString();
        if (!auth.StartsWith("Apikey ", StringComparison.OrdinalIgnoreCase)
            || !DepositCheckoutService.SecretMatches(payment.Value.ApiKey, auth["Apikey ".Length..].Trim()))
            return Unauthorized(new { success = false, message = "Unauthorized" });
        try
        {
            var payload = await JsonSerializer.DeserializeAsync<SePayWebhookPayload>(Request.Body,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true }, HttpContext.RequestAborted);
            if (payload is null) return BadRequest(new { success = false, message = "Invalid payload" });
            if (!string.Equals(payload.TransferType, "in", StringComparison.OrdinalIgnoreCase)) return Ok(new { success = true });
            var order = await checkout.FindOrderAsync(payload.Content);
            if (order is null || order.IsGateway || payload.Id <= 0 || !DepositCheckoutService.ValidAmount(payload.TransferAmount)
                || payload.TransferAmount != order.Amount || !DepositCheckoutService.MatchesReceiver(order, payload.Gateway, payload.AccountNumber))
            {
                logger.LogWarning("SePay incoming transfer did not match a saved deposit receiver/order.");
                return Ok(new { success = true });
            }
            var result = await confirmations.ConfirmAsync(order.TransactionId, payload.Id, payload.ReferenceCode ?? "", payload.TransferAmount);
            logger.LogInformation("SePay deposit {Id} processed with result {Result}", order.TransactionId, result);
            return Ok(new { success = true });
        }
        catch (JsonException) { return BadRequest(new { success = false, message = "Invalid payload" }); }
        catch (Exception e) { logger.LogError(e, "SePay deposit processing failed"); return StatusCode(500, new { success = false, message = "Internal error" }); }
    }
    [AllowAnonymous, HttpGet]
    public async Task<IActionResult> CheckPaymentStatus(int id)
    {
        var status = id > 0 ? await game.GetTransactionStatusAsync(id) : null;
        return status is null ? Json(new { paid = false }) : Json(new { paid = status.Status == "Completed", status = status.Status, amount = status.Amount });
    }
    [HttpPost, ValidateAntiForgeryToken]
    public async Task<IActionResult> CreateGatewayPayment(decimal amount)
    {
        try
        {
            var order = await checkout.CreateAsync(User.Identity!.Name!, amount, true);
            var baseUrl = $"{Request.Scheme}://{Request.Host}";
            ViewBag.CheckoutForm = gateway.BuildCheckoutForm(amount, order.OrderCode, order.OrderCode, User.Identity!.Name!,
                $"{baseUrl}/Profile/Deposit/GatewaySuccess?id={order.TransactionId}",
                $"{baseUrl}/Profile/Deposit/GatewayError?id={order.TransactionId}",
                $"{baseUrl}/Profile/Deposit/GatewayCancel?id={order.TransactionId}");
            return View("GatewayRedirect");
        }
        catch (DepositRequestException e) { TempData["Error"] = e.Message; return RedirectToAction(nameof(Index)); }
    }
    public async Task<IActionResult> GatewaySuccess(int id)
    {
        var status = await game.GetTransactionStatusAsync(id);
        ViewBag.Success = status?.Status == "Completed";
        ViewBag.Message = status?.Status == "Completed" ? localizer["Deposit_SuccessMessage"].Value : "Đang chờ SePay xác nhận thanh toán. Bạn có thể kiểm tra lại số dư trong tài khoản.";
        ViewBag.Amount = status?.Amount ?? 0;
        ViewBag.TransactionNo = (await receivers.GetOrderAsync(id))?.OrderCode ?? $"#{id}";
        ViewBag.TransactionId = id;
        return View("Result");
    }
    public IActionResult GatewayError(int id) => GatewayResult(id, "Deposit_FailedMessage");
    public IActionResult GatewayCancel(int id) => GatewayResult(id, "Deposit_CancelledMessage");
    private IActionResult GatewayResult(int id, string message)
    {
        ViewBag.Success = false; ViewBag.Message = localizer[message].Value; ViewBag.TransactionNo = $"#{id}";
        return View("Result");
    }
    [AllowAnonymous, IgnoreAntiforgeryToken, HttpPost]
    public async Task<IActionResult> GatewayIpn()
    {
        // The dedicated IPN key is independent of the merchant signing key.
        if (!payment.Value.EnableGateway || !DepositCheckoutService.SecretMatches(ipnSecrets.Read(), Request.Headers["X-Secret-Key"].ToString()))
            return Unauthorized(new { success = false, message = "Unauthorized" });
        try
        {
            var payload = await JsonSerializer.DeserializeAsync<SePayGatewayIpnPayload>(Request.Body, cancellationToken: HttpContext.RequestAborted);
            if (payload?.Order is null || payload.Transaction is null) return BadRequest(new { success = false, message = "Invalid payload" });
            if (payload.NotificationType != "ORDER_PAID" || payload.Order.OrderStatus != "CAPTURED" || payload.Transaction.TransactionStatus != "APPROVED") return Ok(new { success = true });
            var order = await checkout.FindOrderAsync(payload.Order.OrderInvoiceNumber, true);
            if (order is null || !order.IsGateway || string.IsNullOrWhiteSpace(payload.Transaction.TransactionId)
                || payload.Transaction.TransactionId.Length > 200
                || !decimal.TryParse(payload.Transaction.TransactionAmount, NumberStyles.Number, CultureInfo.InvariantCulture, out var amount)
                || !DepositCheckoutService.ValidAmount(amount) || amount != order.Amount
                || !string.Equals(payload.Order.OrderCurrency, "VND", StringComparison.OrdinalIgnoreCase)
                || !string.Equals(payload.Transaction.TransactionCurrency, "VND", StringComparison.OrdinalIgnoreCase))
                return BadRequest(new { success = false, message = "Order mismatch" });
            var result = await confirmations.ConfirmAsync(order.TransactionId, DepositCheckoutService.GatewayTransactionKey(payload.Transaction.TransactionId), payload.Transaction.TransactionId, amount);
            logger.LogInformation("SePay gateway deposit {Id} processed with result {Result}", order.TransactionId, result);
            return Ok(new { success = true });
        }
        catch (JsonException) { return BadRequest(new { success = false, message = "Invalid payload" }); }
        catch (Exception e) { logger.LogError(e, "SePay gateway processing failed"); return StatusCode(500, new { success = false, message = "Internal error" }); }
    }
}
public class SePayWebhookPayload
{
    public int Id { get; set; }
    public string Gateway { get; set; } = "";
    public string TransactionDate { get; set; } = "";
    public string AccountNumber { get; set; } = "";
    public string? Code { get; set; }
    public string Content { get; set; } = "";
    public string TransferType { get; set; } = "";
    public decimal TransferAmount { get; set; }
    public decimal Accumulated { get; set; }
    public string? SubAccount { get; set; }
    public string ReferenceCode { get; set; } = "";
    public string? Description { get; set; }
}
