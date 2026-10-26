# TÀI LIỆU INTENT DEFINITION TOÀN DIỆN: DỰ ÁN BILLSPLIT AUTO
**Môn học:** PRM (Programming for Mobile)  
**Kiến trúc:** Mobile Flutter (Clean Architecture + BLoC + SQLite + Dio) kết hợp Backend C# (ASP.NET Core Web API + EF Core + SQL Server)

---

## MỤC LỤC TỔNG HỢP CÁC CHỨC NĂNG
1. **Module 1:** Đăng ký, Đăng nhập & Xác thực JWT (Auth & Onboarding)
2. **Module 2:** Quản lý Hồ sơ & Upload Avatar (Profile & Bank Info)
3. **Module 3:** Tra cứu Danh mục Ngân hàng Việt Nam (Bank Directory API)
4. **Module 4:** Mạng lưới Bạn bè & Tìm kiếm qua SĐT (Friend Network & Net Balance)
5. **Module 5:** Quản lý Nhóm chia tiền (Group Management)
6. **Module 6:** Lắng nghe & Bóc tách Thông báo Ngân hàng (Background Notification Listener & Parser)
7. **Module 7:** Tạo Bill & Chia tiền Đa kênh (Smart Bill Split: Bạn bè / Nhóm / Nhập tay)
8. **Module 8:** Tạo mã VietQR chuẩn EMVCo nhúng mã định danh nợ (Dynamic VietQR Generator)
9. **Module 9:** Tự động Gạch nợ qua Thông báo Tiền vào & Đối soát Thủ công (Settlement Engine)
10. **Module 10:** Bù trừ Công nợ & Thống kê Tài chính (Debt Simplification & Dashboard)

---

## CHI TIẾT INTENT DEFINITION CHO TỪNG CHỨC NĂNG

### CHỨC NĂNG 1: Đăng ký, Đăng nhập & Xác thực (Auth & Onboarding)

#### WHY — Mục Đích
- **Business Problem:** Hệ thống cần định danh chính xác người dùng để quản lý công nợ hai chiều, kết nối mạng lưới bạn bè theo số điện thoại và có ngay thông tin tài khoản ngân hàng để tạo mã QR nhận tiền mà không cần cấu hình lại nhiều lần.
- **Người dùng là ai:** Toàn bộ người dùng mới cài đặt ứng dụng hoặc người dùng quay lại đăng nhập.
- **Hậu quả nếu không làm:** Không thể liên kết các giao dịch nợ giữa người với người; không có số tài khoản để tự động sinh QR khi người khác muốn trả tiền.
- **Tiêu chí thành công:** Người dùng hoàn tất đăng ký tài khoản (kèm cấu hình tài khoản ngân hàng nhận tiền) dưới 60 giây; đăng nhập nhận JWT Token hợp lệ để gọi API.

#### WHAT — Yêu Cầu
- **Acceptance Criteria:**
  - `AC-1.1`: Người dùng đăng ký thành công khi cung cấp đủ: Họ tên, Số điện thoại (duy nhất, đúng 10 số), Email (đúng định dạng RFC 5322), Mật khẩu (tối thiểu 6 ký tự), Ngân hàng thụ hưởng (chọn từ danh sách mã BIN), Số tài khoản ngân hàng, Tên in hoa không dấu của chủ tài khoản.
  - `AC-1.2`: Khi đăng ký thành công, hệ thống tự động đăng nhập và trả về `AccessToken` (hạn 7 ngày) cùng thông tin user.
  - `AC-1.3`: Đăng nhập bằng Số điện thoại (hoặc Email) + Mật khẩu. Trả về mã lỗi 401 rõ ràng nếu sai thông tin.
  - `AC-1.4`: Token được lưu trữ an toàn trong `flutter_secure_storage`. Khi mở app, nếu token còn hạn thì tự động bypass màn Login vào thẳng Home.
- **Non-functional requirements:** Mật khẩu phải được hash bằng BCrypt trước khi lưu vào SQL Server. Token truyền tải qua HTTPS Header `Authorization: Bearer <token>`.
- **Constraints và giới hạn:** Mỗi số điện thoại chỉ được gắn với một tài khoản duy nhất.
- **Edge cases & Error states:**
  - Số điện thoại hoặc Email đã tồn tại $\rightarrow$ Báo lỗi validation tương ứng dưới ô input mà không xóa dữ liệu các trường khác.
  - Mất kết nối mạng khi bấm Đăng ký $\rightarrow$ Hiển thị snackbar cảnh báo lỗi mạng, cho phép retry.

#### HOW — Chỉ Định Kỹ Thuật
- **Tech stack & Patterns:** Flutter BLoC (`AuthBloc`), `flutter_secure_storage`, Dio Interceptor. Backend: ASP.NET Core Identity, JWT Bearer, Entity Framework Core.
- **Files cần tạo/chỉnh sửa:**
  - Mobile: `lib/features/auth/presentation/bloc/auth_bloc.dart`, `lib/features/auth/presentation/pages/register_page.dart`, `lib/features/auth/presentation/pages/login_page.dart`, `lib/core/network/dio_client.dart`.
  - Backend: `Controllers/AuthController.cs`, `Services/AuthService.cs`, `Models/User.cs`, `DTOs/RegisterDto.cs`.
