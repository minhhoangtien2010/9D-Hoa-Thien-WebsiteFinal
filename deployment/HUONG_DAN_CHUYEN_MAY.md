# Chuyển website sang Windows khác

Bản `CuuLongHoaThien-Windows-x64-…` đã chứa .NET 8 và ASP.NET Core cho Windows x64. Máy đích không cần cài SDK, không cần Visual Studio và không cần chép `bin/obj` của dự án. Giải nén ra thư mục có quyền ghi, ví dụ `C:\Web\HoaThien`; không chạy trực tiếp bên trong ZIP.

## Các bước

1. Chép ZIP bản phát hành sang máy mới và giải nén. Giữ nguyên `appsettings.json`, `App_Data/uploads` và các file DLL/EXE trong gói. Dữ liệu tài khoản, vật phẩm, cấu hình ngân hàng, bài viết và quyền Admin vẫn dùng SQL hiện tại.
2. Trên máy cũ, lấy khóa trong `C:\ProgramData\HoaThienPortal\migration-key.txt`. Chuyển khóa **bằng kênh riêng** hoặc thiết bị riêng; không để khóa trong ZIP, không đưa lên website/Git và không gửi kèm bản mã. Không chép file `.dpapi` sang máy mới: file này gắn với Windows đã tạo nó.
3. Trên máy mới, mở `NHAP_BI_MAT.cmd`, nhập khóa khi được hỏi. Công cụ giải mã gói AES-256-GCM rồi lưu token Telegram/khóa IPN bằng DPAPI của **máy mới**, trong `C:\ProgramData\HoaThienPortal`. Không hiển thị token. Nếu máy mới đã có cấu hình bí mật, công cụ dừng để tránh ghi đè; chỉ dùng `Import-Secrets.ps1 -Replace` khi chủ động muốn thay.
4. Chạy `KIEM_TRA.cmd`. SQL phải truy cập được; `App_Data/uploads` phải có quyền ghi. Công cụ chỉ mở kết nối SQL và chạy `SELECT 1`, không sửa dữ liệu hay cộng xu.
5. Chạy `CHAY_WEBSITE.cmd`. Website mặc định mở `http://localhost:5188`. Tiến trình chạy nền; xem nhật ký trong `App_Data/logs`. Chạy `DUNG_WEBSITE.cmd` để dừng đúng bản trong thư mục này.

Nếu không cần Telegram/IPN trên máy đích có thể bỏ qua bước nhập bí mật; website vẫn cần các cấu hình và kết nối SQL hiện hữu. Muốn khôi phục đầy đủ luồng tự động nạp, nhập bí mật trước khi đưa máy mới vào sử dụng.

## Kết nối và địa chỉ công khai

- SQL Server cần cho phép kết nối từ IP của máy mới, đúng cổng, đúng quyền database. Firewall hoặc nhà cung cấp SQL có thể giới hạn IP; gói website không thể tự mở firewall của máy SQL từ xa.
- Chạy với cổng khác: `powershell -NoProfile -ExecutionPolicy Bypass -File .\Start-Portal.ps1 -Port 5190`. Truy cập từ mạng LAN: thêm `-ListenAddress 0.0.0.0` và mở đúng cổng Windows Firewall. Chỉ mở mạng khi thực sự cần.
- Với tên miền công khai, cấu hình IIS/reverse proxy và chứng chỉ HTTPS. Nếu đổi tên miền hoặc URL callback, cập nhật URL webhook SePay/cổng thanh toán tại dịch vụ tương ứng. Bot Telegram gửi thông báo ra ngoài bằng HTTPS nên chỉ cần Internet; không cần mở cổng nhận Telegram.
- Đổi ngân hàng tại Admin sẽ cập nhật SQL, QR của đơn mới và thông báo Telegram; trước đó vẫn phải liên kết tài khoản mới tại SePay và kiểm tra bộ lọc tài khoản nhận/webhook ở SePay. Website và bot không thể tự đăng ký tài khoản ngân hàng thay bạn. Đơn đã tạo giữ ngân hàng và nội dung chuyển khoản cũ để đối soát.
- **SePay Checkout:** máy hiện tại chưa có khóa IPN riêng. Muốn dùng Checkout phải thiết lập đúng `X-Secret-Key` tại SePay rồi nhập tại **Admin → Quản trị nạp tự động**. Khóa này khác khóa ký Merchant. Webhook QR chuyển khoản ngân hàng hoạt động độc lập, không yêu cầu khóa IPN Checkout. Bộ đóng gói chỉ chuyển bí mật thực sự đã được cấu hình, không tạo khóa thanh toán giả.
- Không chạy đồng thời nhiều bản để thử nghiệm giao dịch thật. Dừng bản cũ trước khi chuyển hoạt động chính sang máy mới. Thông báo có cơ chế khóa SQL để tránh hai tiến trình nhận cùng một việc, nhưng nên có một bản vận hành chính.

