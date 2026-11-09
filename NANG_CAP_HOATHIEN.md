# Cửu Long Hỏa Thiên – giao diện và tính năng

## Các trang

- `/`: bố cục giới thiệu và ảnh môn phái theo phong cách Home/About.
- `/Ranking`: cả bốn bảng có bộ lọc sáu môn phái; lọc trên SQL trước khi lấy 100 nhân vật.
- `/Home/About`: các khối ảnh/nội dung quản trị, cùng phần môn phái, chức vị và cảnh giới đã có.
- `/Home/Topup`: chọn số tiền, tạo QR, theo dõi thanh toán và cổng SePay đang có.
- `/Home/Games`: năm bàn chơi; chơi thử không ghi xu hoặc phần thưởng thật.
- `/Profile/Profile`: số dư ví và nhân vật lấy từ dữ liệu tài khoản/game hiện có.
- `/Profile/DailyCheckIn`: thưởng, chuỗi ngày và lịch sử điểm danh; ngày mới theo UTC+7.
- `/Profile/Profile/GachaHistory`: lịch sử chung của cả năm trò chơi, phân trang.

Đăng xuất bằng POST có mã chống giả mạo và chuyển về `/`. Các liên kết cũ và các endpoint SePay cũ được giữ lại.

## Quản trị

Chỉ tài khoản có quyền Admin được vào `/Profile/Admin`:

| Chức năng | Đường dẫn |
| --- | --- |
| Giới thiệu: thêm, sửa, xóa, ẩn, thứ tự, ảnh và liên kết | `/Profile/Admin/AboutSections` |
| Tin tức: cả bài đã đăng và bản nháp | `/Profile/Admin/News` |
| Sự kiện | `/Profile/Admin/News?category=event` |
| Tài khoản: tra cứu và chỉnh thông tin liên hệ | `/Profile/Admin/Users` |
| Cấp xu qua chức năng gốc | `/Profile/Admin/AddCoins` |
| Điểm danh: lịch sử và cấu hình thưởng | `/Profile/Admin/CheckInHistory`, `/Profile/Admin/DailyCheckInRewards` |
| Trò chơi mới: giá, bật/tắt, thêm/sửa/xóa phần thưởng | `/Profile/Admin/Gacha` |
| Vòng quay/Lật thẻ: quản trị gốc | `/Profile/Admin/LuckyWheelConfigs`, `/Profile/Admin/GiftBoxConfigs` |
| Đối soát lịch sử cả năm trò chơi | `/Profile/Admin/GachaLogs` |
| Nạp xu: lịch sử giao dịch và ưu đãi | `/Profile/Admin/Deposits`, `/Profile/Admin/DepositBonuses` |
| Kỳ Trân Các: danh mục và vật phẩm | `/Profile/Admin/ShopCategories`, `/Profile/Admin/ShopItems` |

Tài khoản quản trị game đang có vẫn được nhận diện như trước. Có thể cấp riêng quyền quản trị website bằng cách thêm **MemberId của tài khoản đã tồn tại** vào `dbo.Tbl_Web_SiteAdmins`; xóa dòng để thu hồi. Đăng nhập lại sau khi cấp quyền. Mỗi yêu cầu vào Admin kiểm tra lại quyền từ SQL để việc thu hồi có hiệu lực với phiên cũ. Không thay đổi `member_class` của tài khoản game khi cấp quyền website bằng bảng này.

Các giao dịch xu và lịch sử nhận thưởng được giữ để đối soát. Không có nút xóa tài khoản game hoặc sửa tùy ý số dư của giao dịch đã thanh toán. Cấp xu dùng chức năng gốc có ghi lịch sử.

## Dữ liệu

Giữ `NineDragons_Account`, `ND_GAME_0` và `CIS_DB` hiện có. Không tạo database mới, không tạo ví xu riêng trong trình duyệt.