- **API Contracts:**
  - `POST /api/auth/register`
    ```json
    // Request
    {
      "fullName": "Nguyen Van A",
      "phone": "0912345678",
      "email": "vana@gmail.com",
      "password": "Password123@",
      "bankBin": "970422",
      "bankAccountNo": "0912345678",
      "bankAccountName": "NGUYEN VAN A"
    }
    // Response (200 OK)
    {
      "token": "eyJhbGciOi...",
      "user": { "id": "guid", "fullName": "Nguyen Van A", "phone": "0912345678", "avatarUrl": null }
    }
    ```
  - `POST /api/auth/login`
    ```json
    // Request: { "identifier": "0912345678", "password": "Password123@" }
    // Response (200 OK): { "token": "...", "user": { ... } }
    ```
- **Performance Targets:** Thời gian phản hồi API auth < 300ms.

---

### CHỨC NĂNG 2: Quản lý Hồ sơ & Upload Avatar (Profile & Bank Info)

#### WHY — Mục Đích
- **Business Problem:** Người dùng cần linh hoạt thay đổi số tài khoản nhận tiền khi đổi ngân hàng, cập nhật ảnh đại diện để bạn bè dễ dàng nhận diện trong danh sách chia bill, tránh nhầm lẫn người nhận.
- **Người dùng là ai:** Người dùng đã có tài khoản trên hệ thống.
- **Hậu quả nếu không làm:** Nếu người dùng đổi số tài khoản ngân hàng mà không sửa được, toàn bộ mã QR sinh ra về sau sẽ chuyển tiền vào tài khoản cũ/không tồn tại.
- **Tiêu chí thành công:** Cập nhật thông tin ngân hàng thành công ngay lập tức; upload avatar hiển thị mượt mà trên toàn bộ các màn hình chia nợ.

#### WHAT — Yêu Cầu
- **Acceptance Criteria:**
  - `AC-2.1`: Cho phép xem và chỉnh sửa: Họ tên, Ngân hàng nhận tiền, Số tài khoản, Tên chủ thẻ (chặn sửa Số điện thoại để đảm bảo tính toàn vẹn định danh bạn bè).
  - `AC-2.2`: Cho phép chọn ảnh từ Thư viện hoặc chụp từ Camera qua `image_picker`.
  - `AC-2.3`: Ảnh được crop và nén tự động trên thiết bị (kích thước tối đa 1024x1024, dung lượng < 1MB) trước khi upload dạng `multipart/form-data`.
  - `AC-2.4`: Avatar mới được cập nhật ngay trên UI và cache lại qua `cached_network_image`.
- **Non-functional requirements:** Tải file qua streaming, kiểm tra định dạng file phía backend (chỉ chấp nhận JPG, JPEG, PNG, WEBP).
- **Constraints và giới hạn:** Dung lượng ảnh tải lên tối đa là 5MB.
- **Edge cases & Error states:**
  - Người dùng từ chối cấp quyền Camera/Bộ nhớ $\rightarrow$ Hiển thị popup giải thích lý do cần quyền và hướng dẫn vào Cài đặt để cấp quyền.
  - Mạng gián đoạn giữa chừng khi upload ảnh $\rightarrow$ Giữ nguyên avatar cũ, thông báo "Tải ảnh thất bại, vui lòng thử lại".

#### HOW — Chỉ Định Kỹ Thuật
- **Tech stack & Patterns:** Flutter `image_picker`, `image_cropper`, `cached_network_image`, `ProfileBloc`. Backend: ASP.NET Core `IFormFile`, lưu trữ file tĩnh tại `wwwroot/uploads/avatars/` hoặc Cloudinary.
- **Files cần tạo/chỉnh sửa:**
  - Mobile: `lib/features/profile/presentation/pages/profile_page.dart`, `lib/features/profile/presentation/bloc/profile_bloc.dart`, `lib/features/profile/data/datasources/profile_remote_datasource.dart`.
  - Backend: `Controllers/UsersController.cs`, `Services/FileStorageService.cs`.
- **API Contracts:**
  - `GET /api/users/profile` $\rightarrow$ Trả về đầy đủ profile + thông tin ngân hàng.
  - `PUT /api/users/profile` $\rightarrow$ Cập nhật `fullName`, `bankBin`, `bankAccountNo`, `bankAccountName`.
  - `POST /api/users/avatar` (Form-data: `file: [binary]`) $\rightarrow$ Trả về `{ "avatarUrl": "https://server.com/uploads/avatars/abc.jpg" }`.
- **Performance Targets:** Upload và xử lý ảnh < 1.5s trên mạng 4G tiêu chuẩn.

---

### CHỨC NĂNG 3: Tra cứu Danh mục Ngân hàng Việt Nam (Bank Directory API)

#### WHY — Mục Đích
- **Business Problem:** Người dùng không nhớ mã định danh ngân hàng (BIN code theo chuẩn Napas). Nếu để người dùng tự gõ text tự do, mã VietQR sinh ra sẽ bị sai chuẩn và app ngân hàng không quét được.
- **Người dùng là ai:** Người dùng khi đăng ký tài khoản, sửa thông tin nhận tiền hoặc tìm kiếm ngân hàng.
- **Hậu quả nếu không làm:** Tỉ lệ tạo QR thanh toán hỏng rất cao; người dùng phải tra cứu mã BIN thủ công ngoài internet.
- **Tiêu chí thành công:** Người dùng chọn được ngân hàng chỉ với 1-2 từ khóa gõ tắt (ví dụ: "MB", "TPB", "VCB") kèm logo trực quan; app hoạt động offline nhờ cache.

