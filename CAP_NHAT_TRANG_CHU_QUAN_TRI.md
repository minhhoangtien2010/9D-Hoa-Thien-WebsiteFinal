# Cập nhật Trang chủ, Tiên Duyên Các và quản trị

Đã thay Trang chủ bằng bố cục mới và dùng nguyên banner người dùng gửi, lưu tại `WebGame/wwwroot/images/hoathien/home-banner-hoathien.png`. Hai nút Nạp Xu/Tải Về, khu Tiên Duyên Các, tin tức và xếp hạng được thiết kế lại. Trang chủ ẩn Tài Phú Bảng, bỏ Thần Thú/Tọa Kị, dùng ảnh chân dung lớn cho môn phái. Phần “Con đường lên cấp 200” dùng chung partial và dữ liệu với Giới thiệu.

## Các trang quản trị

Đăng nhập bằng tài khoản Admin website rồi mở `/Profile/Admin`.

| Trang | Chức năng |
| --- | --- |
| `/Profile/Admin/AboutSections` | Tổng quan 265 trường có sẵn trong 16 mục và các khối bài viết bổ sung |
| `/Profile/Admin/AboutContent` | Sửa nội dung, ảnh, nút, ẩn/hiện từng phần của Giới thiệu |
| `/Profile/Admin/AboutContentHistory` | Lịch sử sửa nội dung qua website và SQL |
| `/Profile/Admin/News` | Tin tức, bản nháp, đăng/ẩn và xóa bài |
| `/Profile/Admin/Events` | Quản lý bài thuộc mục Sự kiện |
| `/Profile/Admin/GameRewards` | Phần thưởng cả năm trò: thêm/sửa/xóa, ẩn/hiện, trọng số, tỷ lệ |
| `/Profile/Admin/Gacha` | Giá và bật/tắt Rương, Đập hộp, Xổ số; liên kết cấu hình hai trò gốc |
| `/Profile/Admin/GachaLogs` | Lịch sử cả năm trò và trạng thái giao vật phẩm |
| `/Profile/Admin/Telegram` | Bật/tắt thông báo nạp, nơi nhận, kiểm tra bot và hàng đợi |

Tài khoản `minhadmin2` đã tạo và xác thực đăng nhập thực tế. Quyền là Admin website, không thay thành GM trong game. Mật khẩu giữ theo yêu cầu, không ghi vào tài liệu/mã nguồn.

## Đồng bộ SQL

Giữ các database hiện có. Các migration bổ sung đã áp dụng vào `NineDragons_Account`:

- `WebPage.Core/setup-about-content.sql`
- `WebPage.Core/setup-games-management.sql`
- `WebPage.Core/setup-news-category-visibility.sql`
- `WebPage.Core/setup-telegram-notifications.sql`

Nội dung, phần thưởng và cấu hình được đọc trực tiếp từ SQL. Lần tải/lượt chơi tiếp theo nhận thay đổi mới. Tên 24 chức vị và 17 cảnh giới dùng chung ở Giới thiệu, Trang chủ, Ranking và nhân vật tài khoản. Khoảng cấp và mã nhân vật game được giữ nguyên. Có kiểm tra phiên bản để tránh một form Admin cũ ghi đè dữ liệu vừa sửa trong SQL.

Trọng số là số tương đối: tỷ lệ bằng trọng số chia tổng trọng số đủ điều kiện. Trọng số 0/ẩn/hết kho không được chọn. Lật bài áp dụng tỷ lệ mới khi tạo bàn mới, giữ nguyên những ô đã gán cho bàn đang chơi. Quà đã có trong bàn chơi/lịch sử được lưu trữ bằng cách ẩn khi cần để giữ đối soát. Xổ số được khởi tạo với xác suất và thưởng gốc, sau đó có thể chỉnh trong Admin/SQL.

Hai tab Cộng Đồng/Giới Thiệu trong News chỉ hiện khi mục đó có ít nhất một bài đã xuất bản. Tạo bản nháp không làm hiện tab.

## Nạp xu và Telegram

Luồng SePay/gateway cũ xác nhận và cộng xu được giữ nguyên. Tác vụ nền lấy các giao dịch chuyển khoản mới đã hoàn tất vào hàng đợi SQL và gửi Telegram, khoảng 15 giây mỗi lượt. Không gửi lại các giao dịch trước thời điểm cài đặt. Bot đã kiểm tra thành công và gửi tin thử tới cuộc trò chuyện người dùng vừa bấm Start.

Token mã hóa bằng DPAPI ngoài dự án; không nằm trong HTML/JavaScript. Hướng dẫn chuyển máy chủ, quyền đọc của tiến trình và các trường hợp cần kiểm tra lại thông báo nằm trong `TELEGRAM_NAP_XU.md`. Website cần được chạy để tác vụ nền gửi thông báo.

## Các sửa lỗi đã rà soát lại

- Topup: bỏ cờ bố cục cũ làm ẩn toàn bộ trang mới; thông tin ngân hàng hiện ngay, QR/nội dung riêng của đơn tiếp tục dùng cơ chế cũ.
- Điểm danh: giao diện mới và thông báo thành công nổi bật, kèm xu nhận được.
- Download và menu tài khoản bên phải: đã trang trí; menu quản trị chia nhóm và dùng được trên điện thoại.
- Shop: SQL có 43 đường dẫn PNG thiếu file gốc trong dự án/bản nén. Hệ thống hiển thị ảnh dự phòng ghi rõ “Ảnh minh họa”, không còn biểu tượng ảnh hỏng. Cần bổ sung file gốc để có đúng hình từng vật phẩm.

## Kiểm tra

Build ASP.NET hoàn tất không lỗi. Đã kiểm tra thực tế trên trình duyệt desktop/mobile: ảnh, tràn ngang trang, chọn môn phái và ảnh nam/nữ, hai tab xếp hạng, năm trò chơi thử, thông tin ngân hàng và các trang Admin. Lưu nội dung Giới thiệu bằng form thật, đồng bộ trang công khai, kiểm tra phiên bản cũ và lịch sử đều đạt; nội dung sau thử đã khôi phục. Kiểm tra bot qua chính trang Admin thành công. Đăng xuất thật trên trình duyệt xóa phiên đăng nhập và quay về Trang chủ.

Kiểm tra SQL phần thưởng/xổ số/cộng trừ xu/chống lượt trùng/hàng đợi Telegram dùng transaction rollback. Không thực hiện chuyển khoản thật hoặc phát vật phẩm thật trong đợt kiểm tra này. Tài khoản Admin thử giữ số dư 0.

Bản sao nguồn trước sửa, log kiểm tra và ảnh chụp nằm ngoài dự án tại `C:\Users\Admin\Downloads\webchinh-expansion-backup-20261108`.
