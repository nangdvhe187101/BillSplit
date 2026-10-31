# Security Audit Report

**Project:** Sổ Nợ (BillSplit)
**Scope:** Toàn bộ repository (`backend/`, `mobile/`) tại nhánh `cachalot`, đã đẩy lên `origin/main` (GitHub `nangdvhe187101/BillSplit`, public/private không xác định từ phía repo)
**Mode:** Comprehensive audit (secrets, dependency, code patterns, STRIDE, OWASP)
**Files checked:** Toàn bộ file đã tracked trong git (backend C#, mobile Dart, config JSON/YAML)

## Summary

| Category | Critical | High | Medium | Low | Info |
|----------|----------|------|--------|-----|------|
| Secrets  | 2        | 0    | 0      | 0   | -    |
| Code     | 0        | 2    | 1      | 0   | -    |
| STRIDE/OWASP | 0    | 0    | 1      | 1   | -    |

## Findings

| # | Mức độ | Phân loại | File:Line | Mô tả | Khắc phục |
|---|--------|-----------|-----------|-------|-----------|
| 1 | **Critical** | Secret / A02 Cryptographic Failures | `backend/BillSplit.Api/appsettings.json:11-12`, `appsettings.Development.json:10-11` | Cloudflare R2 `AccessKeyId` và `SecretAccessKey` thật đã commit và push lên GitHub (`d32550e`). Đây không chỉ nằm trong working tree mà đã vào lịch sử git của remote. | Thu hồi (revoke) token R2 ngay trên Cloudflare Dashboard, tạo token mới, chuyển sang `dotnet user-secrets` hoặc biến môi trường, thêm file vào `.gitignore`. Vì đã push lên remote, cần làm sạch lịch sử git (`git filter-repo`/BFG) hoặc coi repo là compromised và tạo repo mới. |
| 2 | **Critical** | Secret / A02 Cryptographic Failures | `backend/BillSplit.Infrastructure/Services/EmailService.cs:27` | Mật khẩu ứng dụng Gmail `"petr jxhc zdhh jrot"` hardcode làm giá trị fallback **ngay trong mã nguồn** (`_configuration["Smtp:Password"] ?? "petr jxhc zdhh jrot"`), không chỉ trong config. Secret này tồn tại vĩnh viễn trong code dù sau có đổi config, vẫn bị lộ qua `git blame`/lịch sử. | Xóa hẳn giá trị fallback hardcode, bắt buộc đọc từ cấu hình (throw nếu thiếu, theo đúng mẫu đã làm với `Jwt:Secret`). Đổi mật khẩu ứng dụng Gmail ngay trên Google Account. |
| 3 | **High** | A07 Identification & Authentication Failures | `backend/BillSplit.Infrastructure/Services/AuthService.cs:168-186` (`VerifyOtpAsync`) | Không giới hạn số lần thử sai OTP. Mã 6 số (900.000 khả năng) có thể bị dò vét cạn trong vài phút bằng script gửi nhiều request liên tục trước khi OTP hết hạn (10 phút). | Thêm bộ đếm `otp_attempts_{purpose}_{email}` trong `IMemoryCache`; sau 5 lần sai, hủy OTP và yêu cầu gửi lại. |
| 4 | **High** | A04 Insecure Design (Rate Limiting) | `backend/BillSplit.Infrastructure/Services/AuthService.cs:119-166` (`SendOtpAsync`) | Không có cooldown giữa các lần gửi OTP. Một client có thể gọi `POST /api/auth/send-otp` liên tục vào cùng email, dẫn đến email bombing cho người bị target và/hoặc cạn hạn ngạch gửi thư Gmail (500 thư/ngày) khiến toàn hệ thống không gửi được OTP hợp lệ nữa. | Thêm cooldown tối thiểu 60 giây mỗi email trước khi cho gửi OTP mới (dùng `IMemoryCache` key riêng `otp_cooldown_{email}`). |
| 5 | **Medium** | A05 Security Misconfiguration | `backend/BillSplit.Api/Program.cs:69-77` | CORS cấu hình `AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader()` — chấp nhận request từ mọi domain. Phù hợp cho dev/test nhưng là lỗ hổng nếu dùng khi production có mặt web client. | Giới hạn whitelist domain cụ thể (web/app chính thức) khi triển khai production; giữ `AllowAll` chỉ trong môi trường Development. |
| 6 | **Medium** | A02 Cryptographic Failures (Transport) | `mobile/android/app/src/main/AndroidManifest.xml:8` | `android:usesCleartextTraffic="true"` cho phép gửi JWT token, số tài khoản ngân hàng, số tiền nợ qua HTTP không mã hóa. Cần thiết cho test LAN hiện tại nhưng nguy hiểm nếu dùng khi đóng gói bản release kết nối domain thật. | Giữ `true` chỉ cho build dev/debug trỏ tới IP LAN; khi phát hành (release) phải chuyển `false` và backend phải chạy HTTPS. |
| 7 | Low (non-issue, ghi nhận) | A01 Broken Access Control | `backend/BillSplit.Api/Controllers/UsersController.cs:81`, `CloudflareR2StorageService.cs:35-38` | Tên file upload avatar (`file.FileName`) được dùng để lấy `extension`, nhưng key lưu trên R2 luôn được sinh lại bằng `Guid.NewGuid()` + timestamp (`$"{folder}/{DateTime.UtcNow:yyyyMMdd}_{Guid.NewGuid():N}{extension}"`), không ghép trực tiếp tên file người dùng vào path. **Không có path traversal thực tế** — xác minh qua đọc mã nguồn trực tiếp. | Không cần sửa. Ghi nhận để không lặp lại kiểm tra này ở audit sau. |

## Đánh giá bối cảnh (Threat model)

Ứng dụng xử lý: số điện thoại, email, số tài khoản ngân hàng, tên chủ tài khoản, số tiền nợ, JWT token, ảnh hóa đơn/avatar trên Cloudflare R2, và một hộp thư Gmail cá nhân dùng để gửi OTP. Ứng dụng **không giữ tiền** (đúng như quyết định thiết kế của bạn) nên rủi ro tài chính trực tiếp là thấp, nhưng rủi ro thực sự nằm ở:
- **Danh tính & tài khoản ngân hàng cá nhân bị giả mạo/đánh cắp** nếu JWT hoặc OTP bị khai thác.
- **Tài khoản Gmail cá nhân (`nang14dz@gmail.com`) và bucket R2 bị chiếm quyền** vì secret đã công khai trên GitHub — đây là tác hại ngoài phạm vi app, ảnh hưởng trực tiếp đến tài sản số cá nhân của bạn.

## Việc cần làm ngay (ưu tiên theo mức độ)

1. **Thu hồi ngay 2 secret đã lộ** (R2 Access Key + Gmail App Password) — làm trước khi làm bất kỳ việc nào khác, vì chúng đã public trên GitHub.
2. Xóa giá trị fallback hardcode trong `EmailService.cs`.
3. Thêm giới hạn 5 lần sai + cooldown 60 giây cho luồng OTP.
4. Để lại CORS mở và cleartext traffic cho môi trường dev hiện tại (LAN testing), nhưng nhắc lại rõ ràng trước khi phát hành bản thật.

## Câu hỏi còn mở

- Bạn đã thu hồi API key Cloudflare R2 và đổi mật khẩu ứng dụng Gmail từ lần audit trước chưa? Nếu chưa, đây vẫn là rủi ro đang hoạt động (active), không phải rủi ro lý thuyết.
- Bạn có muốn tôi khóa luôn lịch sử Git (xóa secret khỏi các commit cũ bằng `git filter-repo`) hay chỉ cần sửa code đi tới (secret cũ coi như đã compromised và sẽ bị thu hồi)?
- Bạn có muốn tôi áp dụng vá ngay 2 lỗi High (giới hạn OTP) trong lượt này không?
