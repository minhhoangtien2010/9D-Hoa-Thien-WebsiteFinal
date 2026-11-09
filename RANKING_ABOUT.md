# Cập nhật Ranking và Home/About

Lần đổi tên bảng/cột, ẩn bộ lọc và sửa tên nhân vật mới nhất được ghi tại [RANKING_TITLES.md](RANKING_TITLES.md). Trang Ranking hiện hiển thị bốn tab; dữ liệu rich cũ vẫn được giữ ở phía xử lý.

Đã đối chiếu trực tiếp với hai trang `#ranking` và `#about` trong file `C:\Users\Admin\Downloads\indexfinal.html`.

## Phạm vi rà soát

- Ranking: controller `WebPage.Core/Features/Ranking/RankingController.cs`, view dùng chung `WebPage.Core/Views/Ranking/Index.cshtml`, model `WebPage.Core/ViewModel/Rank.cs`, các partial `_RankingPreview.cshtml` của Core/WebGame, `_RankingTriple.cshtml`, các khối xếp hạng trong trang chủ và CSS/JS liên quan.
- About: `WebGame/Views/Home/About.cshtml`, `WebPage.Core/Controllers/HomeController.cs`, `AboutSectionPoco.cs`, `about-sections.css`, layout, menu và các ảnh đang dùng.
- Không chỉnh các bản biên dịch/sao chép trong `bin` và `obj` bằng tay.

## Kết quả

Ranking dùng view mới tại `WebGame/Views/Ranking/Index.cshtml`, được ASP.NET ưu tiên thay cho view dùng chung của Core. View Core được giữ lại để bảo toàn cấu trúc thư viện.

- Banner phong cảnh, sáu ảnh đại diện môn phái, các nút chọn bảng/lọc, bục top 3 với hạng 1 ở giữa và bảng có ảnh nhân vật theo bố cục mẫu.
- Giữ nguyên controller, repository, các cột dữ liệu, thứ hạng, bộ lọc môn phái và năm loại dữ liệu controller đã hỗ trợ: cấp độ, online, ác danh, danh tiếng, tổng nạp.
- Tìm kiếm, lọc chức trách và “Xem thêm” chỉ xử lý các dòng thực do controller trả về. Không sinh tên, số liệu hoặc máy chủ giả. Máy chủ trong bộ lọc lấy từ cấu hình hiện có.
- `ranking-indexfinal.css` cũng trang trí các partial Ranking hiện có; `ranking-indexfinal.js` chỉ hoạt động trong trang Ranking.

About dùng poster ngang trên máy tính, poster dọc trên điện thoại, phần câu chuyện hai cột, sáu thẻ điểm nổi bật, bộ ảnh chân dung 3 cột/2 cột, thẻ môn phái, hai thế lực, bảng chức trách, bản đồ và cảnh giới. Các nút Nam/Nữ chỉ thay ảnh có sẵn của môn phái; nội dung và dữ liệu vẫn giữ nguyên. Phần hiển thị nội dung `ViewBag.AboutSections` được giữ lại.

Đã bổ sung action GET `HomeController.About()` để mở view có sẵn. Đây là phần nối đường dẫn hiển thị; không thêm truy vấn hoặc thao tác ghi database. So sánh với bản sao lưu xác nhận HomeController chỉ thêm action này; controller Ranking, model, repository, JSON kết nối, XML và SQL không thay đổi.

## Mở xem

- [Ranking](http://localhost:5188/Ranking)
- [About](http://localhost:5188/Home/About)

Nhấn **Ctrl + F5** nếu trình duyệt còn giữ CSS cũ.

Bản sao lưu, ảnh máy tính/điện thoại và báo cáo đối chiếu nằm ở `C:\Users\Admin\Downloads\webchinh-ranking-about-backup-20261108`.

Đã build solution và kiểm tra bằng trình duyệt, gồm các bảng Ranking, lọc môn phái, tìm kiếm không có kết quả, khôi phục tìm kiếm, xem thêm và chuyển ảnh môn phái. Không thực hiện thao tác ghi vào dữ liệu game/tài khoản để kiểm thử.
