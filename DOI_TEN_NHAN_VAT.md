# Đổi tên nhân vật

Trang người chơi: `/Profile/CharacterRename`. Phí mặc định **200 xu**; quản trị tại `/Profile/Admin/RenamePricing`, lịch sử tại `/Profile/Admin/RenameRequests`, nhật ký tại `/Profile/Admin/RenameAudit`.

Người chơi cần thoát hoàn toàn game, chờ ít nhất 30 giây rồi tải lại trang. Giữ game đóng đến khi thông báo thành công. Tên mới gồm 3–12 chữ cái không dấu, chữ số hoặc dấu gạch dưới, phù hợp cột tên `varchar(12)` của game.

Giao dịch kiểm tra quyền sở hữu bằng `Tbl_ND_Member_Login.member_guid` và `ND_GAME_0.dbo.ND_V01_Charac.acc_id`. Ví xu vẫn dùng tài khoản `member_id`; không tự sửa các mã ví cũ. Dữ liệu hiện tại có mã `Web_Member.member_guid` khác mã tài khoản game ở nhiều tài khoản cũ, nên không dùng mã ví đó để suy ra quyền sở hữu nhân vật.

`sp_Web_Rename_Apply` kiểm tra phiên game có `cur_state=0`, `temp_id=0`, thời gian thoát mới hơn hoặc bằng lần đăng nhập, và đã qua 30 giây. Đây là các trường được thủ tục game `_prDS_Logout` cập nhật. Chỉ dùng `cur_state=0` sẽ không đủ vì luồng đăng nhập trùng cũng có thể đặt riêng trường này về 0.

Đổi tên game, cập nhật tên hiện hành liên quan, trừ xu, phiếu tiêu phí `CharacterRename` và lịch sử đổi tên nằm trong cùng một transaction SQL. Mã giao dịch chống thu phí hai lần khi gửi lại yêu cầu. Tên trùng, sai chủ sở hữu, chưa thoát game, thiếu xu hoặc mức phí đã đổi đều bị từ chối trước khi hoàn tất. Phiếu tiêu phí được tính cùng cơ chế Mốc tiêu phí đang có.

Website **không tự đá người chơi và không tạo khóa đăng nhập 10 phút**. Các thủ tục SQL hiện có chưa chứng minh được khả năng ngắt phiên game trực tiếp. Module không thay đổi `member_class`, bảng ban hoặc thủ tục đăng nhập cũ. Khi đổi tên thành công, người chơi có thể đăng nhập lại.

Quản trị có thể thêm, sửa, bật/tắt, chọn mức phí đang áp dụng và xóa cấu hình khỏi áp dụng. Xóa lưu trữ cấu hình để giữ lịch sử thu phí, không xóa giao dịch tài chính cũ. Sửa trực tiếp SQL được đọc lại ở lần truy cập kế tiếp; biểu mẫu dùng phiên bản dữ liệu để tránh ghi đè thay đổi mới.

Các bảng mới trong database tài khoản hiện có:

- `Tbl_Web_Rename_Pricing`
- `Tbl_Web_Rename_Requests`
- `Tbl_Web_Rename_Audit`

Triển khai SQL theo thứ tự `WebPage.Core/setup-character-rename.sql`, rồi `WebPage.Core/setup-character-rename-apply.sql`. Đăng ký DI `CharacterRenameRepository` với lifetime Scoped.

Đã kiểm tra bằng giao dịch SQL hoàn tác: đổi tên thật trong transaction, đúng phí, phiếu tiêu phí, lịch sử, gửi lại cùng mã giao dịch, phát hiện phiên chưa kết thúc dù `cur_state=0`, thiếu xu, mức phí cũ, nhân vật tài khoản khác, và thêm/sửa/bật/tắt/xóa mức phí. Tất cả thay đổi kiểm tra đã được rollback; không để lại đổi tên, thu xu hoặc khóa tài khoản thật.