#### WHAT — Yêu Cầu
- **Acceptance Criteria:**
  - `AC-3.1`: Hiển thị danh sách hơn 50 ngân hàng Việt Nam gồm: Logo, Tên viết tắt (shortName), Tên đầy đủ, Mã BIN chuẩn (ví dụ: MB = 970422, TPBank = 970423).
  - `AC-3.2`: Cho phép lọc nhanh theo thời gian thực (instant search) qua text input.
  - `AC-3.3`: Backend đồng bộ và cache danh sách ngân hàng từ VietQR Open API (`https://api.vietqr.io/v2/banks`) về cơ sở dữ liệu để phục vụ app, không gọi trực tiếp API ngoài từ từng máy mobile (tránh rate limit).
  - `AC-3.4`: App Mobile cache danh mục ngân hàng vào SQLite/SharedPreferences để mở tức thì khi người dùng bấm chọn.
- **Non-functional requirements:** Dữ liệu ngân hàng ít thay đổi, áp dụng `MemoryCache` trên backend trong 24 giờ.
- **Constraints và giới hạn:** Chỉ hiển thị các ngân hàng hỗ trợ chuyển tiền nhanh Napas247.
- **Edge cases & Error states:**
  - Máy client không có mạng khi lần đầu mở màn hình chọn ngân hàng $\rightarrow$ Nếu local cache trống, hiển thị nút "Tải lại khi có mạng".

#### HOW — Chỉ Định Kỹ Thuật
- **Tech stack & Patterns:** Backend dùng `HttpClientFactory` kết hợp `IMemoryCache`. Mobile dùng `Dio` gọi API nội bộ, render danh sách bằng `ListView.builder` và `CachedNetworkImage`.
- **Files cần tạo/chỉnh sửa:**
  - Mobile: `lib/features/bank/presentation/widgets/bank_picker_dialog.dart`, `lib/features/bank/data/models/bank_model.dart`.
  - Backend: `Controllers/BanksController.cs`, `Services/VietQrSyncService.cs`.
- **API Contracts:**
  - `GET /api/banks`
    ```json
    // Response (200 OK)
    [
      { "bin": "970422", "name": "Ngân hàng TMCP Quân đội", "shortName": "MBBank", "logo": "https://.../mb.png" },
      { "bin": "970423", "name": "Ngân hàng TMCP Tiên Phong", "shortName": "TPBank", "logo": "https://.../tpb.png" }
    ]
    ```
- **Performance Targets:** Trả kết quả danh sách ngân hàng từ backend < 50ms (nhờ Memory Cache). Tìm kiếm client-side phản hồi < 16ms (60 FPS).

---

### CHỨC NĂNG 4: Mạng lưới Bạn bè & Tìm kiếm qua SĐT (Friends & Net Balance)

#### WHY — Mục Đích
- **Business Problem:** Để chia bill minh bạch, người dùng cần kết nối với nhau. Khi hai người có nhiều khoản chi tiêu qua lại (hôm nay người này trả, mai người kia trả), cần biết được con số nợ ròng cuối cùng (ai đang nợ ai bao nhiêu tiền).
- **Người dùng là ai:** Mọi người dùng muốn chia tiền với bạn bè, đồng nghiệp.
- **Hậu quả nếu không làm:** Phải nhập tay tên người nợ mỗi lần chia bill; không thể đồng bộ trạng thái nợ lên máy người kia; nợ qua nợ lại bị tính rời rạc gây khó đối soát.
- **Tiêu chí thành công:** Tìm kiếm và gửi lời mời kết bạn qua SĐT chính xác 100%; hiển thị số dư nợ bù trừ tức thì trên từng thẻ bạn bè.

#### WHAT — Yêu Cầu
- **Acceptance Criteria:**
  - `AC-4.1`: Tìm kiếm người dùng bằng Số điện thoại chính xác. Hiển thị thông tin Avatar, Tên và nút "Kết bạn".
  - `AC-4.2`: Không cho phép tự kết bạn với chính mình hoặc gửi lại lời mời khi đã là bạn bè / đang chờ phản hồi.
  - `AC-4.3`: Danh sách bạn bè hiển thị kèm trạng thái số dư nợ ròng (Net Balance):
    - Màu xanh lá: Bạn này đang nợ tôi $X$ đồng.
    - Màu cam/đỏ: Tôi đang nợ bạn này $Y$ đồng.
    - Màu xám: Cân bằng (0 đồng).
  - `AC-4.4`: Nhấn vào một người bạn sẽ mở màn hình Lịch sử nợ chi tiết giữa 2 người (danh sách từng bill, ngày tạo, lý do, trạng thái đã trả hay chưa).
- **Non-functional requirements:** Tính toán Net Balance được thực hiện bằng query aggregate phía database backend để đảm bảo hiệu năng.
- **Constraints và giới hạn:** Chỉ tìm được người dùng đã đăng ký tài khoản trên hệ thống.
- **Edge cases & Error states:**
  - Nhập SĐT chưa đăng ký app $\rightarrow$ Thông báo: "Số điện thoại chưa tham gia ứng dụng" kèm gợi ý chia sẻ link tải app.

#### HOW — Chỉ Định Kỹ Thuật
- **Tech stack & Patterns:** Flutter `FriendBloc`. Backend C# LINQ query, bảng `Friendships` (UserId, FriendId, Status) và tính toán tổng nợ từ bảng `Debts`.
- **Files cần tạo/chỉnh sửa:**
  - Mobile: `lib/features/friends/presentation/pages/friends_page.dart`, `lib/features/friends/presentation/pages/friend_detail_page.dart`, `lib/features/friends/presentation/bloc/friend_bloc.dart`.
  - Backend: `Controllers/FriendsController.cs`, `Services/FriendService.cs`, `Models/Friendship.cs`.
