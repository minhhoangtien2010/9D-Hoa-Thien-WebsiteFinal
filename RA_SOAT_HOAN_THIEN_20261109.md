# Rà soát và hoàn thiện ngày 09/11/2026

Đây là bản đối chiếu công việc với mã nguồn, SQL đang dùng và kết quả kiểm thử. Không commit, push hoặc triển khai lên máy chủ production. Website local dùng cổng 5085; dữ liệu tính năng tiếp tục nằm trong database tài khoản hiện có và CIS_DB của dự án.

## Các hạng mục đã triển khai

| Hạng mục | Kết quả và nơi sử dụng |
| --- | --- |
| Quản trị nạp tự động | `/Profile/Admin/DepositSettings`: sửa ngân hàng, số tài khoản, chủ tài khoản, cấu hình nạp và bật/tắt hiển thị. Website và nội dung thông báo đọc cùng cấu hình SQL. Khi đổi ngân hàng, vẫn cần liên kết tài khoản tương ứng tại nhà cung cấp thanh toán. |
| Telegram | `/Profile/Admin/Telegram`: theo dõi hàng đợi, kết nối và gửi lại. Thêm thông báo giao dịch Admin cấp xu mới; ghi rõ nguồn thủ công, không coi xu được cấp là tiền VND chuyển khoản. Không gửi lại toàn bộ lịch sử cũ. |
| Google Sheet | `/Profile/Admin/DepositReport`: cấu hình URL Web App, ngày bắt đầu, bật/tắt, CSV, bảng trạng thái và gửi lại. Đã bật từ 09/11/2026, worker gửi thành công và đọc lại được giao dịch trên Sheet công khai. Gửi lại giữ một dòng theo mã giao dịch. Xem `KET_NOI_GOOGLE_SHEET.md`. |
| Bật/tắt trò chơi | `/Profile/Admin/GameRewards`: điều khiển riêng năm trò chơi; có kiểm tra phía máy chủ. Phần thưởng dùng ID và số lượng vật phẩm, có bộ chọn từ danh mục Kỳ Trân Các. Các trọng số gốc được giữ, SQL và website dùng cùng dữ liệu. |
| Ảnh Giới thiệu và Tin tức | Quản trị nội dung hiện có, tải ảnh mới, chỉnh ngang/dọc, thu phóng và cách hiển thị. Chân dung có chế độ hiện toàn bộ ảnh, bố trí nam/nữ riêng và xem trước. |
| Trang chủ | Banner đã cung cấp; ba nút Đăng ký, Tải game, Nạp xu; Tiên Duyên Các gọn hơn; ẩn Tài Phú Bảng; nội dung cảnh giới tái sử dụng dữ liệu Giới thiệu. |
| Giao diện chung | Tông ngà vàng đã hạ độ sáng; chữ và bảng tăng tương phản. Header, footer và thanh điều hướng điện thoại được sắp xếp lại. Menu Profile nằm bên trái trên máy tính. |
| Trò chơi thật | Loại bỏ chế độ chơi thử, dữ liệu giả và mã chơi thử. Hiển thị trạng thái tài khoản, giá và quà từ SQL. Vòng quay có nút 5/10/20 lượt, gửi một yêu cầu theo cơ chế SQL có sẵn. |
| Hiệu ứng kết quả | Hộp kết quả ở giữa màn hình, nhóm quà trùng, số lượt thực hiện, số dư và cảnh báo giao thưởng. Có hỗ trợ Tab/Escape và trả focus về nút chơi. |
| Đổi tên nhân vật | `/Profile/CharacterRename`, phí mặc định 200 xu. Chỉ thực hiện sau khi xác nhận đã thoát game ít nhất 30 giây. Đổi tên, trừ xu, phiếu tiêu phí và lịch sử cùng transaction. Không tự kick hoặc khóa 10 phút; phương án yêu cầu thoát game đã được người dùng đồng ý. |
| Quản trị đổi tên | `/Profile/Admin/RenamePricing`, `RenameRequests`, `RenameAudit`: thêm/sửa/bật/tắt/lưu trữ mức phí, xem lịch sử và nhật ký; kiểm tra phiên bản chống ghi đè. |
| Profile | Giftcode, Settings, ChangePassword, SpendingMilestone, DepositMilestone được trang trí, giữ biểu mẫu và cơ chế nhận thưởng cũ. Thêm kiểm tra máy chủ cho xác nhận mật khẩu mới. |
| Bảng quản trị | Bốn nhóm chức năng, tìm kiếm tiếng Việt có/không dấu, liên kết tới nạp, báo cáo, đổi tên, nội dung, trò chơi và danh mục. |
| Ranking | Giữ nhãn Ác Danh/Danh Tiếng. Bốn bảng đọc thêm giới tính từ SQL để chọn ảnh đúng môn phái và giới tính; giá trị không biết dùng biểu tượng trung tính. |
| Đăng nhập Shop | Giữ ReturnUrl qua GET, POST và nhập thiếu/sai; chỉ chuyển về đường dẫn nội bộ hợp lệ. |
| Kỳ Trân Các ingame | `/InGame/Shop` và `/InGame/History`, layout riêng, ES5/XMLHttpRequest, không tải script hiện đại của website. Dùng tài khoản, ví, repository, SQL và luồng mua/tặng cũ. Trình duyệt MSHTML vào Shop cũ được chuyển sang giao diện riêng. |
| Chuyển máy | Gói Windows x64 tự chứa .NET, công cụ kiểm tra SQL/kho ảnh, chạy/dừng, chuyển token và khóa Sheet bằng gói mã hóa. Khóa giải mã phải chuyển riêng. Xem `DONG_GOI_CHUYEN_MAY.md`. |

