# Đóng gói và chuyển máy

Dùng bản phát hành tự chứa runtime Windows x64 để chuyển máy; chép nguyên source rồi chạy từ `bin/Debug` có thể thiếu runtime, ảnh đã tải lên hoặc token được mã hóa riêng trên máy cũ.

Tại thư mục dự án, mở PowerShell và chạy:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deployment\Build-Portable.ps1
```

Script tạo thư mục `CuuLongHoaThien-Windows-x64-<thời điểm>` và ZIP bên cạnh dự án, có `WebGame.exe`, runtime .NET/ASP.NET Core, cấu hình, ảnh `App_Data/uploads`, công cụ kiểm tra SQL và script chạy/dừng. Script không xóa bản đóng gói cũ.

Token Telegram/khóa IPN cục bộ được xuất dưới dạng mã hóa AES-256-GCM. Khóa di chuyển được giữ riêng tại `C:\ProgramData\HoaThienPortal\migration-key.txt`, không đưa vào ZIP. Việc nhập trên máy mới tạo lại file DPAPI gắn với máy mới, vì chép nguyên file DPAPI từ máy cũ không dùng được.

Hướng dẫn thao tác ở máy đích nằm trong [deployment/HUONG_DAN_CHUYEN_MAY.md](deployment/HUONG_DAN_CHUYEN_MAY.md) và được chép vào bản phát hành. Trên máy mới: nhập bí mật → kiểm tra kết nối → chạy `CHAY_WEBSITE.cmd`.

Cấu hình kết nối SQL vốn có vẫn nằm trong gói nên toàn bộ ZIP cần được giữ riêng tư. Khả năng truy cập SQL từ IP mới, firewall và cấu hình tên miền/callback của nhà cung cấp vẫn cần đúng ở môi trường đích. Ảnh vật phẩm gốc vốn thiếu không thể phục hồi bằng việc đóng gói; các ảnh đó tiếp tục dùng ảnh minh họa dự phòng như ở máy hiện tại.
