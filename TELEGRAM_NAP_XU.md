# Thông báo nạp xu qua Telegram

Trang quản trị: `/Profile/Admin/Telegram`. Chỉ Admin còn hiệu lực trong SQL mới được truy cập. Có thể đổi nơi nhận, bật/tắt, kiểm tra bot, lấy Chat ID sau khi bấm Start, gửi thử, xem lịch sử và yêu cầu gửi lại thông báo lỗi.

`WebPage.Core/setup-telegram-notifications.sql` đã được áp dụng vào database tài khoản hiện có. Bảng `Tbl_Web_Telegram_Settings` lưu cấu hình, `Tbl_Web_Telegram_Outbox` lưu hàng đợi/lịch sử, `Tbl_Web_Telegram_Audit` lưu thao tác quản trị. Thay đổi cấu hình trực tiếp trong SQL được áp dụng trong lượt xử lý tiếp theo, khoảng 15 giây.

Luồng tự động đọc các giao dịch gốc có `payment_method = BankTransfer`, `status = Completed`, đã có số xu và ngày hoàn tất. Chỉ thu thập các đơn hoàn tất sau mốc cài đặt `InstalledAt`; không gửi lại các giao dịch lịch sử. Các đơn cấp xu quản trị, mua Shop và tặng Shop bị loại khỏi thông báo. Không sửa controller thanh toán, các stored procedure thanh toán, tỷ lệ quy đổi, số dư hoặc dữ liệu ngân hàng hiện có.

Mỗi mã giao dịch chỉ có một hàng đợi; SQL khóa lúc nhận việc để nhiều tiến trình không cùng gửi. Telegram trả lỗi rõ ràng tạm thời thì thử lại tối đa 8 lần. Nếu mất kết nối hoặc tiến trình dừng giữa lúc gửi, không thể biết Telegram đã nhận hay chưa: thông báo chuyển sang `Review` để Admin kiểm tra trước khi gửi lại. Telegram không cung cấp khóa chống trùng cho `sendMessage`; không thể đảm bảo đúng một tin nhắn trong mọi tình huống mất kết nối.

Token được mã hóa bằng Windows DPAPI LocalMachine ở `C:\ProgramData\HoaThienPortal\telegram-token.dpapi`, ngoài mã nguồn và ngoài thư mục website. Thư mục chỉ cho tài khoản cài đặt, Administrators và SYSTEM truy cập. Không đặt token vào Razor, JavaScript hoặc bản cấu hình công khai. HttpClient gửi bot tách khỏi các handler ghi URL vì URL Telegram chứa token. Log ứng dụng không ghi URL, nội dung token hoặc exception HTTP.

Khi chuyển sang máy chủ khác, tệp DPAPI không dùng được trên máy mới. Cấu hình biến môi trường `Telegram__BotToken` riêng cho tiến trình website, hoặc tạo lại tệp DPAPI trên chính máy Windows mới và chỉ cấp quyền đọc cho danh tính chạy website (ví dụ IIS Application Pool phù hợp). Có thể chỉ định vị trí tệp qua `Telegram__SecretFile`. Linux dùng biến môi trường riêng. Không sao chép token vào thư mục xuất bản. Chat ID và trạng thái bật/tắt vẫn lấy từ SQL.

Đăng ký dịch vụ tại host (sau `AddCoreServices`):

```csharp
builder.Services.AddScoped<WebPage.Services.TelegramNotificationRepository>();
builder.Services.AddSingleton<WebPage.Services.TelegramSecretStore>();
builder.Services.AddSingleton<WebPage.Services.TelegramBotClient>();
builder.Services.AddHostedService<WebPage.Services.TelegramNotificationWorker>();
```

Tài liệu API chính thức: <https://core.telegram.org/bots/api#sendmessage>. Tính năng này gửi thông báo sau xác nhận thanh toán; tin nhắn Telegram không có quyền tạo giao dịch, duyệt thanh toán hay cộng xu.