- **API Contracts:**
  - `GET /api/friends`: Lấy danh sách bạn bè kèm net balance.
    ```json
    [
      {
        "friendId": "guid-user-b",
        "fullName": "Tran Van B",
        "phone": "0987654321",
        "avatarUrl": "https://...",
        "netBalance": 75000 // Dương: B nợ mình 75k; Âm: Mình nợ B
      }
    ]
    ```
  - `POST /api/friends/add`: Body `{ "phone": "0987654321" }`.
- **Performance Targets:** Query danh sách bạn bè kèm số dư nợ < 200ms cho danh sách 100 bạn bè.

---

### CHỨC NĂNG 5: Quản lý Nhóm chia tiền (Group Management)

#### WHY — Mục Đích
- **Business Problem:** Các khoản chi tiêu thường diễn ra theo ngữ cảnh nhóm cố định (ví dụ: nhóm bạn cùng phòng ăn uống hàng ngày, nhóm đồng nghiệp ăn trưa công ty, nhóm đi du lịch). Chia theo từng cá nhân rời rạc rất mất thời gian.
- **Người dùng là ai:** Nhóm bạn, thành viên phòng trọ, đồng nghiệp.
- **Hậu quả nếu không làm:** Mỗi lần đi ăn chung 5 người, chủ nợ phải ngồi tick chọn từng người một cách thủ công, dễ bỏ sót thành viên.
- **Tiêu chí thành công:** Tạo nhóm trong 10 giây; chia 1 hóa đơn cho toàn bộ nhóm chỉ với 1 lần bấm chọn nhóm.

#### WHAT — Yêu Cầu
- **Acceptance Criteria:**
  - `AC-5.1`: Người dùng tạo được nhóm mới với: Tên nhóm, Loại nhóm (Nhà trọ, Chuyến đi, Ăn uống, Khác), Ảnh đại diện nhóm (tùy chọn).
  - `AC-5.2`: Thêm thành viên vào nhóm từ Danh sách bạn bè đã có sẵn.
  - `AC-5.3`: Mỗi nhóm có một Mã mời (Invite Code - 6 ký tự). Người dùng có thể nhập mã mời để tự tham gia nhóm mà không cần chủ nhóm add tay.
  - `AC-5.4`: Trang chi tiết nhóm hiển thị:
    - Bảng cân đối tài chính nhóm: Ai đã chi bao nhiêu, ai đang nợ bao nhiêu trong nhóm này.
    - Lịch sử các bill đã chia trong nhóm.
  - `AC-5.5`: Cho phép thành viên rời nhóm nếu số dư nợ cá nhân trong nhóm bằng 0.
- **Non-functional requirements:** Toàn vẹn dữ liệu: Ràng buộc khóa ngoại `GroupId` trong các bảng `Expenses` và `GroupMembers`.
- **Constraints và giới hạn:** Mỗi nhóm có tối thiểu 2 thành viên, tối đa 50 thành viên.
- **Edge cases & Error states:**
  - Người dùng bấm rời nhóm khi vẫn đang nợ tiền nhóm $\rightarrow$ Chặn hành động và hiện popup: "Bạn cần thanh toán hết các khoản nợ trong nhóm trước khi rời nhóm".

#### HOW — Chỉ Định Kỹ Thuật
- **Tech stack & Patterns:** Flutter `GroupBloc`. Backend: EF Core quan hệ n-n giữa `Users` và `Groups` qua bảng liên kết `GroupMembers`.
- **Files cần tạo/chỉnh sửa:**
  - Mobile: `lib/features/groups/presentation/pages/groups_page.dart`, `lib/features/groups/presentation/pages/group_detail_page.dart`, `lib/features/groups/presentation/pages/create_group_page.dart`.
  - Backend: `Controllers/GroupsController.cs`, `Services/GroupService.cs`, `Models/Group.cs`, `Models/GroupMember.cs`.
- **API Contracts:**
  - `POST /api/groups`: Tạo nhóm `{ "name": "Team Ăn Trưa", "category": "Food", "memberIds": ["guid-1", "guid-2"] }`.
  - `GET /api/groups/{id}`: Trả về thông tin nhóm, danh sách thành viên và bảng công nợ thành viên.
  - `POST /api/groups/join`: Tham gia nhóm qua mã `{ "inviteCode": "TRUA30" }`.
- **Performance Targets:** Lấy dữ liệu chi tiết nhóm và tính toán số dư thành viên < 250ms.

---

### CHỨC NĂNG 6: Lắng nghe & Bóc tách Thông báo Ngân hàng (Background Notification Listener & Parser)

#### WHY — Mục Đích
- **Business Problem:** Trở ngại lớn nhất của các app chia tiền là người trả tiền lười gõ lại số tiền vừa chi tiêu vào app. Sau khi quẹt thẻ hay chuyển khoản ở quán ăn, thông báo ngân hàng đã hiển thị ngay trên điện thoại nhưng dữ liệu bị bỏ phí.
- **Người dùng là ai:** Người thường xuyên đứng ra thanh toán bằng tài khoản ngân hàng trên điện thoại Android.
- **Hậu quả nếu không làm:** Người dùng phải mở app ngân hàng xem lại số tiền, rồi mở lại app chia nợ để gõ tay $\rightarrow$ Rất dễ nản và bỏ không dùng app sau vài ngày.
- **Tiêu chí thành công:** Bắt được 100% thông báo biến động số dư từ các app ngân hàng trên máy; tự động trích xuất đúng số tiền, chiều giao dịch (+/-) và lưu vào mục "Giao dịch chờ chia" trong SQLite cục bộ trong vòng 1 giây.

