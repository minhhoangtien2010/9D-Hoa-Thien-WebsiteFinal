# Tên bảng, chức vị, tu vi và tên nhân vật

Trang xem trực tiếp: http://localhost:5188/Ranking. Nhấn Ctrl + F5 để tải CSS/JS mới.

Các tab hiển thị trên trang Ranking:

| Loại dữ liệu hiện có | Tên hiển thị |
| --- | --- |
| player | Thiên Kiêu Bảng |
| online | Nhập Thế Bảng |
| infamy | Sát Lục Bảng |
| honor | Danh Vọng Bảng |

Đã ẩn bộ lọc Lãng Nhân và tab Top Nạp/Tổng nạp trên trang Ranking. Chỉ ẩn các lựa chọn giao diện; không xóa dữ liệu hoặc thay đổi endpoint/repository cũ.

Thiên Kiêu Bảng xếp cột theo thứ tự **Hạng, Phong Hào, Môn Phái, Chức Vị, Thế Lực, Tu Vi**. Các bảng khác giữ các trường đang có, đổi chỉ số tương ứng thành **Thọ Nguyên**, **Sát Lục**, **Danh Vọng**.

## Chức vị và cảnh giới

`WebPage.Core/Helper/GameDisplayCatalog.cs` là nguồn tên dùng chung cho Ranking và About. Thông tin sáu môn phái và 17 cảnh giới được chuyển nguyên từ About, không thay đổi các mốc cấp.

| Môn phái | Cận chiến | Hỗ trợ | Hoàn hảo | Khí công |
| --- | --- | --- | --- | --- |
| Ma Giáo | Huyết Chiến Ma | Quỷ Hồn Ma | Cuồng Bạo Ma | Hắc Phong Ma |
| Lục Lâm | Bác Đấu Quỷ | Diệu Thủ Quỷ | Thái Sơn Quỷ | Thiết Giáp Quỷ |
| Cái Bang | Chiến Vệ Cái | Thương Minh Cái | Đấu Hồn Cái | Giáng Long Cái |
| Thiếu Lâm | La Hán Tăng | Kim Cang Tăng | Phục Ma Tăng | Chế Ma Tăng |
| Võ Đang | Thanh Long Nhân | Chu Tước Nhân | Bạch Hổ Nhân | Huyền Vũ Nhân |
| Bí Cung | Chiến Thần Nữ | Thiên Thần Nữ | Tử Hà Nữ | Nhiếp Hồn Nữ |

Cột Tu Vi hiển thị tên cảnh giới theo cấp thực, ví dụ cấp 141 là **Thiên Hoa Nan Truy**, cấp 193–200 là **Hư Không Phấn Toái**. Cấp gốc được giữ dưới tên cảnh giới để đối chiếu. Các trường không có dữ liệu hoặc vượt ngoài bảng cảnh giới không được gán một cảnh giới giả.

## Lỗi tên nhân vật

Nguồn tên có dấu từ game có hiện tượng byte Windows-1258 bị đọc thành ký tự Windows-1252. `WebPage.Core/Helper/GameCharacterText.cs` sửa các dấu hiệu bảng mã quan sát được và chuẩn hóa Unicode khi hiển thị. Ví dụ:

- `HuyêÌnKhông` → `HuyềnKhông`.
- `ÐôòcCôKhaìch` → `ĐộcCôKhách`.
- `BeìHayKhoìc` → `BéHayKhóc`.

Không ghi tên mới vào database, không đổi khóa tài khoản/nhân vật và không bỏ dấu hàng loạt. Những tên đã là Unicode hợp lệ và ký hiệu trang trí được giữ lại. Bộ lọc tìm kiếm dùng tên đã sửa, hỗ trợ nhập không dấu.

Đã áp dụng phần hiển thị này cho view Ranking của WebGame, view dự phòng của Core, các partial Ranking và khối xếp hạng trang chủ. Controller, repository, cấu hình kết nối và dữ liệu gốc không thay đổi.

## Kiểm tra

- Build solution thành công, 0 lỗi.
- Kiểm tra 30 trường hợp tên/chức vị/mốc cấp và toàn bộ cấp 1–200.
- Kiểm tra HTTP cả bốn bảng, bộ lọc môn phái và About.
- Kiểm tra các nhãn/cột, tìm `huyen`, lọc `Huyết Chiến Ma`, hình ảnh và bố cục máy tính/điện thoại.

Bản sao lưu, chương trình kiểm tra, ảnh xem thử và báo cáo đối chiếu nằm ở `C:\Users\Admin\Downloads\webchinh-ranking-titles-backup-20261108`.
