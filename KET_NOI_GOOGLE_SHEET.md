# Kết nối báo cáo nạp xu

Sheet đã lưu trong cấu hình: https://docs.google.com/spreadsheets/d/16MDII88EkoR1aA7heSRXobU9CKf2lOLdd_bEQWLstE8/edit

Màn hình quản trị: `/Profile/Admin/DepositReport`. Có cấu hình Sheet, ngày bắt đầu, bảng giao dịch, CSV, trạng thái và gửi lại. Website thu cả đơn chuyển khoản và xu Admin cấp; các khoản cấp xu không bị tính nhầm thành tiền chuyển khoản. Không thay đổi số dư khi thu hoặc gửi báo cáo.

## Chủ Sheet thiết lập một lần

1. Đăng nhập Google bằng tài khoản sở hữu Sheet. Mở Sheet → **Tiện ích mở rộng → Apps Script**.
2. Trong Admin website, bấm **Tải mã Apps Script**. Mã đã được chuẩn bị sẵn tại `C:\Users\Admin\Downloads\HoaThien-NapXu-AppsScript-20261109.gs`. Dán toàn bộ vào Apps Script thay mã trống mặc định.
3. Lưu, chọn hàm **setup**, bấm **Chạy** và cấp quyền cho mã quản lý bảng của mình. Hàm tạo hai tab **Nạp xu** và **Tổng quan**, không xóa các tab cũ.
4. Chọn **Triển khai → Triển khai mới → Ứng dụng web**. Chạy bằng tài khoản của chủ Sheet, cho phép truy cập bằng đường dẫn (**Anyone/Mọi người**). Mỗi yêu cầu ghi vẫn phải có chữ ký bí mật hợp lệ.
5. Sao chép URL được cấp, dạng `https://script.google.com/macros/s/.../exec`. Nhập URL đó tại Admin → **Báo cáo & Google Sheet**, chọn ngày bắt đầu và bật đồng bộ. Có thể gửi URL `/exec` lại trong cuộc trò chuyện để tôi hoàn tất cấu hình và xác minh kết nối.

Đã lưu URL Web App do chủ bảng cung cấp và bật đồng bộ từ ngày **09/11/2026** qua biểu mẫu quản trị có xác thực và CSRF. Đã đồng bộ một giao dịch Admin cấp xu có sẵn, không tạo giao dịch tài chính hoặc cộng xu thử. Worker nhận xác nhận của Google, SQL chuyển **Đã đồng bộ**; đọc lại Sheet công khai thấy đúng một dòng theo ID giao dịch, tiền chuyển khoản để trống và số xu được ghi riêng. Gửi lại cùng mã được Google xác nhận thành công, không tạo thêm dòng.

Đã sửa công thức Tổng quan sang dạng không phụ thuộc dấu phân cách đối số của vùng. Chủ Sheet đã chạy lại `setup`; đọc lại tab Tổng quan xác nhận không còn lỗi công thức. Cập nhật công thức giữ nguyên các dòng giao dịch và không cần triển khai lại Web App cho riêng thay đổi này.

Mã Apps Script tải về chứa khóa kết nối riêng: chỉ dán vào dự án Apps Script của chủ bảng, không đưa mã/khóa lên Sheet công khai. Khi chuyển máy, dùng công cụ nhập bí mật trong gói portable; khóa Google Sheet được chuyển cùng token Telegram bằng gói mã hóa.

## Dữ liệu và đối soát

Các cột hiển thị gồm mã đồng bộ, ID giao dịch, thời gian máy chủ, tài khoản, mã đơn, nguồn, tiền VND, xu cộng, xu thưởng và trạng thái. Cột phiên bản K được ẩn để tránh lần gửi cũ ghi đè kết quả mới. Mỗi giao dịch có một dòng; gửi lại sẽ cập nhật dòng đó.

Không gửi mật khẩu, token bot, IP hay số tài khoản ngân hàng. Tab Tổng quan tách tiền chuyển khoản và xu Admin cấp. Ngày bắt đầu do Admin chọn; có thể tải CSV để kiểm tra dữ liệu trước khi bật đồng bộ ngoài.

Mốc thời gian lấy theo ngày hoàn tất thanh toán nếu có, nếu chưa hoàn tất thì theo ngày tạo đơn. Vì vậy đơn được tạo hôm trước nhưng thanh toán hôm sau vẫn được đưa vào báo cáo của khoảng thanh toán tương ứng. Đã kiểm tra trường hợp này bằng transaction hoàn tác, không hoàn tất đơn hoặc cộng xu thử thật.

Nếu chỉnh mã Apps Script sau khi triển khai, cập nhật phiên bản triển khai đang dùng, không chỉ bấm Lưu. Nếu tạo lại khóa từ website, phải tải và triển khai lại mã tương ứng.

Nếu kết nối bị từ chối, mã mới cung cấp thông báo riêng cho chưa chạy setup, khóa không khớp, sai Sheet hoặc không ghi được bảng. Không trả nội dung giao dịch hoặc khóa trong thông báo lỗi. Với lỗi ghi bảng, xem Nhật ký thực thi trong tài khoản chủ Apps Script. Bản cập nhật chỉ mã lỗi giữ nguyên khóa đang sử dụng; không bấm tạo lại khóa để thử khắc phục lỗi quyền Google.

Đã kiểm tra SQL bằng rollback, chữ ký HMAC, xử lý gửi lại, phiên bản dữ liệu và chống công thức từ nội dung văn bản. Đã kiểm tra ghi thực tế, đọc lại dòng giao dịch trên Sheet công khai và gửi lặp có xác nhận. Nếu thay mã nhận dữ liệu, chọn **Quản lý các bản triển khai → bút chì → Phiên bản → Phiên bản mới → Triển khai**; bấm Lưu mã trong editor không cập nhật phiên bản đang chạy.

Tài liệu Google: [Web Apps](https://developers.google.com/apps-script/guides/web), [cập nhật phiên bản triển khai](https://developers.google.com/apps-script/concepts/deployments), [Content Service](https://developers.google.com/apps-script/guides/content), [Spreadsheet Range](https://developers.google.com/apps-script/reference/spreadsheet/range#setvaluesvalues).