#### WHAT — Yêu Cầu
- **Acceptance Criteria:**
  - `AC-6.1`: Khởi chạy Android Service kế thừa `NotificationListenerService` ngay khi thiết bị khởi động hoặc khi mở app.
  - `AC-6.2`: Lọc thông báo dựa trên danh sách package name ngân hàng phổ biến (MBBank: `com.mbmobile`, TPBank: `com.tpb.mb.gprsandroid`, Vietcombank: `com.VCB`, Techcombank, VPBank, ACB, BIDV...) hoặc text chứa từ khóa: "Biến động số dư", "GD", "VND", "VNĐ", "số dư".
  - `AC-6.3`: Bộ phân tích tổng quát (Universal Parser) trích xuất thành công:
    - Chiều tiền: Trừ tiền (tiền ra) hoặc Cộng tiền (tiền vào).
    - Số tiền: Parse regex dạng `120,000VND`, `120.000d`, `50,000 đ`.
    - Thời gian: Lấy timestamp của thông báo.
    - Nội dung giao dịch thô.
  - `AC-6.4`: Nếu là giao dịch **Trừ tiền** $\rightarrow$ Lưu vào bảng `PendingTransactions` trong SQLite cục bộ để người dùng chọn chia bill sau này.
  - `AC-6.5`: Nếu là giao dịch **Cộng tiền** $\rightarrow$ Chuyển sang Engine Đối soát (Module 9) để tìm mã gạch nợ.
- **Non-functional requirements:** Chạy ngầm tốn ít pin (< 1% pin/ngày). Đảm bảo quyền riêng tư tuyệt đối: Không gửi nội dung thông báo thô lên server khi chưa có sự xác nhận của người dùng.
- **Constraints và giới hạn:** Chỉ hỗ trợ hệ điều hành Android (do iOS bảo mật sandbox không cho phép ứng dụng bên thứ 3 đọc thông báo của hệ thống).
- **Edge cases & Error states:**
  - Người dùng chưa cấp quyền "Truy cập thông báo" $\rightarrow$ Hiển thị thanh cảnh báo đỏ trên trang chủ kèm nút "Cấp quyền ngay" dẫn thẳng vào cài đặt hệ thống.
  - Thông báo quảng cáo/khuyến mãi từ app ngân hàng (không phải biến động số dư) $\rightarrow$ Parser bỏ qua an toàn nếu không trích xuất được số tiền và dấu +/-.

#### HOW — Chỉ Định Kỹ Thuật
- **Tech stack & Patterns:** Android Native Kotlin (`NotificationListenerService`, `MethodChannel` kết nối Flutter), Strategy Pattern cho Parser, SQLite local database (`sqflite`).
- **Files cần tạo/chỉnh sửa:**
  - Android: `android/app/src/main/kotlin/.../BankNotificationListener.kt`, `AndroidManifest.xml` (khai báo Service và quyền `BIND_NOTIFICATION_LISTENER_SERVICE`).
  - Mobile: `lib/core/services/notification_service.dart`, `lib/core/utils/universal_bank_parser.dart`, `lib/features/transactions/data/datasources/transaction_local_datasource.dart`.
- **Cấu trúc Dữ liệu SQLite (`PendingTransactions`):**
  - `id` (INTEGER PRIMARY KEY AUTOINCREMENT)
  - `bankName` (TEXT)
  - `amount` (REAL)
  - `type` (TEXT: 'OUT' hoặc 'IN')
  - `rawContent` (TEXT)
  - `timestamp` (INTEGER)
  - `isProcessed` (INTEGER: 0 hoặc 1)
- **Performance Targets:** Bóc tách regex và ghi vào SQLite < 100ms kể từ khi notification xuất hiện.

---

### CHỨC NĂNG 7: Tạo Bill & Chia tiền Đa kênh (Smart Bill Split)

#### WHY — Mục Đích
- **Business Problem:** Sau khi thanh toán, chủ nợ cần chia tiền nhanh chóng cho nhiều đối tượng khác nhau: bạn bè đã có app, thành viên trong nhóm, hoặc cả những người chưa cài app (người ngoài, khách vãng lai).
- **Người dùng là ai:** Chủ nợ (người vừa thanh toán hóa đơn).
- **Hậu quả nếu không làm:** Nếu app bắt buộc 100% mọi người đều phải cài app mới cho chia bill thì sẽ bị tẩy chay khi đi ăn có 1-2 người lạ không cài app.
- **Tiêu chí thành công:** Hoàn tất 1 bill chia tiền cho 5 người trong vòng 15 giây; hỗ trợ cả bạn bè lẫn người nhập tay; tự động kiểm tra tổng tiền chính xác tuyệt đối.

