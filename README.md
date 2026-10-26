# Sổ Nợ (BillSplit) - Ứng Dụng Chia Tiền & Quản Lý Công Nợ Thông Minh

Hệ thống ghi nhận, chia tiền và đối soát giao dịch VietQR tự động giữa các thành viên. Ứng dụng đóng vai trò là sổ ghi chép công nợ trung gian, không lưu ký hoặc giữ tiền của người dùng.

---

## 🛠️ Công Nghệ Sử Dụng

### Backend (ASP.NET Core Web API)
- **Framework:** .NET 9 (C#)
- **Kiến trúc:** Clean Architecture (Domain, Application, Infrastructure, API)
- **Cơ sở dữ liệu:** SQLite / SQL Server qua Entity Framework Core
- **Lưu trữ ảnh:** Cloudflare R2 Object Storage (chuẩn S3 API)
- **Bảo mật & Xác thực:** JWT Bearer Token, Gmail SMTP OTP verification (In-memory Cache 10 phút), mã hóa mật khẩu BCrypt.
- **Dịch vụ chạy ngầm:** `ReceiptCleanupBackgroundService` (tự động dọn dẹp ảnh hóa đơn trên R2 sau 14 ngày kể từ khi thanh toán xong).

### Mobile App (Flutter)
- **Framework:** Flutter 3.x (Dart)
- **State Management:** BLoC Pattern (`flutter_bloc`)
- **Mạng & API:** Dio HTTP Client với Interceptor
- **Tính năng nổi bật:**
  - Chế độ Khách (Guest Mode) tính toán hóa đơn không bắt buộc đăng nhập.
  - Tạo và quét mã VietQR chuẩn EMVCo động (tích hợp số tài khoản, tên ngân hàng và số tiền).
  - Tải ảnh đại diện trực tiếp lên Cloudflare R2.
  - Tự động liên kết các khoản nợ cũ khi bạn bè chưa cài app đăng ký tài khoản mới bằng số điện thoại.

---

## 🚀 Khởi Chạy Dự Án

### 1. Backend API
```bash
cd backend/BillSplit.Api
dotnet run --launch-profile http
```
*API lắng nghe tại cổng `http://0.0.0.0:5206`*.

### 2. Mobile App (Flutter)
```bash
cd mobile
flutter run
```
