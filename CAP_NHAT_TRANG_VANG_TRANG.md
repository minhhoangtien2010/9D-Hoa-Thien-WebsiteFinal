# Cập nhật giao diện trắng vàng và quản trị

Đã triển khai vào mã nguồn và SQL đang dùng. Đăng nhập Admin website rồi vào `/Profile/Admin`.

| Mục | Đường dẫn và thao tác |
| --- | --- |
| Nạp tự động | `/Profile/Admin/DepositSettings`: ẩn/hiện Nạp xu, tạm dừng đơn mới, ngân hàng/số tài khoản/chủ tài khoản, tiền tố, mẫu QR, lịch sử, thông báo Telegram và gửi kiểm tra. Hiện Nạp xu đang **ẩn**. |
| Trò chơi | `/Profile/Admin/GameRewards`: ẩn/hiện độc lập năm trò, quản lý phần thưởng, trọng số, kho và tỷ lệ. Trò ẩn không nhận lượt chơi qua các đường dẫn website cũ hoặc mới. |
| Ảnh Giới thiệu | `/Profile/Admin/AboutContent`: tải ảnh mới, kéo khung xem trước, chỉnh vị trí, thu/phóng, hiện toàn ảnh, hoàn tác; ảnh nam/nữ độc lập. Chân dung mặc định hiện toàn ảnh. Tổng 265 trường trong 16 nhóm. Khối bổ sung có cùng điều khiển ảnh. |
| Ảnh Tin tức/Sự kiện | `/Profile/Admin/News`, `/Profile/Admin/Events`: sửa ảnh đại diện, căn vị trí/tỷ lệ khung, ảnh trong bài và xem trước bản nháp riêng cho Admin. |
| Vật phẩm dùng chung | Khi thêm/sửa phần thưởng của cả năm trò, chọn từ danh mục Kỳ Trân Các đọc trực tiếp từ SQL; ID/tên/số lượng được điền vào form, sau đó lưu để áp dụng. Có cảnh báo khi nhập ID chưa có trong Shop. |

Các bộ quà cũ có ID vật phẩm chưa xuất hiện trong danh mục Shop hiện tại: vòng quay có 23 dòng vật phẩm, cấu hình lật bài cũ đang đóng có 38 dòng vật phẩm. Giữ nguyên các ID này vì chỉ riêng việc không có trong Shop chưa chứng minh ID trong game bị sai. Quản trị có thể chọn lại từ Shop khi muốn thay quà. Sửa ID của một mặt hàng Shop không tự thay ID các quà đã cấu hình; cần chọn/lưu lại quà tương ứng. Xu, vé và vật phẩm tiếp tục dùng các luồng SQL/CIS vốn có.

Trang chủ có ba nút Đăng Ký – Tải Game – Nạp Xu, Tiên Duyên Các thu gọn và giữ banner chính. Nạp Xu tại bộ ba nút dẫn tới thông báo đang ẩn, không lộ ngân hàng. Các liên kết Nạp xu khác được ẩn theo cấu hình. Menu tài khoản nằm bên trái, kể cả ngăn kéo trên điện thoại. Ranking đổi thành Ác Danh Bảng/Danh Tiếng Bảng và các cột tương ứng; bộ lọc môn phái giữ đúng bảng đang xem.

Giao diện trắng ngà/vàng áp dụng ở Trang chủ, Giới thiệu, News, Ranking, Nạp xu, Tải game, tài khoản, Shop, trò chơi và quản trị. Banner nghệ thuật Thiên Cơ được giữ.

## Ngân hàng và Telegram

Cấu hình nhận tiền, lịch sử và thông báo dùng chung SQL. Khi đổi từ Admin hoặc SQL, QR của đơn mới dùng cấu hình mới và thông báo được xếp hàng gửi bot. Mỗi đơn giữ ảnh chụp cấu hình nhận tiền tại thời điểm tạo; việc ẩn hoặc đổi ngân hàng không bỏ đối soát đơn cũ. Callback xác thực thông tin đơn/ngân hàng/số tiền và được tuần tự hóa qua `sp_Web_Deposit_Confirm` trước khi gọi thủ tục cộng xu cũ, tránh cộng trùng khi hai thông báo đến cùng lúc.

Website không tự liên kết tài khoản ngân hàng tại SePay. Trước khi chuyển sang tài khoản mới, cần liên kết/bật tài khoản đó và cập nhật bộ lọc ngân hàng/số tài khoản của webhook tại SePay. Chỉ hỗ trợ tài khoản ngân hàng thông thường trong màn hình này.

QR chuyển khoản dùng webhook vốn có. Cổng Checkout/IPN riêng chỉ mở khi có đầy đủ cấu hình merchant và khóa **X-Secret-Key** riêng; khóa này hiện chưa thiết lập. Nhập khóa đúng từ SePay trong màn hình quản trị Nạp tự động nếu sử dụng Checkout. Không dùng khóa ký merchant thay khóa IPN.

## Chuyển máy

Dùng bản phát hành Windows x64 tự chứa runtime và làm theo [DONG_GOI_CHUYEN_MAY.md](DONG_GOI_CHUYEN_MAY.md). Ảnh tải lên được lưu ngoài DLL ở `App_Data/uploads` và được đóng gói. Token Telegram/khóa IPN được chuyển bằng gói mã hóa, khóa giải mã mang riêng; máy mới cần bước nhập lại bí mật vì DPAPI gắn với từng máy. SQL vẫn là database hiện tại, không tạo bản dữ liệu tài khoản thứ hai.

Đã build, kiểm tra đăng nhập Admin, upload/lưu/đọc lại ảnh, menu điện thoại, ẩn trò chơi, chặn đơn nạp khi ẩn và callback không xác thực. Kiểm tra SQL đồng thời/nhận lại thông báo đạt; toàn bộ xu thử được rollback. Máy khác vẫn cần được SQL cho phép kết nối và có cấu hình firewall/tên miền/callback phù hợp.