Không tự sửa hoặc ánh xạ ID quà cũ sang vật phẩm khác. Một số file ảnh Shop gốc đã thiếu từ trước vẫn dùng ảnh thay thế; cần tải lại ảnh thật nếu muốn khôi phục đúng từng vật phẩm. Quản trị website thao tác trên các chức năng được cung cấp, không mở màn hình chạy câu lệnh SQL tùy ý.

## Kiểm thử đã thực hiện

- Build Debug và publish Windows x64 thành công. Dự án còn các cảnh báo cũ về nullable và gói thư viện; chi tiết nằm trong log kiểm thử, không coi là không có cảnh báo.
- Đăng nhập bằng phiên mới: quay lại đúng Shop có bộ lọc; giữ ReturnUrl khi validation thất bại; từ chối URL chuyển hướng ra ngoài. Không đổi phương thức xác thực hoặc bỏ CSRF.
- Shop ingame: đọc danh mục, số dư và lịch sử thật; không tự đăng nhập bằng `userid`; giao dịch khách, thiếu CSRF hoặc tham số không hợp lệ bị chặn.
- Phân tích cú pháp ES5 bằng Acorn; chạy giao diện ingame trong Chromium khi vô hiệu hóa `fetch`, `Promise`, `URLSearchParams`, `closest`, `NodeList.forEach`, `Object.assign`. Kiểm tra mở/đóng hộp mua/tặng, focus và ảnh thay thế. Chưa thay thế được kiểm thử MSHTML thực tế.
- Kiểm thử controller đã biên dịch bằng mock: tặng vật phẩm cho đúng người nhận, ghi tiêu phí cho người mua, từ chối tự tặng và giao dịch sai. Không gọi giao vật phẩm thật.
- SQL Shop: gọi thủ tục mua số lượng hai và tặng trong transaction bên ngoài rồi rollback; kiểm tra đúng số xu, người nhận và phiếu giao dịch; số dư/lịch sử trở về trạng thái ban đầu. Không gọi CIS hoặc dịch vụ giao vật phẩm.
- SQL đổi tên: đổi tên trong transaction và rollback, đủ/thiếu xu, tên trùng, sai chủ, phiên game chưa kết thúc, mức phí cũ, chống gửi lặp, thêm/sửa/bật/tắt/lưu trữ mức phí. Không để lại tên hoặc khoản thu thử.
- SQL vòng quay: 1/5/10/20 lượt, lượt tặng, vé, xu, giới hạn ngày, tồn quà, thiếu xu và danh sách quà trống; rollback toàn bộ. Giá và cơ chế giao thưởng gốc giữ nguyên.
- Trình duyệt trò chơi: chặn yêu cầu chơi ngay trong tab kiểm thử để kiểm tra 20 lượt gửi một lần và hộp kết quả; không gửi lượt chơi thật tới SQL/CIS.
- SQL Telegram/báo cáo: Admin cấp xu trong transaction rồi rollback; kiểm tra nguồn, phiên bản dữ liệu, quyền xử lý hàng đợi, gửi lại và thay cấu hình. Apps Script kiểm thử chữ ký, thời gian, chống trùng và chặn chuỗi công thức.
- Google Sheet thực tế: worker gửi thành công và SQL ghi Đã đồng bộ; đọc lại đúng một dòng giao dịch, gửi lặp không tạo thêm dòng. Tổng quan đã hết lỗi vùng và các tổng số khớp dòng chi tiết, tách đúng tiền chuyển khoản với xu Admin cấp. Không cộng xu hoặc tạo đơn thử.
- Báo cáo lấy ngày hoàn tất thanh toán, dùng ngày tạo khi chưa hoàn tất. SQL integration test xác nhận đơn tạo trước mốc lọc nhưng hoàn tất sau mốc vẫn được thu; rollback khôi phục trạng thái đơn và không để lại dòng báo cáo hoặc thông báo thử.
- Đã xem và kiểm tra giao diện máy tính/điện thoại, ảnh, CSRF, tràn ngang và lỗi JavaScript cho các trang Profile đã mở, trò chơi và bảng quản trị. Riêng trang Mốc tiêu phí có cơ chế tự cấp quà khi GET vốn có; tránh gọi GET bằng tài khoản có tiêu phí để thử giao diện gây nhận thưởng thật. View đã được biên dịch và rà soát.

