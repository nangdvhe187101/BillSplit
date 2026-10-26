# BÁO CÁO CẬP NHẬT KẾ HOẠCH & ĐẶC TẢ KỸ THUẬT (PLAN & SPEC UPDATE)
**Dự án:** Sổ Nợ (BillSplit Smart Ledger)  
**Ngày cập nhật:** 27/10/2026  
**Mục tiêu:** Đồng bộ toàn diện các thay đổi kiến trúc, tính năng bảo mật, lưu trữ đám mây và trải nghiệm người dùng thực tế vào hệ thống tài liệu Kế hoạch (Plans) và Đặc tả Kỹ thuật (Technical Specs).

---

## 1. TỔNG HỢP CÁC NỘI DUNG ĐÃ ĐƯỢC CẬP NHẬT VÀO PLAN

### A. Chuẩn hóa Bản chất Ứng dụng: "Sổ Nợ Thông Minh" (Không phải Ví Điện Tử)
- **Vấn đề cốt lõi:** Ứng dụng đóng vai trò là sổ ghi chép, chia tiền và đối soát giao dịch VietQR trung gian giữa các cá nhân, **hoàn toàn không giữ hoặc quản lý số dư tiền mặt** của người dùng.
- **Thay đổi giao diện & nghiệp vụ:**
  - Loại bỏ hoàn toàn khái niệm gây hiểu lầm "Số dư ròng".
  - Chuẩn hóa thành 2 chỉ số thực tế:
    - **Mọi người đang nợ bạn** *(Tổng các khoản người khác cần thanh toán cho bạn qua VietQR)*.
    - **Bạn đang nợ người khác** *(Tổng các khoản bạn cần chuyển khoản trả cho bạn bè)*.
  - Phím tắt Trang chủ đổi từ "Chuyển tiền cho B" thành **"QR nhận tiền"** (hiển thị mã VietQR tài khoản ngân hàng cá nhân của chính người dùng, không gán cứng nợ mẫu).

### B. Tích hợp Lưu trữ Cloudflare R2 & Cơ chế Tự động Dọn dẹp Hóa đơn (14 Ngày)
- **Nhà cung cấp:** Cloudflare R2 Object Storage (chuẩn S3 API qua thư viện `AWSSDK.S3`).
  - **Bucket:** `sono-media`
  - **S3 Endpoint:** `https://afd1bfe18e075fda7233a80fd8082a10.r2.cloudflarestorage.com`
  - **Public CDN:** `https://pub-d7674cafcb294fa88a2290f5bdb835f2.r2.dev`
- **Ảnh đại diện (Avatar):** Tải lên thư mục `avatars/` qua `POST /api/users/avatar`, tự động cập nhật URL CDN vào hồ sơ người dùng.
- **Tự động xóa ảnh hóa đơn sau 2 tuần:**
  - Dịch vụ nền `ReceiptCleanupBackgroundService` chạy định kỳ 24 giờ.
  - Điều kiện xóa: Khi tất cả các khoản nợ trong hóa đơn đã thanh toán xong (`DebtStatus.Paid`) và thời điểm người cuối cùng thanh toán đã qua đủ 14 ngày (`PaidAt <= DateTime.UtcNow.AddDays(-14)`).
  - Tự động gọi API S3 xóa vĩnh viễn file trên R2 và gán `ReceiptImageUrl = null` trong database.

### C. Xác thực Email OTP, Quên mật khẩu & Bảo mật Tài khoản
- **Cơ chế OTP qua Gmail SMTP:**
  - Gửi mã xác thực từ `nang14dz@gmail.com` bằng App Password an toàn.
  - **Lưu trữ bộ nhớ tạm (In-Memory Cache):** Mã OTP 6 chữ số được lưu độc quyền trên RAM qua `IMemoryCache` với thời hạn chính xác **10 phút**. Tuyệt đối không lưu vào Database để chống spam tài khoản rác và tối ưu hiệu năng.
- **Quy trình Quên mật khẩu:**
  - `POST /api/auth/send-otp` (gửi OTP đăng ký hoặc quên mật khẩu).
  - `POST /api/auth/verify-otp` (xác thực mã).
  - `POST /api/auth/forgot-password` và `POST /api/auth/reset-password` (đặt lại mật khẩu mới).
- **Chính sách mật khẩu mạnh:**
  - Regex bắt buộc tối thiểu 8 ký tự, bao gồm ít nhất 1 chữ hoa, 1 chữ thường, 1 chữ số và 1 ký tự đặc biệt.

### D. Đồng bộ Nợ Bạn bè Chưa Cài App & Phản hồi Tra cứu
- **Chia tiền cho bạn bè chưa có app:**
  - Bổ sung trường `DebtorPhone` vào entity `Debt`.
  - Người dùng có thể ghi nhận nợ cho bạn bè bằng số điện thoại.
  - Ngay khi người bạn đó tải app và đăng ký tài khoản bằng số điện thoại này, hệ thống `AuthService` sẽ tự động liên kết (`DebtorId = newUser.Id`) toàn bộ các khoản nợ lịch sử vào tài khoản mới.
- **Phản hồi tra cứu số điện thoại:**
  - Khi thêm bạn bè, nếu số điện thoại chưa tồn tại, hệ thống phản hồi cảnh báo rõ ràng: `"Không tìm thấy người dùng có số điện thoại này trong hệ thống."`.

### E. Chế độ Trải nghiệm Khách (Guest Mode) & Điều hướng
- Người dùng chưa đăng nhập có thể truy cập trực tiếp Trang chủ và công cụ chia tiền tự động (`/split`).
- Nút "Đăng nhập" thân thiện hiển thị trên thanh điều hướng thay vì biểu tượng đăng xuất đỏ.
- Bổ sung nút quay lại (Back) từ màn hình Đăng nhập để khách có thể quay lại Trang chủ dễ dàng.

---

## 2. DANH SÁCH TÀI LIỆU PLAN ĐÃ CẬP NHẬT TRONG REPO

1. **`plans/261025-1653-billsplit-technical-specs/specs.md`**:
   - Cập nhật cấu trúc bảng `Debts` (thêm trường `DebtorPhone`).
   - Cập nhật Module 1: Thêm 4 endpoint API liên quan đến OTP và Quên mật khẩu; chính sách mật khẩu mạnh.
   - Cập nhật Module 2: Thêm đặc tả upload Avatar lên Cloudflare R2; đặc tả cơ chế tự động dọn dẹp hóa đơn sau 14 ngày của `ReceiptCleanupBackgroundService`.
2. **`plans/261025-1643-billsplit-intent-definition/intent-definitions.md`**:
   - Đồng bộ hóa mục tiêu thiết kế sổ nợ trung gian và trải nghiệm khách trải nghiệm (Guest Mode).
3. **`mobile/plans/reports/plan-update-261027-0054-smart-ledger-sync.md`**:
   - Báo cáo tổng kết hiện trạng và nghiệm thu kiến trúc.

---

## 3. TRẠNG THÁI BUILD VÀ MÃ NGUỒN
- **Backend:** `BillSplit.Api` build thành công tuyệt đối (**0 Warning, 0 Error**).
- **Môi trường Test Thực tế:** Đã cấu hình cổng `5206` trên IP mạng LAN nội bộ, sẵn sàng cho việc kiểm thử trên điện thoại thật (Samsung Galaxy A73 5G) và tích hợp các ứng dụng ngân hàng số (TPBank, VietinBank, MBBank).
