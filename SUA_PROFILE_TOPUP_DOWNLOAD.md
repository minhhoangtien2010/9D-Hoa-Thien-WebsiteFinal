# Cập nhật tài khoản, điểm danh, nạp xu và tải game

## Tài khoản quản trị

Đã tạo tài khoản `minhadmin2` bằng luồng đăng ký SQL gốc, kiểm tra mật khẩu qua luồng đăng nhập gốc và đăng nhập website thành công. Mật khẩu dùng đúng thông tin người dùng cung cấp, không ghi vào mã nguồn hoặc tài liệu này.

Quyền quản trị website lưu trong `dbo.Tbl_Web_SiteAdmins`. Mã tài khoản ở `Tbl_ND_Web_Member` đã đồng bộ với mã thực trong `Tbl_ND_Member_Login`. Tài khoản này không được cấp quyền GM trong game.

## Những thay đổi

- **Profile/DailyCheckIn**: thẻ thưởng và chuỗi ngày rõ hơn, làm nổi bật ngày đang chờ nhận. Sau khi nhận thành công có biên nhận lớn với dấu kiểm, số xu cộng, số dư và chuỗi ngày. Chống bấm lặp ở giao diện và tiếp tục dùng kiểm tra ngày/khóa ví ở SQL.
- **Home/Topup**: lỗi trống trang do cờ `IsTopupPage` kích hoạt CSS cũ, ẩn mọi nội dung mới bên ngoài `#topup`. Đã bỏ cờ dành cho bố cục cũ ở action của trang nạp riêng. Thông tin ngân hàng hiện ngay sau khi đăng nhập; nội dung chuyển khoản chỉ lấy từ đơn do handler nạp gốc tạo. Thêm nút sao chép số tài khoản/nội dung và hướng dẫn khi ảnh QR chưa tải được.
- **Profile/Shop**: SQL đang tham chiếu 43 ảnh PNG không có trong dự án và bản nén gốc; thư mục Shop hiện có 3 ảnh GIF khác. Ảnh thiếu được hiển thị bằng ảnh dự phòng có nhãn “Ảnh minh họa”. Không thay giá, vật phẩm, CashItemId hoặc đường dẫn gốc trong SQL. Khi có lại file hoặc cập nhật ảnh trong Admin, ảnh thật được dùng tự động. Bộ xử lý hỗ trợ cả tệp vật lý và tài nguyên nhúng trong bản publish. Ảnh trong trang phân trang AJAX, hộp thoại mua/tặng và màn hình quản trị cũng dùng cùng cách xử lý.
- **Home/Download**: bổ sung banner, thẻ nguồn tải, cấu hình thiết bị và ba bước cài đặt theo phong cách Hỏa Thiên. Các liên kết và cấu hình tải hiện có được giữ nguyên.
- **Menu tài khoản**: đặt ở cột phải trên máy tính, chia nhóm tài khoản/hoạt động/quản trị. Các nhóm quản trị có thể thu gọn. Trên điện thoại menu mở từ cạnh phải, có lớp nền, nút đóng và hỗ trợ phím Escape.

## Kiểm tra

- Build Razor/.NET thành công.
- Đăng nhập tài khoản mới và xác minh quyền Admin qua website thực.
- Kiểm tra các trang tài khoản, điểm danh, nạp xu, tải game, Shop và quản trị ảnh; ảnh dự phòng trả về đúng SVG.
- Kiểm tra trực tiếp hiển thị ngân hàng trước khi tạo đơn và gọi API tạo QR gốc; mã nội dung hiển thị khớp phản hồi máy chủ. Không chuyển tiền ngân hàng.
- Nhận thưởng điểm danh, xác minh thông báo/số dư/ngày đã nhận và từ chối lượt nhận lặp. Lượt điểm danh thử và số xu thử đã được hoàn nguyên có kiểm tra; tài khoản vẫn có thể tự nhận ngày đầu.
- Kiểm tra menu máy tính/điện thoại, ảnh ở trang đầu/trang AJAX và hộp thoại mua. Không thực hiện mua vật phẩm hoặc giao vật phẩm thử vào game.
- Chỉ xóa đúng đơn nạp Pending do đợt kiểm tra tạo; không sửa giao dịch đã thanh toán.

Bản sao trước sửa và ảnh kiểm tra nằm ngoài dự án: `C:\Users\Admin\Downloads\webchinh-profile-fixes-backup-20261108`.

Razor và tài nguyên được nhúng trong DLL. Cần build/publish và khởi động lại ứng dụng khi cập nhật máy chủ web.