#### WHAT — Yêu Cầu
- **Acceptance Criteria:**
  - `AC-7.1`: Cho phép tạo bill từ 2 nguồn: (1) Chọn từ danh sách "Giao dịch chờ" do Module 6 tự bắt được, hoặc (2) Bấm "+" tự gõ số tiền thủ công (cho giao dịch tiền mặt).
  - `AC-7.2`: Chọn đối tượng chia linh hoạt:
    - Chọn 1 Nhóm cụ thể $\rightarrow$ Tự động add toàn bộ thành viên nhóm vào danh sách chia.
    - Chọn từng Bạn bè từ danh bạ app.
    - Nhập tay tên người ngoài chưa cài app (ví dụ: "Anh Tuấn Grab", "Bảo bạn Nam").
  - `AC-7.3`: Cơ chế chia tiền:
    - Mặc định: Chia đều cho $N$ người (làm tròn số nguyên đồng, phần lẻ cộng dồn cho chủ nợ).
    - Tùy chỉnh: Cho phép sửa trực tiếp số tiền từng người.
    - Validate bắt buộc: $\sum \text{Tiền từng người} == \text{Tổng tiền hóa đơn}$. Nếu lệch, nút Lưu bị disable và hiển thị cảnh báo đỏ số tiền chênh lệch.
  - `AC-7.4`: Sau khi bấm Lưu:
    - Với người dùng app: Đẩy dữ liệu lên backend C# tạo các bản ghi `Debt`, sinh mã định danh duy nhất `BSxxxxx`.
    - Với người ngoài nhập tay: Lưu trực tiếp vào SQLite trên máy chủ nợ với trạng thái nợ offline.
- **Non-functional requirements:** Đảm bảo tính Transaction (ACID) trên C# Backend: Nếu tạo nợ cho 1 người thất bại thì rollback toàn bộ bill.
- **Constraints và giới hạn:** Một bill hỗ trợ tối đa 50 người chia.
- **Edge cases & Error states:**
  - Nhập số tiền từng người có giá trị âm $\rightarrow$ Báo lỗi Form Validation "Số tiền không hợp lệ".

#### HOW — Chỉ Định Kỹ Thuật
- **Tech stack & Patterns:** Flutter `SplitBillBloc`, Clean Architecture. Backend: ASP.NET Core `DbTransaction` với EF Core.
- **Files cần tạo/chỉnh sửa:**
  - Mobile: `lib/features/split/presentation/pages/split_bill_page.dart`, `lib/features/split/presentation/widgets/member_split_item.dart`, `lib/features/split/presentation/bloc/split_bill_bloc.dart`.
  - Backend: `Controllers/DebtsController.cs`, `Services/DebtService.cs`, `Models/Expense.cs`, `Models/Debt.cs`.
- **API Contracts:**
  - `POST /api/debts/split`
    ```json
    // Request
    {
      "title": "Ăn trưa lẩu Haidilao",
      "totalAmount": 600000,
      "groupId": null, // hoặc guid nếu chia trong nhóm
      "splits": [
        { "debtorUserId": "guid-user-b", "customDebtorName": null, "amount": 200000 },
        { "debtorUserId": "guid-user-c", "customDebtorName": null, "amount": 200000 },
        { "debtorUserId": null, "customDebtorName": "Anh Nam", "amount": 200000 }
      ]
    }
    // Response (201 Created)
    {
      "expenseId": "guid-expense",
      "debts": [
        { "debtId": "guid-debt-1", "debtCode": "BS8K2M", "amount": 200000, "status": "PENDING" },
        ...
      ]
    }
    ```
- **Performance Targets:** Xử lý chia bill và lưu trữ backend < 300ms.

---

### CHỨC NĂNG 8: Tạo mã VietQR chuẩn EMVCo nhúng mã định danh nợ (Dynamic VietQR Generator)

#### WHY — Mục Đích
- **Business Problem:** Khi người nợ muốn trả tiền, họ phải hỏi: "Mày dùng ngân hàng gì, đọc số tài khoản, tao chuyển bao nhiêu, ghi nội dung gì?". Quá trình này phiền toái, dễ nhầm số tài khoản, và người chuyển hay quên ghi nội dung để đối soát.
- **Người dùng là ai:** Người nợ (tự mở QR trên app của mình để quét chuyển khoản) hoặc Chủ nợ (mở QR trên máy mình đưa cho người nợ quét).
- **Hậu quả nếu không làm:** Chuyển nhầm người nhận; người chuyển gõ sai nội dung khiến không thể nhận diện được khoản tiền vào.
- **Tiêu chí thành công:** Tạo mã QR hoàn toàn OFFLINE trên thiết bị theo chuẩn VietQR Napas247; app ngân hàng bất kỳ quét vào là tự điền đúng: Ngân hàng, Số tài khoản, Số tiền, và Nội dung có mã `BSxxxxx`.

#### WHAT — Yêu Cầu
- **Acceptance Criteria:**
  - `AC-8.1`: Tự encode chuỗi Payload chuẩn **EMVCo QR Code (TLV - Tag Length Value)** bao gồm:
    - Tag `00`: Payload Format Indicator (`01`).
    - Tag `01`: Point of Initiation Method (`12` - Dynamic QR).
    - Tag `38`: Merchant Account Info (Chứa GUID VietQR `A000000727`, Mã BIN ngân hàng chủ nợ, Số tài khoản chủ nợ).
    - Tag `53`: Transaction Currency (`704` - VNĐ).
    - Tag `54`: Transaction Amount (Số tiền nợ chính xác, ví dụ `200000`).
    - Tag `58`: Country Code (`VN`).
    - Tag `62`: Additional Data Field (Chứa Tag `08` - Purpose of Transaction: `BS8K2M TRANO`).
    - Tag `63`: CRC Checksum (Tính thuật toán CRC-16/CCITT-FALSE 4 ký tự hexa cuối chuỗi).
  - `AC-8.2`: Render chuỗi thành hình ảnh QR rõ nét bằng thư viện `qr_flutter`.
  - `AC-8.3`: Màn hình thanh toán hiển thị: Ảnh QR, Logo ngân hàng, Tên chủ thẻ, Số tài khoản, Số tiền, Nội dung chuyển khoản kèm nút "Sao chép".
  - `AC-8.4`: Cho phép chụp/lưu ảnh QR về thư viện máy hoặc chia sẻ qua Zalo/Messenger cho người nợ ngoài app.