## IIS hoặc tài khoản Windows khác

Nếu chạy bằng IIS/service thay vì tài khoản đã nhập bí mật, cài **ASP.NET Core Hosting Bundle 8** cho IIS, chọn Application Pool `No Managed Code`, rồi cấp quyền đọc/chạy thư mục phát hành. Cấp quyền dữ liệu và bí mật cho đúng tài khoản tiến trình bằng PowerShell quản trị:

```powershell
.\Grant-PortalDataAccess.ps1 -Identity 'IIS AppPool\HoaThien'
```

Lệnh này cấp `Modify` vào `App_Data` và thư mục bí mật cho tài khoản được chỉ định, không cấp cho `Everyone`. Không đưa thư mục bí mật vào thư mục công khai của website. Nếu dùng đường dẫn bí mật tùy chỉnh trong cấu hình, cấp quyền tương ứng tại đường dẫn đó.

## Ảnh và dữ liệu khi cập nhật

Ảnh tải trực tiếp trên Admin nằm trong `App_Data/uploads` và được phục vụ ở `/uploads/…`. Khi thay bản mới phải giữ/copy lại cả thư mục này; SQL chỉ lưu URL, không thay thế file ảnh. Giữ `wwwroot/PATCH` nếu đang phân phối bản vá game và giữ `.well-known` nếu dùng xác minh tên miền/chứng chỉ.

Ảnh cũ của Tin tức, Shop, Lật thẻ và Vòng quay được giữ thêm trong `App_Data/uploads/legacy`, để URL `/images/News/…`, `/images/Shop/…`, `/images/GiftBox/…`, `/images/LuckyWheel/…` tiếp tục chạy sau publish. Công cụ đóng gói cũng đọc `MediaStorage:RootPath` nếu máy cũ dùng kho ảnh khác và đưa ảnh về đường dẫn tương đối `App_Data/uploads` trong gói mới.

## Các mục quản trị thường dùng

Đăng nhập tài khoản website Admin, mở menu tài khoản bên trái:

- **Nạp tự động:** `/Profile/Admin/DepositSettings`. Ô **Hiển thị Nạp xu và thông tin chuyển khoản** bật/tắt toàn bộ phần nạp công khai; bản đang chuẩn bị được đặt **ẩn** theo yêu cầu. Khi ẩn, không tạo đơn mới; giao dịch cũ vẫn được đối soát. Các thông tin tài khoản nhận và thay đổi cấu hình đọc/ghi cùng SQL; bot lấy dữ liệu từ SQL.
- **Telegram:** `/Profile/Admin/Telegram`. Theo dõi kết nối, Chat ID và hàng đợi gửi; thay thông tin ngân hàng ở mục trên thì không cần thay token bot.
- **Trò chơi và phần thưởng:** `/Profile/Admin/GameRewards`. Chọn từng trò chơi để bật/tắt hiển thị, quản lý phần thưởng và trọng số. Trọng số là tỷ lệ tương đối trong tổng các quà đang bật, không phải phần trăm độc lập. Trong biểu mẫu sửa/thêm quà có **Chọn từ Kỳ Trân Các**, tìm theo tên hoặc `CashItemId`, dùng ID vật phẩm SQL và số lượng để giao quà vào game. Có thể nhập ID trực tiếp cho vật phẩm chưa có trong Shop.
- **Nội dung Giới thiệu:** `/Profile/Admin/AboutContent`. Chọn nhóm nội dung, bấm **Tải ảnh lên**, kéo trên ảnh xem trước hoặc dùng các thanh ngang/dọc/thu phóng; chọn **Hiện toàn bộ ảnh** để tránh chân dung bị cắt. Mỗi ảnh nam/nữ có bố trí riêng. Lưu thay đổi sau khi xem trước.
- **Tin tức:** `/Profile/Admin/News`. Tạo/sửa bài, tải ảnh và chỉnh bố trí ảnh trong trình soạn thảo; lưu bài để áp dụng ra trang công khai.

ZIP có cấu hình kết nối SQL vốn có của dự án, vì vậy hãy coi **toàn bộ ZIP là tài liệu riêng tư**. Khóa di chuyển token được giữ tách riêng. Không đăng ZIP, log hoặc `appsettings.json` công khai.

Không thể cam kết mọi máy đều chạy ngay khi hệ điều hành, firewall, IP SQL hoặc tên miền khác nhau. Bản phát hành đã loại bỏ phụ thuộc vào SDK trên máy mới, kiểm tra kết nối trước khi chạy, giữ ảnh đã tải lên và cung cấp cách chuyển token an toàn để xử lý những lỗi thường gặp ngay tại đây.

Tham khảo: [Microsoft — cách phát hành .NET tự chứa runtime](https://learn.microsoft.com/en-us/dotnet/core/deploying/).
