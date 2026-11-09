Kỳ Trân Các trong cửa sổ game

- Địa chỉ vào cửa hàng: `/InGame/Shop` (máy hiện tại: `http://localhost:5085/InGame/Shop`).
- Lịch sử dùng cùng tài khoản: `/InGame/History`.
- Chưa đăng nhập: trang đăng nhập gọn dành cho cửa sổ game; đăng nhập xong quay lại đúng cửa hàng.
- Tài khoản được xác thực bằng luồng đăng nhập website hiện có. Tham số `userid` hoặc tên tài khoản trong đường dẫn không thể thay cho đăng nhập.
- Danh mục, vật phẩm, giá, giới hạn, số dư và lịch sử đọc qua repository/SQL hiện có. Mua/tặng gọi lại `/Profile/Shop/Purchase` và `/Profile/Shop/Gift`; dùng cùng ví và luồng giao vật phẩm CIS.
- Có xác nhận trước khi mua/tặng, chống bấm lặp khi đang gửi, token chống giả mạo yêu cầu và thông báo kiểm tra lịch sử khi kết nối gián đoạn. Không tự gửi lại giao dịch bị mất phản hồi.
- Trang cửa hàng website `/Profile/Shop` vẫn dùng giao diện hiện tại cho trình duyệt thông thường.

Phần dành cho cửa sổ game có layout riêng, JavaScript ES5 + XMLHttpRequest, CSS bố cục thông thường, font hệ thống; không tải các script/theme hiện đại của trang website. Ảnh không đọc được trong MSHTML được thay bằng ảnh minh họa SVG, gồm định dạng WebP mà IE11 không hỗ trợ.

Tài liệu kỹ thuật Microsoft:

- `X-UA-Compatible` chọn chế độ tài liệu IE hỗ trợ: https://learn.microsoft.com/en-us/openspecs/ie_standards/ms-iedoco/380e2488-f5eb-4457-a07a-0cb1b6e4b4b5
- WebBrowser control sử dụng nền tảng MSHTML/Trident: https://learn.microsoft.com/en-us/microsoft-edge/devtools/ie-mode/

Cần trỏ nút cửa hàng của client đến URL trên. Thiết lập chế độ trình duyệt của host và sự kiện đóng cửa sổ thuộc client game; trang chỉ gọi đóng khi người dùng bấm nút Đóng, không tự lấy focus hoặc đổi cửa sổ. Kiểm tra cú pháp ES5 và chạy trên Chromium không thay thế kiểm thử thực tế trong NineDragons.exe/IE11.

Sửa đăng nhập chung: `ReturnUrl` đi từ GET → model → trường ẩn POST; giữ khi nhập thiếu/sai và chỉ dùng `LocalRedirect` khi `Url.IsLocalUrl` xác nhận đường dẫn nội bộ.