| Nhóm | Bảng chính |
| --- | --- |
| Tài khoản/ví | `Tbl_ND_Member_Login`, `Tbl_ND_Web_Member` |
| Nhân vật | `ND_GAME_0.dbo.ND_V01_Charac`, `ND_V01_CharacState` |
| Nội dung | `News`, `Tbl_Web_AboutSections` |
| Điểm danh | `Web_DailyCheckIn`, `Web_DailyCheckInRewardRule` |
| Nạp xu | `Tbl_ND_Web_Transactions`, `Tbl_Web_Deposit_Bonus` |
| Cửa hàng/mốc tiêu phí | `Tbl_Web_Shop_Items`, `Tbl_Web_Shop_Categories`, `Tbl_Web_Shop_Purchases` và các bảng mốc gốc |
| Vòng quay | các bảng `Tbl_Web_LuckyWheel_*` gốc |
| Lật thẻ | các bảng `Tbl_Web_GiftBox_*` gốc |
| Rương, Đập hộp, Xổ số | `Tbl_Web_Gacha_Config`, `Tbl_Web_Gacha_Prizes`, `Tbl_Web_Gacha_Play`, `Tbl_Web_Gacha_History` |
| Vật phẩm vào game | `CIS_DB.dbo.Tbl_Cash_Inven` |

Vòng quay và Lật thẻ gọi lại controller, stored procedure và luồng giao vật phẩm gốc. Vì SQL chưa có sự kiện Lật thẻ đang bật, đã tạo bộ cơ bản 40 xu/lượt, thưởng xu; không sửa các cấu hình sự kiện cũ. Rương và Đập hộp có bộ thưởng xu ban đầu, Admin có thể bổ sung vật phẩm bằng CashItemId hợp lệ. Xổ số lấy kết quả ngẫu nhiên phía SQL trong khoảng 000–999.

Trò mới trừ xu, cộng thưởng, ghi lịch sử và ghi mốc tiêu phí trong cùng giao dịch SQL. Mã lượt chơi chống xử lý lặp. Điểm danh khóa ví trước khi kiểm tra ngày và cộng thưởng; bấm lặp không cộng thêm xu. Giao vật phẩm có trạng thái Pending/Processing/Delivered/Review; trường hợp cần kiểm tra không tự phát lại vật phẩm. Luồng giao vật phẩm hỗ trợ đúng số lượng trong cùng giao dịch CIS.

## Script SQL và triển khai

Các script đã được áp dụng trên SQL hiện tại:

1. `WebPage.Core/setup-portal-upgrade.sql`
2. `WebPage.Core/setup-portal-card-default.sql` – chỉ tạo sự kiện mẫu khi chưa có sự kiện đang bật.
3. `WebPage.Core/setup-portal-admin-ledgers.sql`
4. `WebPage.Core/setup-portal-auth.sql`
5. `WebPage.Core/setup-portal-cms.sql`

Chạy trong database tài khoản hiện có. Script nâng cấp dùng các bảng gốc của dự án; không dùng để dựng database game trống. Thông tin kết nối tiếp tục lấy từ cấu hình ứng dụng, không đưa thông tin đăng nhập SQL vào giao diện hoặc script nâng cấp.

Razor và tài nguyên được biên dịch/nhúng vào DLL. Khi đưa lên máy chủ web, cần build/publish rồi khởi động lại ứng dụng; thay riêng file Razor không cập nhật được bản đã biên dịch.

## Kiểm tra

- Build ASP.NET Core và biên dịch Razor.
- Kiểm tra HTTP các trang công khai, yêu cầu đăng nhập ở các trang riêng, POST đăng xuất về trang chủ và endpoint webhook yêu cầu API key.
- Kiểm tra giao diện máy tính/điện thoại, biểu mẫu chống giả mạo và ảnh.
- Kiểm thử SQL: cả năm trò chơi, ghi mốc tiêu phí, trừ/cộng xu, lượt chơi lặp, điểm danh lặp, CRUD Giới thiệu, bản nháp/đăng/xóa sự kiện, CRUD ưu đãi nạp và quyền Admin website.
- Kiểm thử luồng SQL nạp xu gốc: tạo đơn, xác nhận, cộng xu và xác nhận lặp.
- Mọi thay đổi dữ liệu của các kiểm thử giao dịch đều được rollback. Không thực hiện chuyển khoản ngân hàng thật hoặc phát vật phẩm thật để thử.

Bản sao mã nguồn trước nâng cấp và kết quả kiểm tra nằm ngoài dự án tại `C:\Users\Admin\Downloads\webchinh-full-upgrade-backup-20261108`.
