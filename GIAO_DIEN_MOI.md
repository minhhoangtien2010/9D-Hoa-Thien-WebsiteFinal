# Giao diện theo indexfinal.html

Đã cập nhật trực tiếp dự án ASP.NET Core trong thư mục này. File mẫu `C:\Users\Admin\Downloads\indexfinal.html` được giữ nguyên.

- Dùng đúng banner và ảnh logo lớn được nhúng trong file mẫu. Các ảnh còn lại đã có sẵn và trùng với mẫu.
- Đồng bộ màu xanh ngọc, khung vàng, chữ, nút, thẻ nội dung và bố cục cho các trang dùng layout chung: trang chủ, tin tức/sự kiện, xếp hạng, hướng dẫn, môn phái, tải game, đăng nhập/đăng ký, tài khoản, cửa hàng, phần thưởng và quản trị.
- Dùng chung header và thanh điều hướng điện thoại cho trang công khai và khu tài khoản. Chỉnh menu bị tràn ngang và thanh điều hướng 7 mục bị xuống hai hàng.
- Trang tổng quan tài khoản dùng một menu bên trái; giữ các lối tắt và bảng dữ liệu hiện có.
- Giữ nguyên nguồn nội dung từ model/ViewBag, biểu mẫu, các input, tên trường, token chống giả mạo, mã JavaScript nghiệp vụ và đường dẫn API có sẵn. Không đưa dữ liệu mẫu hay cơ chế lưu tài khoản/giao dịch của file HTML vào dự án.

Các tệp chính:

- `WebGame/wwwroot/css/indexfinal-integration.css`: lớp giao diện chung và phần thích ứng với các trang Razor hiện có.
- `WebGame/wwwroot/js/indexfinal-ui.js`: chỉ đánh dấu mục menu hiện tại, không chặn gửi biểu mẫu hoặc gọi API.
- `WebGame/Views/Shared/_SiteHeader.cshtml`, `_SiteIcons.cshtml`, `_MobileNav.cshtml`: các thành phần giao diện dùng chung.
- Ba layout công khai, đăng nhập và khu tài khoản được nối với giao diện chung.
- Trang chủ và trang tin tức được chỉnh phần trình bày; hai ảnh `hhero.webp`, `lg1.webp` được thay bằng ảnh từ mẫu.

Trong lần chuyển giao diện chung đầu tiên, không thay đổi tệp C#, cấu hình JSON, project, XML dữ liệu hoặc SQL. Báo cáo SHA-256 lần đó ở `..\webchinh-ttv3final-ui-backup-20261108\source-audit.json`. Lần rà soát riêng Ranking/About sau đó có bổ sung action GET để mở view About; xem `RANKING_ABOUT.md` để biết thay đổi mới nhất.

## Chạy tại máy

Mở PowerShell ở thư mục dự án:

```powershell
dotnet run --project WebGame/WebGame.csproj --no-launch-profile --urls http://localhost:5188
```

Sau đó mở `http://localhost:5188`. Khi chạy lại sau các lần sửa, dừng tiến trình đang chạy trước khi build.

## Kiểm tra và giới hạn

Đã build solution, kiểm tra trang chủ, tin tức, xếp hạng, đăng nhập/đăng ký bằng trình duyệt ở kích thước máy tính và điện thoại. Các trang có quyền truy cập tài khoản, cửa hàng, cài đặt và quản trị được render thử bằng các view/layout thật trong một chương trình tách biệt, dùng dữ liệu giả chỉ để kiểm tra bố cục; chương trình đó nằm ngoài dự án. Không thực hiện nạp tiền, mua hàng, quay thưởng thật, đăng ký tài khoản hoặc ghi dữ liệu để kiểm thử.

Lệnh `dotnet build WebGame.sln --no-restore` thành công với 0 lỗi; còn 8 cảnh báo trong phần mã/thư viện có sẵn. Kiểm tra HTTP cuối: 10 trang công khai trả về 200; trang tổng quan tài khoản, cửa hàng và quản trị trả về 302 tới đăng nhập khi chưa xác thực. Các cảnh báo không được sửa trong lần thay giao diện này.

Mã nguồn được cung cấp ban đầu thiếu các action tương ứng `/Home/About`, `/Home/Games`, `/Home/Topup`. Đường dẫn `/Home/About` đã được bổ sung trong lần rà soát riêng Ranking/About và mở được. Hai đường dẫn Games/Topup vẫn giữ nguyên phần xử lý cũ, cần kiểm tra riêng. Có file view/section liên quan không đồng nghĩa controller/API đã được triển khai đầy đủ. Chưa kiểm thử giao dịch thật hoặc tích hợp game từ đầu đến cuối.

## Bản sao lưu và ảnh xem thử

Bản trước khi sửa, báo cáo đối chiếu và ảnh kiểm tra nằm trong:

`C:\Users\Admin\Downloads\webchinh-ttv3final-ui-backup-20261108`

Các ảnh `after-desktop.png`, `after-mobile.png`, `login-mobile.png`, `news-desktop.png`, `ranking-mobile.png` là ảnh chạy cục bộ. Các ảnh có tiền tố `profile-`, `admin-`, `shop-`, `settings-` là bản render tách biệt với dữ liệu thử, không phải dữ liệu tài khoản thật.

Để hoàn tác, dừng ứng dụng và chép lại các tệp cùng đường dẫn tương đối từ thư mục sao lưu vào dự án. Các tệp CSS/JS và partial mới sẽ không còn được nạp sau khi khôi phục ba layout. Chưa publish hoặc thay đổi website đang chạy trên máy chủ.