- **Non-functional requirements:** Hoạt động 100% offline, không phụ thuộc vào internet hay API bên thứ 3 (như vietqr.io).
- **Constraints và giới hạn:** Mã nội dung định danh `BSxxxxx` luôn bắt đầu bằng `BS` + 5 ký tự ngẫu nhiên in hoa (độ dài 7 ký tự).
- **Edge cases & Error states:**
  - Chủ nợ chưa cấu hình số tài khoản trong profile $\rightarrow$ Hiện thông báo yêu cầu cập nhật thông tin ngân hàng trước khi mở QR.

#### HOW — Chỉ Định Kỹ Thuật
- **Tech stack & Patterns:** Flutter `qr_flutter`, thuật toán tự viết `VietQrEncoder` (xử lý TLV và CRC16).
- **Files cần tạo/chỉnh sửa:**
  - Mobile: `lib/core/utils/vietqr_encoder.dart`, `lib/core/utils/crc16.dart`, `lib/features/payment/presentation/pages/qr_payment_page.dart`.
- **Cấu trúc thuật toán mã hóa EMVCo:**
  ```dart
  class VietQrEncoder {
    static String generate({
      required String bankBin,
      required String accountNo,
      required double amount,
      required String memo, // ví dụ "BS8K2M TRANO"
    }) {
      // Build TLV string và gán CRC16 ở Tag 63
    }
  }
  ```
- **Performance Targets:** Thời gian tạo chuỗi EMVCo và render QR trên màn hình < 50ms.

---

### CHỨC NĂNG 9: Tự động Gạch nợ qua Thông báo Tiền vào & Đối soát Thủ công (Settlement Engine)

#### WHY — Mục Đích
- **Business Problem:** Khi người nợ chuyển khoản trả tiền, chủ nợ thường không để ý hoặc phải mất công mở app ngân hàng check xem tiền đã vào chưa rồi mới nhớ tick vào sổ nợ. Nếu quên tick, hôm sau lại đòi nợ người ta gây ngại ngùng.
- **Người dùng là ai:** Chủ nợ và Người nợ.
- **Hậu quả nếu không làm:** Dữ liệu nợ bị sai lệch so với thực tế tài khoản ngân hàng; mất đi tính tự động thông minh của ứng dụng.
- **Tiêu chí thành công:** Tự động chuyển trạng thái khoản nợ từ "Chờ thanh toán" sang "Đã trả" trong vòng 3 giây ngay khi điện thoại chủ nợ nhận thông báo tiền vào có chứa mã `BSxxxxx`.

#### WHAT — Yêu Cầu
- **Acceptance Criteria:**
  - `AC-9.1`: Khi `NotificationListenerService` bắt được thông báo biến động số dư **Cộng tiền (+)** trên máy chủ nợ:
    - Quét nội dung thông báo bằng Regex: `\bBS[A-Z0-9]{5}\b`.
    - Nếu tìm thấy mã (ví dụ `BS8K2M`), gọi API Backend C# `POST /api/debts/auto-settle` gửi mã này và số tiền nhận được lên server.
  - `AC-9.2`: Backend kiểm tra mã `BS8K2M`:
    - Nếu tồn tại khoản nợ tương ứng đang ở trạng thái `PENDING` và số tiền nhận $\ge$ số tiền nợ $\rightarrow$ Cập nhật trạng thái thành `PAID`, ghi nhận thời gian thanh toán.
    - Bắn Firebase Cloud Messaging (FCM) thông báo cho máy Người nợ: *"Khoản nợ 200.000đ cho bill Haidilao đã được thanh toán thành công"*.
  - `AC-9.3`: **Đối soát thủ công (Fallback):**
    - Luôn có nút "Xác nhận đã trả" dành cho chủ nợ bấm tay.
    - Áp dụng khi: Người nợ trả tiền mặt, người ngoài app trả tiền, hoặc người chuyển khoản lỡ tay xóa mất mã `BSxxxxx` khi chuyển tiền.
  - `AC-9.4`: Lịch sử nợ cập nhật thời gian gạch nợ và phương thức gạch nợ (Tự động qua MB/TPBank hay Thủ công).
- **Non-functional requirements:** Idempotency: Nếu thông báo ngân hàng bị bắn lặp lại 2 lần, backend chỉ xử lý gạch nợ duy nhất 1 lần, không sinh lỗi logic.
- **Constraints và giới hạn:** Tự động gạch nợ chỉ kích hoạt khi thông báo tiền vào xuất hiện trên chính điện thoại của chủ nợ đang cài app.
- **Edge cases & Error states:**
  - Người nợ chuyển thiếu tiền (nợ 200k nhưng chỉ chuyển 100k) $\rightarrow$ Không tự gạch nợ tự động, gửi push notification cảnh báo chủ nợ kiểm tra thủ công.