## Những phần cần xác nhận bên ngoài

1. **NineDragons.exe/IE11:** cần mở bằng client game thật để kiểm tra chế độ tài liệu, cookie và đóng cửa sổ. Chưa mua/tặng vật phẩm thật trong client.
2. **SePay Checkout:** chưa có X-Secret-Key IPN riêng của Checkout. QR chuyển khoản là luồng riêng; thay ngân hàng trên website không tự tạo liên kết ngân hàng ở SePay.
3. **Chuyển máy khác:** đã có gói tự chứa runtime và preflight; vẫn cần quyền truy cập SQL, firewall/IP phù hợp, giữ kho ảnh, nhập token/khóa và cấu hình tên miền/callback. Chưa chạy trên máy thứ hai thực tế.

Google Sheet đang lấy giao dịch từ 09/11/2026. Muốn lấy lịch sử trước ngày này, Admin đổi ngày bắt đầu rồi làm mới từ giao dịch.

## Các tệp chính thay đổi trong đợt này

- `WebPage.Core/Controllers/AccountController.cs`, `ViewModel/LoginModel.cs`, view Login; `WebGame/Controllers/InGameController.cs`, các view `WebGame/Views/InGame`, `ingame-shop.css/js`.
- `WebPage.Core/Features/Shop/ShopController.cs`: giao quà cho đúng người nhận.
- `WebPage.Core/Services/CharacterRenameRepository.cs`, controller/view CharacterRename và AdminCharacterRename; `setup-character-rename.sql`, `setup-character-rename-apply.sql`.
- `WebPage.Core/Services/DepositReport.cs`, AdminDepositReport controller/view, `Resources/DepositSheets.gs`, `setup-deposit-report.sql`; worker/model/view Telegram.
- `setup-ranking-gender.sql`, các model/repository Ranking và `CharacterPortrait.cs`, controller Home/Ranking, view Ranking.
- Các view Games, `GachaController`, LuckyWheel, `setup-wheel-batch20.sql`, `games-board.js`, `gacha-live.js`, `games-arena.js`, `games-refined.css`, `hoathien.js`.
- View các trang Profile nêu trên, `profile-services.css`, `profile-polish.js`, model đổi mật khẩu; dashboard Admin và `admin-workspace.css/js`.
- Các partial header/footer/menu, `portal-chrome.css`, `gold-white.css`, hai layout chung; công cụ và script `deployment`, `tools/Portal.Portable`.

Các script SQL mới đã được áp dụng trên database đang dùng. Mang gói sang máy khác tiếp tục kết nối database đó thì không cần tạo database mới hoặc chạy lại script để thay dữ liệu. Lưu các script SQL trong source để quản lý phiên bản; không chạy bừa toàn bộ file SQL trong dự án.
