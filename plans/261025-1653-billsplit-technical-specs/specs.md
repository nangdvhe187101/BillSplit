# TÀI LIỆU ĐẶC TẢ KỸ THUẬT CHI TIẾT (TECHNICAL SPECIFICATION)
## DỰ ÁN: BILLSPLIT AUTO (HỆ THỐNG CHIA TIỀN TỰ ĐỘNG & ĐỐI SOÁT QUA VIETQR)
- **Hệ thống:** Mobile App (Flutter) + Backend API (C# ASP.NET Core Web API)
- **Cơ sở dữ liệu:** SQL Server (Backend chính) + SQLite (Mobile Local Storage)
- **Kiến trúc:** Clean Architecture (Domain - Data - Presentation/API)

---

# PHẦN 1: MÔ HÌNH DỮ LIỆU TỔNG THỂ (DATABASE SCHEMA)

## 1. Cơ sở dữ liệu Backend (SQL Server qua EF Core)

### Bảng `Users`
| Cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
| :--- | :--- | :--- | :--- |
| `Id` | `UNIQUEIDENTIFIER` | PK, Default `NEWID()` | ID người dùng |
| `PhoneNumber` | `NVARCHAR(15)` | Unique, Not Null, Index | Số điện thoại định danh |
| `Email` | `NVARCHAR(100)` | Unique, Not Null | Email tài khoản |
| `PasswordHash` | `NVARCHAR(255)` | Not Null | Hash mật khẩu (BCrypt) |
| `FullName` | `NVARCHAR(100)` | Not Null | Họ tên hiển thị |
| `AvatarUrl` | `NVARCHAR(500)` | Nullable | Đường dẫn ảnh đại diện |
| `BankBin` | `NVARCHAR(10)` | Not Null | Mã BIN ngân hàng (Napas) |
| `BankAccountNo`| `NVARCHAR(30)` | Not Null | Số tài khoản ngân hàng nhận tiền |
| `BankAccountName`| `NVARCHAR(100)`| Not Null | Tên in hoa không dấu của chủ tài khoản |
| `FcmToken` | `NVARCHAR(255)` | Nullable | Token thiết bị nhận Push Notification |
| `CreatedAt` | `DATETIME2` | Default `SYSUTCDATETIME()` | Thời gian tạo |
| `UpdatedAt` | `DATETIME2` | Default `SYSUTCDATETIME()` | Thời gian cập nhật |

### Bảng `Banks`
| Cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
| :--- | :--- | :--- | :--- |
| `Bin` | `NVARCHAR(10)` | PK | Mã định danh Napas |
| `ShortName` | `NVARCHAR(50)` | Not Null, Index | Tên viết tắt (MBBank, TPBank, VCB...) |
| `FullName` | `NVARCHAR(150)` | Not Null | Tên đầy đủ của ngân hàng |
| `LogoUrl` | `NVARCHAR(500)` | Nullable | Đường dẫn logo ngân hàng |
| `IsSupported`| `BIT` | Default 1 | Ngân hàng hỗ trợ chuyển tiền nhanh 247 |

### Bảng `Friendships`
| Cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
| :--- | :--- | :--- | :--- |
| `Id` | `UNIQUEIDENTIFIER` | PK, Default `NEWID()` | ID mối quan hệ |
| `RequesterId`| `UNIQUEIDENTIFIER` | FK -> `Users(Id)`, Not Null | Người gửi lời mời kết bạn |
| `AddresseeId`| `UNIQUEIDENTIFIER` | FK -> `Users(Id)`, Not Null | Người nhận lời mời kết bạn |
| `Status` | `NVARCHAR(20)` | Not Null, Default `'PENDING'` | `'PENDING'`, `'ACCEPTED'`, `'BLOCKED'` |
| `CreatedAt` | `DATETIME2` | Default `SYSUTCDATETIME()` | Ngày kết bạn |
*Ràng buộc duy nhất (Unique Index):* `(RequesterId, AddresseeId)` để tránh gửi trùng lời mời.

### Bảng `Groups`
| Cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
| :--- | :--- | :--- | :--- |
| `Id` | `UNIQUEIDENTIFIER` | PK, Default `NEWID()` | ID nhóm |
| `Name` | `NVARCHAR(100)` | Not Null | Tên nhóm |
| `Category` | `NVARCHAR(50)` | Not Null | Danh mục: `'House'`, `'Trip'`, `'Food'`, `'Other'` |
| `AvatarUrl` | `NVARCHAR(500)` | Nullable | Ảnh đại diện nhóm |
| `InviteCode`| `NVARCHAR(10)` | Unique, Not Null, Index | Mã mời tham gia nhóm (6 ký tự) |
| `CreatedById`| `UNIQUEIDENTIFIER` | FK -> `Users(Id)` | Người tạo nhóm |
| `CreatedAt` | `DATETIME2` | Default `SYSUTCDATETIME()` | Ngày tạo |

### Bảng `GroupMembers`
| Cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
| :--- | :--- | :--- | :--- |
| `GroupId` | `UNIQUEIDENTIFIER` | FK -> `Groups(Id)`, PK | ID nhóm |
| `UserId` | `UNIQUEIDENTIFIER` | FK -> `Users(Id)`, PK | ID thành viên |
| `Role` | `NVARCHAR(20)` | Default `'MEMBER'` | `'OWNER'`, `'MEMBER'` |
| `JoinedAt` | `DATETIME2` | Default `SYSUTCDATETIME()` | Ngày tham gia |

### Bảng `Expenses` (Hóa đơn gốc)
| Cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
| :--- | :--- | :--- | :--- |
| `Id` | `UNIQUEIDENTIFIER` | PK, Default `NEWID()` | ID hóa đơn |
| `Title` | `NVARCHAR(150)` | Not Null | Tiêu đề hóa đơn (ví dụ: "Lẩu Haidilao") |
| `TotalAmount`| `DECIMAL(18, 2)` | Not Null, Check > 0 | Tổng tiền hóa đơn |
| `PayerId` | `UNIQUEIDENTIFIER` | FK -> `Users(Id)`, Not Null | Người đứng ra trả tiền trước (Chủ nợ) |
| `GroupId` | `UNIQUEIDENTIFIER` | FK -> `Groups(Id)`, Nullable | Nhóm liên kết (null nếu chia lẻ) |
| `Category` | `NVARCHAR(50)` | Default `'Food'` | Phân loại chi tiêu |
| `ReceiptImageUrl` | `NVARCHAR(500)` | Nullable | Ảnh chụp hóa đơn gốc |
| `CreatedAt` | `DATETIME2` | Default `SYSUTCDATETIME()` | Thời điểm tạo bill |

### Bảng `Debts` (Khoản nợ chi tiết)
| Cột | Kiểu dữ liệu | Ràng buộc | Mô tả |
| :--- | :--- | :--- | :--- |
| `Id` | `UNIQUEIDENTIFIER` | PK, Default `NEWID()` | ID khoản nợ |
| `ExpenseId` | `UNIQUEIDENTIFIER` | FK -> `Expenses(Id)`, Not Null | Thuộc hóa đơn nào |
| `CreditorId` | `UNIQUEIDENTIFIER` | FK -> `Users(Id)`, Not Null | Chủ nợ (người nhận tiền) |
| `DebtorId` | `UNIQUEIDENTIFIER` | FK -> `Users(Id)`, Nullable | Người nợ trong hệ thống |
| `CustomDebtorName` | `NVARCHAR(100)` | Nullable | Tên người nợ nhập tay (nếu không có app) |
| `DebtorPhone` | `NVARCHAR(20)` | Nullable, Index | Số điện thoại người nợ chưa có app (để tự động liên kết khi đăng ký) |
| `Amount` | `DECIMAL(18, 2)` | Not Null, Check > 0 | Số tiền cần trả |
| `DebtCode` | `NVARCHAR(10)` | Unique, Not Null, Index | Mã định danh chuyển khoản: `BS` + 5 ký tự |
| `Status` | `NVARCHAR(20)` | Default `'PENDING'` | `'PENDING'`, `'PAID'`, `'CANCELLED'` |
| `SettlementType`| `NVARCHAR(20)` | Nullable | `'AUTO'` (qua biến động số dư) hoặc `'MANUAL'` |
| `PaidAt` | `DATETIME2` | Nullable | Thời điểm thanh toán |
| `BankRawMessage`| `NVARCHAR(MAX)` | Nullable | Nội dung thông báo ngân hàng đối soát |

---

## 2. Cơ sở dữ liệu Cục bộ Mobile (SQLite qua `sqflite`)

### Bảng `pending_transactions`
```sql
CREATE TABLE pending_transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    bank_name TEXT NOT NULL,
    amount REAL NOT NULL,
    transaction_type TEXT NOT NULL, -- 'OUT' hoặc 'IN'
    raw_content TEXT NOT NULL,
    timestamp INTEGER NOT NULL,
    is_processed INTEGER DEFAULT 0 -- 0: Chưa chia, 1: Đã chia
);
```

### Bảng `local_debts` (Lưu người nợ nhập tay khi không có mạng)
```sql
CREATE TABLE local_debts (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    debtor_name TEXT NOT NULL,
    amount REAL NOT NULL,
    status TEXT DEFAULT 'PENDING',
    created_at INTEGER NOT NULL,
    paid_at INTEGER
);
```

### Bảng `bank_cache`
```sql
CREATE TABLE bank_cache (
    bin TEXT PRIMARY KEY,
    short_name TEXT NOT NULL,
    full_name TEXT NOT NULL,
    logo_url TEXT
);
```

---

# PHẦN 2: ĐẶC TẢ CHI TIẾT TỪNG MODULE CHỨC NĂNG

---

## MODULE 1: ĐĂNG KÝ, ĐĂNG NHẬP & XÁC THỰC (AUTH)

### 1. API Contract
- **POST** `/api/auth/register`
  - *Header:* `Content-Type: application/json`
  - *Request Body:*
    ```json
    {
      "phoneNumber": "0912345678",
      "email": "vana@gmail.com",
      "password": "Password123@",
      "fullName": "Nguyen Van A",
      "bankBin": "970422",
      "bankAccountNo": "0912345678",
      "bankAccountName": "NGUYEN VAN A"
    }
    ```
  - *Response (201 Created):*
    ```json
    {
      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "refreshToken": "d7a8e2b1-...",
      "user": {
        "id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
        "phoneNumber": "0912345678",
        "fullName": "Nguyen Van A",
        "email": "vana@gmail.com",
        "bankBin": "970422",
        "bankAccountNo": "0912345678",
        "bankAccountName": "NGUYEN VAN A",
        "avatarUrl": null
      }
    }
    ```
  - *Error Codes:* `400 Bad Request` (Dữ liệu validation sai), `409 Conflict` (SĐT hoặc Email đã tồn tại).

- **POST** `/api/auth/send-otp`
  - *Request Body:* `{"email": "vana@gmail.com", "purpose": "register"}` (hoặc `"forgot_password"`)
  - *Cơ chế lưu trữ:* Sử dụng `IMemoryCache` (lưu trên RAM, TTL 10 phút, không lưu DB để tránh rác hệ thống).
  - *Response (200 OK):* `{"message": "Mã xác thực OTP đã được gửi đến email của bạn."}`

- **POST** `/api/auth/verify-otp`
  - *Request Body:* `{"email": "vana@gmail.com", "otpCode": "123456", "purpose": "register"}`
  - *Response (200 OK):* `{"message": "Xác thực OTP thành công."}`

- **POST** `/api/auth/forgot-password`
  - *Request Body:* `{"email": "vana@gmail.com"}`
  - *Response (200 OK):* `{"message": "Mã xác thực OTP đã được gửi đến email của bạn."}`

- **POST** `/api/auth/reset-password`
  - *Request Body:* `{"email": "vana@gmail.com", "otpCode": "123456", "newPassword": "NewPassword123@"}`
  - *Ràng buộc:* Mật khẩu mới tối thiểu 8 ký tự, có chữ hoa, chữ thường, số, ký tự đặc biệt.

- **POST** `/api/auth/login`
  - *Request Body:*
    ```json
    {
      "identifier": "0912345678", // chấp nhận SĐT hoặc Email
      "password": "Password123@"
    }
    ```
  - *Response (200 OK):* Cấu trúc như Register.
  - *Error Codes:* `401 Unauthorized` (Sai tài khoản hoặc mật khẩu).

### 2. Quản lý State (BLoC)
- **Events:**
  - `AuthRegisterSubmitted(RegisterData data)`
  - `AuthLoginSubmitted(String identifier, String password)`
  - `AuthCheckRequested()` (kiểm tra token trong local storage khi mở app)
  - `AuthLogoutRequested()`
- **States:**
  - `AuthInitial`
  - `AuthLoading`
  - `Authenticated(User user, String token)`
  - `Unauthenticated()`
  - `AuthFailure(String errorMessage)`

### 3. Màn hình & Validation
- **Màn hình Đăng ký (`RegisterPage`):**
  - Validation SĐT: Regex `^(0[3|5|7|8|9])+([0-9]{8})$` (chính xác 10 số, đầu số hợp lệ của VN).
  - Validation Email: Regex RFC 5322 chuẩn.
  - Validation Mật khẩu: Tối thiểu 6 ký tự.
  - Validation Tên chủ thẻ: Tự động chuyển thành chữ HOA không dấu (Uppercase without accents).
  - Chọn ngân hàng: Bấm mở `BankPickerBottomSheet`.

---

## MODULE 2: HỒ SƠ CÁ NHÂN & UPLOAD AVATAR (PROFILE)

### 1. API Contract
- **GET** `/api/users/profile`
  - *Header:* `Authorization: Bearer <token>`
  - *Response (200 OK):* Thông tin User chi tiết.

- **PUT** `/api/users/profile`
  - *Request Body:*
    ```json
    {
      "fullName": "Nguyen Van A (Cap nhat)",
      "bankBin": "970423",
      "bankAccountNo": "000123456789",
      "bankAccountName": "NGUYEN VAN A"
    }
    ```
  - *Response (200 OK):* Object User đã cập nhật.

- **POST** `/api/users/avatar`
  - *Header:* `Content-Type: multipart/form-data`, `Authorization: Bearer <token>`
  - *Form-data:* `file` (JPG/PNG/WEBP, tối đa 5MB)
  - *Lưu trữ:* Tải trực tiếp lên **Cloudflare R2** bucket `sono-media` qua S3 API (`AWSSDK.S3`), trả về URL CDN công khai.
  - *Response (200 OK):*
    ```json
    {
      "message": "Tải ảnh đại diện lên Cloudflare R2 thành công.",
      "avatarUrl": "https://pub-d7674cafcb294fa88a2290f5bdb835f2.r2.dev/avatars/20261027_...jpg"
    }
    ```

### 2. Quản lý Vòng đời Ảnh Hóa đơn trên Cloudflare R2 (Receipts Auto-Cleanup)
- **Cơ chế:** Khi tạo hóa đơn chia tiền có đính kèm ảnh chụp bill, ảnh được lưu trữ trên Cloudflare R2 (`sono-media/bills/`).
- **Tự động xóa sau 14 ngày:** Worker ngầm `ReceiptCleanupBackgroundService` quét định kỳ mỗi 24 giờ. Khi toàn bộ các khoản nợ trong hóa đơn đã thanh toán xong (`DebtStatus.Paid`) và người cuối cùng trả đã qua đủ 14 ngày (`PaidAt <= DateTime.UtcNow.AddDays(-14)`), hệ thống tự động gọi API S3 xóa vĩnh viễn file ảnh khỏi Cloudflare R2 và giải phóng dung lượng, cập nhật `ReceiptImageUrl = null` trong database.

### 2. Thuật toán Xử lý Ảnh trên Mobile
1. Gọi `ImagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80)`.
2. Dùng `image_cropper` khóa tỉ lệ khung hình 1:1 (hình vuông).
3. Nén file (nếu kích thước > 1024x1024 thì scale down xuống 1024).
4. Đóng gói vào `FormData.fromMap({'file': await MultipartFile.fromFile(path)})` gửi lên Dio.

---

## MODULE 3: DANH MỤC NGÂN HÀNG VIỆT NAM (BANK DIRECTORY)

### 1. API Contract
- **GET** `/api/banks`
  - *Response (200 OK):*
    ```json
    [
      { "bin": "970422", "shortName": "MBBank", "fullName": "Ngân hàng TMCP Quân đội", "logoUrl": "https://.../mb.png" },
      { "bin": "970423", "shortName": "TPBank", "fullName": "Ngân hàng TMCP Tiên Phong", "logoUrl": "https://.../tpb.png" }
    ]
    ```

### 2. Logic Đồng bộ & Cache
- **Backend:** `VietQrSyncBackgroundService` chạy ngầm mỗi 24 giờ gọi `https://api.vietqr.io/v2/banks`, đồng bộ vào bảng `Banks` và lưu vào `IMemoryCache`.
- **Mobile:**
  - Khi app mở lần đầu: Gọi `GET /api/banks`, lưu vào bảng `bank_cache` trong SQLite.
  - Các lần sau: Đọc trực tiếp từ SQLite; hiển thị tức thời trong bottom sheet chọn ngân hàng; hỗ trợ search real-time theo `shortName` hoặc `fullName`.

---

## MODULE 4: MẠNG LƯỚI BẠN BÈ & BÙ TRỪ NỢ (FRIENDS & NET BALANCE)

### 1. API Contract
- **GET** `/api/friends`
  - *Response (200 OK):*
    ```json
    [
      {
        "friendId": "8f8b8a8b-...",
        "fullName": "Tran Van B",
        "phoneNumber": "0987654321",
        "avatarUrl": "https://...",
        "netBalance": 75000.0 // Dương: B nợ tôi 75k; Âm: Tôi nợ B
      }
    ]
    ```

- **POST** `/api/friends/add`
  - *Request Body:* `{ "phoneNumber": "0987654321" }`
  - *Response (200 OK):* `{ "message": "Gửi lời mời kết bạn thành công", "friendshipId": "..." }`
  - *Error Codes:* `404 Not Found` (SĐT chưa đăng ký app), `400 Bad Request` (Tự kết bạn với chính mình).

- **GET** `/api/friends/{friendId}/debts`
  - Lấy toàn bộ danh sách các khoản nợ chưa thanh toán giữa 2 người (để phục vụ gạch nợ hoặc xem chi tiết).

### 2. Thuật toán Tính Net Balance (SQL / LINQ)
$$\text{NetBalance} = \sum (\text{Debts mà User là Creditor, Bạn là Debtor, Status='PENDING'}) - \sum (\text{Debts mà Bạn là Creditor, User là Debtor, Status='PENDING'})$$
- Nếu `NetBalance > 0`: Bạn nợ tôi tiền $\rightarrow$ UI hiện chữ màu xanh lá `+75.000 đ`.
- Nếu `NetBalance < 0`: Tôi nợ bạn tiền $\rightarrow$ UI hiện chữ màu cam `-75.000 đ`.
- Nếu `NetBalance == 0`: Hết nợ $\rightarrow$ UI hiện chữ màu xám `0 đ`.

---

## MODULE 5: QUẢN LÝ NHÓM CHIA TIỀN (GROUP MANAGEMENT)

### 1. API Contract
- **POST** `/api/groups`
  - *Request Body:*
    ```json
    {
      "name": "Phòng trọ 302",
      "category": "House",
      "memberIds": ["guid-user-1", "guid-user-2"]
    }
    ```
  - *Response (201 Created):* Thông tin group kèm `inviteCode` (ví dụ `"PT302A"`).

- **GET** `/api/groups/{id}`
  - *Response (200 OK):*
    ```json
    {
      "id": "guid-group",
      "name": "Phòng trọ 302",
      "inviteCode": "PT302A",
      "members": [
        { "userId": "guid-user-1", "fullName": "Nguyen Van A", "role": "OWNER", "balance": 150000.0 },
        { "userId": "guid-user-2", "fullName": "Tran Van B", "role": "MEMBER", "balance": -150000.0 }
      ],
      "recentExpenses": [ ... ]
    }
    ```

- **POST** `/api/groups/join`
  - *Request Body:* `{ "inviteCode": "PT302A" }`
  - *Response (200 OK):* Gia nhập nhóm thành công.

---

## MODULE 6: LẮNG NGHE & PHÂN TÍCH THÔNG BÁO NGÂN HÀNG (NOTIFICATION LISTENER)

### 1. Cấu trúc Android Native (`NotificationListenerService`)
- Lắng nghe event `onNotificationPosted(sbn: StatusBarNotification)`.
- Trích xuất:
  - `packageName`: Gói ứng dụng (ví dụ: `com.mbmobile`, `com.tpb.mb.gprsandroid`, `com.VCB`...).
  - `title`: Tiêu đề notification.
  - `text`: Nội dung notification.
  - `postTime`: Thời điểm nhận thông báo.
- Gửi qua `MethodChannel("com.billsplit.app/notification")` về phía Flutter.

### 2. Thuật toán Universal Regex Parser
1. **Kiểm tra chiều tiền:**
   - Chiều Trừ tiền (Tiền ra - `OUT`): Chứa dấu `-`, từ khóa `tru`, `giam`, `thanh toan`, `chuyen tien`, `rut tien`, `phi`.
   - Chiều Cộng tiền (Tiền vào - `IN`): Chứa dấu `+`, từ khóa `cong`, `tang`, `nhan tu`, `chuyen den`.
2. **Bóc tách số tiền:**
   ```dart
   // Regex nhận diện tiền tệ Việt Nam (100.000, 100,000, kèm đ/VND)
   final amountRegex = RegExp(r'(?:[\+\-]\s*)?([\d]{1,3}(?:[.,]\d{3})+)');
   ```
3. **Phân nhánh xử lý:**
   - Nếu `OUT` $\rightarrow$ Insert vào SQLite `pending_transactions(bank_name, amount, 'OUT', raw_content, timestamp, 0)`.
   - Nếu `IN` $\rightarrow$ Quét mã định danh `BS[A-Z0-9]{5}` (chuyển sang Module 9).

---

## MODULE 7: TẠO BILL & CHIA TIỀN ĐA KÊNH (SMART BILL SPLIT)

### 1. API Contract
- **POST** `/api/debts/split`
  - *Header:* `Authorization: Bearer <token>`
  - *Request Body:*
    ```json
    {
      "title": "Ăn trưa lẩu dê",
      "totalAmount": 450000,
      "category": "Food",
      "groupId": null,
      "splits": [
        { "debtorUserId": "guid-user-b", "customDebtorName": null, "amount": 150000 },
        { "debtorUserId": "guid-user-c", "customDebtorName": null, "amount": 150000 },
        { "debtorUserId": null, "customDebtorName": "Anh Tuan Grab", "amount": 150000 }
      ]
    }
    ```
  - *Response (201 Created):*
    ```json
    {
      "expenseId": "guid-expense",
      "totalAmount": 450000,
      "debts": [
        { "debtId": "guid-debt-1", "debtCode": "BS7K2M", "debtorName": "Tran Van B", "amount": 150000, "status": "PENDING" },
        { "debtorName": "Anh Tuan Grab", "amount": 150000, "status": "OFFLINE" }
      ]
    }
    ```

### 2. Thuật toán Chia đều & Sửa lẻ
- **Chia đều:**
  $$\text{Số tiền mỗi người} = \lfloor \text{TotalAmount} / N \rfloor$$
  $$\text{Phần dư} = \text{TotalAmount} - (\text{Số tiền mỗi người} \times N)$$
  (Phần dư sẽ được tự động cộng vào phần của chủ nợ hoặc người đầu tiên để đảm bảo tổng đúng 100%).
- **Sửa lẻ:** Cho phép nhập `TextFormField` từng người.
  - Ràng buộc: `sum(splits.amount) == totalAmount`. Nếu lệch, hiển thị text đỏ: *"Số tiền phân bổ chênh lệch: +10.000 đ"* và disable nút Lưu.

---

## MODULE 8: TẠO MÃ VIETQR CHUẨN EMVCo TLV (QR GENERATOR)

### 1. Cấu trúc Chuỗi EMVCo Payload (TLV Format)
Chuỗi mã VietQR là một chuỗi tuần tự các khối `[Tag][Length][Value]`:

| Tag | Ý nghĩa | Quy tắc sinh giá trị |
| :--- | :--- | :--- |
| `00` | Payload Format Indicator | Cố định `01` (độ dài 2) $\rightarrow$ `000201` |
| `01` | Point of Initiation Method | `12` (Dynamic QR - có sẵn số tiền) $\rightarrow$ `010212` |
| `38` | Merchant Account Information | Sub-tags: <br>- `00`: AID Napas `A000000727`<br>- `01`: Mã Ngân hàng (Tag `00`: Mã BIN 6 số, Tag `01`: STK) <br>- `02`: Service Code `QRIBFTTA` |
| `53` | Transaction Currency | `704` (Mã tiền tệ VNĐ) $\rightarrow$ `5303704` |
| `54` | Transaction Amount | Chuỗi số nguyên tiền (ví dụ `150000`) $\rightarrow$ `5406150000` |
| `58` | Country Code | `VN` $\rightarrow$ `5802VN` |
| `62` | Additional Data Field | Sub-tag `08`: Nội dung chuyển khoản chứa mã định danh (ví dụ: `BS7K2M TRANO`) $\rightarrow$ `62170813BS7K2M TRANO` |
| `63` | CRC Checksum | Tính thuật toán CRC-16/CCITT-FALSE cho toàn bộ chuỗi từ Tag `00` đến Tag `6304`. Thêm 4 ký tự Hex vào cuối chuỗi. |

### 2. Thuật toán Tính CRC-16/CCITT-FALSE (Dart)
```dart
int calculateCrc16(List<int> bytes) {
  int crc = 0xFFFF;
  for (int b in bytes) {
    crc ^= (b << 8);
    for (int i = 0; i < 8; i++) {
      if ((crc & 0x8000) != 0) {
        crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
      } else {
        crc = (crc << 1) & 0xFFFF;
      }
    }
  }
  return crc;
}
```

---

## MODULE 9: TỰ ĐỘNG GẠCH NỢ QUA THÔNG BÁO TIỀN VÀO & THỦ CÔNG (SETTLEMENT)

### 1. Luồng Tự Động Gạch Nợ (Sequence)
```
[Máy chủ nợ]                 [App Background]           [Backend C#]             [Máy Người nợ]
     |                              |                         |                        |
(Nhận SMS/Notification MB/TPB)      |                         |                        |
     |                              |                         |                        |
     +---- onNotificationPosted --->|                         |                        |
                                    |                         |                        |
                            (Regex: BS[A-Z0-9]{5})            |                        |
                            (Match: "BS7K2M", +150k)          |                        |
                                    |                         |                        |
                                    +-- POST /api/auto-settle +                        |
                                                              |                        |
                                                      (Update Debt=PAID)               |
                                                      (Update NetBalance)              |
                                                              |                        |
                                                              +--- FCM Push Notify --->|
                                                                                       |
                                                                             ("Bill Haidilao đã
                                                                              được gạch nợ!")
```

### 2. API Contract
- **POST** `/api/debts/auto-settle`
  - *Request Body:*
    ```json
    {
      "debtCode": "BS7K2M",
      "receivedAmount": 150000,
      "rawMessage": "GD: +150,000VND vao TK 0912345678. ND: BS7K2M TRANO..."
    }
    ```
  - *Response (200 OK):*
    ```json
    {
      "success": true,
      "debtId": "guid-debt",
      "status": "PAID",
      "settledAt": "2026-10-25T17:00:00Z"
    }
    ```

- **POST** `/api/debts/{debtId}/manual-settle`
  - *Dùng khi chủ nợ bấm nút "Xác nhận đã trả" bằng tay.*

---

## MODULE 10: BÙ TRỪ CÔNG NỢ & BÁO CÁO THỐNG KÊ (DASHBOARD)

### 1. API Contract
- **GET** `/api/statistics/dashboard`
  - *Response (200 OK):*
    ```json
    {
      "totalReceivable": 650000.0, // Tổng người khác nợ mình
      "totalPayable": 200000.0,    // Tổng mình nợ người khác
      "pendingBillsCount": 4,
      "spendingByCategory": [
        { "category": "Food", "amount": 1200000, "percentage": 75.0 },
        { "category": "House", "amount": 400000, "percentage": 25.0 }
      ],
      "monthlyTrend": [
        { "month": "08/2026", "amount": 2500000 },
        { "month": "09/2026", "amount": 3100000 },
        { "month": "10/2026", "amount": 1800000 }
      ]
    }
    ```

### 2. Thư viện & Widget Render UI
- Sử dụng `fl_chart`:
  - `PieChart`: Render cơ cấu chi tiêu theo nhóm/danh mục (mỗi danh mục 1 màu riêng biệt, có legend chú thích).
  - `BarChart`: Render chi tiêu qua các tháng.
- Thẻ chỉ số SummaryCard: Sử dụng `Hero` animation và màu sắc phân định trạng thái rõ ràng (Xanh lá - Thu về / Đỏ cam - Chi trả).