#### HOW — Chỉ Định Kỹ Thuật
- **Tech stack & Patterns:** Android `NotificationListenerService`, Flutter BLoC, C# Web API, Firebase Admin SDK (Push Notification).
- **Files cần tạo/chỉnh sửa:**
  - Mobile: `lib/core/services/auto_settlement_handler.dart`, `lib/features/debts/presentation/widgets/debt_item_card.dart`.
  - Backend: `Controllers/DebtsController.cs`, `Services/SettlementService.cs`, `Services/FcmPushService.cs`.
- **API Contracts:**
  - `POST /api/debts/auto-settle`
    ```json
    // Request (từ máy chủ nợ)
    {
      "debtCode": "BS8K2M",
      "receivedAmount": 200000,
      "bankRawMessage": "+200,000VND luc 12:30. ND: BS8K2M TRANO..."
    }
    // Response (200 OK)
    {
      "success": true,
      "debtId": "guid-debt",
      "status": "PAID",
      "message": "Khoản nợ đã được gạch tự động thành công."
    }
    ```
  - `POST /api/debts/{id}/manual-settle` $\rightarrow$ Xác nhận thủ công bằng nút bấm.
- **Performance Targets:** Thời gian từ lúc thông báo tiền vào hiển thị đến khi app đổi trạng thái nợ < 3 giây.

---

### CHỨC NĂNG 10: Bù trừ Công nợ & Thống kê Tài chính (Debt Simplification & Dashboard)

#### WHY — Mục Đích
- **Business Problem:** Nhóm bạn bè sinh hoạt lâu dài sẽ phát sinh ma trận nợ chéo phức tạp (A nợ B, B nợ C, C nợ A). Người dùng cần cái nhìn tổng quan về sức khỏe tài chính: "Cuối cùng thì mình đang âm hay dương bao nhiêu tiền?" và muốn tối giản số lần chuyển khoản.
- **Người dùng là ai:** Toàn bộ người dùng muốn kiểm soát tài chính cá nhân và nhóm.
- **Hậu quả nếu không làm:** Mọi người phải chuyển khoản lòng vòng nhiều lần; không có bức tranh tổng thể về chi tiêu chung.
- **Tiêu chí thành công:** Màn hình Dashboard hiển thị trực quan tổng tài sản nợ/có; thuật toán tự động bù trừ nợ 2 chiều giữa từng cặp người dùng chính xác 100%.

#### WHAT — Yêu Cầu
- **Acceptance Criteria:**
  - `AC-10.1`: Trang chủ (Dashboard) hiển thị 2 thẻ chỉ số nổi bật:
    - **"Người khác nợ bạn"** (Tổng tiền bạn cần thu hồi - Màu xanh lá).
    - **"Bạn đang nợ"** (Tổng tiền bạn cần thanh toán - Màu cam/đỏ).
  - `AC-10.2`: Biểu đồ trực quan (sử dụng thư viện `fl_chart`):
    - Biểu đồ tròn: Tỉ lệ chi tiêu theo danh mục (Ăn uống, Mua sắm, Di chuyển, Khác).
    - Biểu đồ cột: Biến động tổng số tiền chia bill qua các tuần/tháng.
  - `AC-10.3`: Thuật toán cấn trừ nợ 2 chiều giữa 2 người:
    - Nếu A nợ B 100k, B nợ A 60k $\rightarrow$ Hệ thống tự động triệt tiêu còn: A nợ B 40k.
    - Khi A thanh toán 40k $\rightarrow$ Cả 2 đều hết nợ nhau.
  - `AC-10.4`: Bộ lọc danh sách nợ linh hoạt: Lọc theo Trạng thái (Đang nợ, Đã trả), lọc theo Nhóm, hoặc lọc theo Tên bạn bè.
- **Non-functional requirements:** Tối ưu hóa UI mượt mà, render biểu đồ không bị giật lag khi chuyển tab.
- **Constraints và giới hạn:** Thuật toán bù trừ áp dụng trực tiếp cho từng cặp 2 người (2-way simplification).
- **Edge cases & Error states:**
  - Người dùng mới chưa có giao dịch nào $\rightarrow$ Hiển thị màn hình rỗng (Empty State) với hình minh họa thân thiện và nút "Tạo bill đầu tiên".

#### HOW — Chỉ Định Kỹ Thuật
- **Tech stack & Patterns:** Flutter `fl_chart`, `DashboardBloc`. Backend C# thuật toán tính toán tổng hợp công nợ.
- **Files cần tạo/chỉnh sửa:**
  - Mobile: `lib/features/dashboard/presentation/pages/dashboard_page.dart`, `lib/features/dashboard/presentation/widgets/summary_card.dart`, `lib/features/dashboard/presentation/widgets/expense_pie_chart.dart`.
  - Backend: `Controllers/StatisticsController.cs`, `Services/StatisticsService.cs`.
- **API Contracts:**
  - `GET /api/statistics/dashboard`
    ```json
    // Response (200 OK)
    {
      "totalReceivable": 450000, // Người khác nợ mình
      "totalPayable": 120000,    // Mình nợ người khác
      "pendingBillsCount": 3,
      "categoryExpenses": [
        { "category": "Food", "amount": 850000, "percentage": 70.8 },
        { "category": "Transport", "amount": 350000, "percentage": 29.2 }
      ]
    }
    ```
- **Performance Targets:** Load toàn bộ dữ liệu thống kê Dashboard < 200ms.
