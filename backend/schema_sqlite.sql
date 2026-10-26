-- ==============================================================================
-- DỰ ÁN: BILLSPLIT AUTO (CƠ SỞ DỮ LIỆU SQLITE CHUẨN)
-- Tương thích 100% với: DB Browser for SQLite, SQLiteStudio, DBeaver, VS Code
-- File cơ sở dữ liệu: billsplit.db
-- ==============================================================================

PRAGMA foreign_keys = ON;

-- 1. BẢNG NGÂN HÀNG (Banks)
CREATE TABLE IF NOT EXISTS Banks (
    Bin TEXT PRIMARY KEY,
    ShortName TEXT NOT NULL,
    FullName TEXT NOT NULL,
    LogoUrl TEXT,
    IsSupported INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS IX_Banks_ShortName ON Banks(ShortName);

-- 2. BẢNG NGƯỜI DÙNG (Users)
CREATE TABLE IF NOT EXISTS Users (
    Id TEXT PRIMARY KEY,
    PhoneNumber TEXT NOT NULL UNIQUE,
    Email TEXT NOT NULL UNIQUE,
    PasswordHash TEXT NOT NULL,
    FullName TEXT NOT NULL,
    AvatarUrl TEXT,
    BankBin TEXT NOT NULL,
    BankAccountNo TEXT NOT NULL,
    BankAccountName TEXT NOT NULL,
    FcmToken TEXT,
    CreatedAt TEXT NOT NULL,
    UpdatedAt TEXT NOT NULL
);

-- 3. BẢNG BẠN BÈ (Friendships)
CREATE TABLE IF NOT EXISTS Friendships (
    Id TEXT PRIMARY KEY,
    RequesterId TEXT NOT NULL,
    AddresseeId TEXT NOT NULL,
    Status TEXT NOT NULL DEFAULT 'Accepted',
    CreatedAt TEXT NOT NULL,
    FOREIGN KEY (RequesterId) REFERENCES Users(Id) ON DELETE RESTRICT,
    FOREIGN KEY (AddresseeId) REFERENCES Users(Id) ON DELETE RESTRICT,
    UNIQUE (RequesterId, AddresseeId)
);

-- 4. BẢNG NHÓM CHIA TIỀN (Groups)
CREATE TABLE IF NOT EXISTS Groups (
    Id TEXT PRIMARY KEY,
    Name TEXT NOT NULL,
    Category TEXT NOT NULL,
    AvatarUrl TEXT,
    InviteCode TEXT NOT NULL UNIQUE,
    CreatedById TEXT NOT NULL,
    CreatedAt TEXT NOT NULL,
    FOREIGN KEY (CreatedById) REFERENCES Users(Id) ON DELETE RESTRICT
);

-- 5. BẢNG THÀNH VIÊN TRONG NHÓM (GroupMembers)
CREATE TABLE IF NOT EXISTS GroupMembers (
    GroupId TEXT NOT NULL,
    UserId TEXT NOT NULL,
    Role TEXT NOT NULL DEFAULT 'Member',
    JoinedAt TEXT NOT NULL,
    PRIMARY KEY (GroupId, UserId),
    FOREIGN KEY (GroupId) REFERENCES Groups(Id) ON DELETE CASCADE,
    FOREIGN KEY (UserId) REFERENCES Users(Id) ON DELETE CASCADE
);

-- 6. BẢNG HÓA ĐƠN GỐC (Expenses)
CREATE TABLE IF NOT EXISTS Expenses (
    Id TEXT PRIMARY KEY,
    Title TEXT NOT NULL,
    TotalAmount REAL NOT NULL,
    PayerId TEXT NOT NULL,
    GroupId TEXT,
    Category TEXT NOT NULL DEFAULT 'Food',
    ReceiptImageUrl TEXT,
    CreatedAt TEXT NOT NULL,
    FOREIGN KEY (PayerId) REFERENCES Users(Id) ON DELETE RESTRICT,
    FOREIGN KEY (GroupId) REFERENCES Groups(Id) ON DELETE SET NULL
);

-- 7. BẢNG KHOẢN NỢ CHI TIẾT & GẠCH NỢ QUA VIETQR (Debts)
CREATE TABLE IF NOT EXISTS Debts (
    Id TEXT PRIMARY KEY,
    ExpenseId TEXT NOT NULL,
    CreditorId TEXT NOT NULL,
    DebtorId TEXT,
    CustomDebtorName TEXT,
    Amount REAL NOT NULL,
    DebtCode TEXT NOT NULL UNIQUE,
    Status TEXT NOT NULL DEFAULT 'Pending',
    SettlementType TEXT,
    PaidAt TEXT,
    BankRawMessage TEXT,
    CreatedAt TEXT NOT NULL,
    FOREIGN KEY (ExpenseId) REFERENCES Expenses(Id) ON DELETE CASCADE,
    FOREIGN KEY (CreditorId) REFERENCES Users(Id) ON DELETE RESTRICT,
    FOREIGN KEY (DebtorId) REFERENCES Users(Id) ON DELETE RESTRICT
);

-- ==============================================================================
-- DỮ LIỆU MẪU ĐẦY ĐỦ CÁC VÍ ĐIỆN TỬ VÀ NGÂN HÀNG VIỆT NAM (SEED DATA)
-- ==============================================================================

INSERT OR REPLACE INTO Banks (Bin, ShortName, FullName, LogoUrl, IsSupported) VALUES
-- Ví điện tử & Ngân hàng số
('971005', 'MoMo', 'Ví điện tử MoMo', 'https://api.vietqr.io/img/MOMO.png', 1),
('971011', 'ZaloPay', 'Ví điện tử ZaloPay', 'https://api.vietqr.io/img/ZALOPAY.png', 1),
('971003', 'Viettel Money', 'Tổng Công ty Dịch vụ Số Viettel', 'https://api.vietqr.io/img/VIETTELMONEY.png', 1),
('971008', 'VNPT Money', 'Tập đoàn Bưu chính Viễn thông Việt Nam', 'https://api.vietqr.io/img/VNPTMONEY.png', 1),
('971010', 'ShopeePay', 'Ví điện tử ShopeePay', 'https://api.vietqr.io/img/SHOPEEPAY.png', 1),
('546034', 'CAKE', 'Ngân hàng số Cake by VPBank', 'https://api.vietqr.io/img/CAKE.png', 1),
('963388', 'Timo', 'Ngân hàng số Timo by BVBank', 'https://api.vietqr.io/img/TIMO.png', 1),

-- Ngân hàng thương mại Việt Nam
('970422', 'MBBank', 'Ngân hàng TMCP Quân đội', 'https://api.vietqr.io/img/MB.png', 1),
('970423', 'TPBank', 'Ngân hàng TMCP Tiên Phong', 'https://api.vietqr.io/img/TPB.png', 1),
('970436', 'Vietcombank', 'Ngân hàng TMCP Ngoại thương Việt Nam', 'https://api.vietqr.io/img/VCB.png', 1),
('970415', 'VietinBank', 'Ngân hàng TMCP Công thương Việt Nam', 'https://api.vietqr.io/img/CTG.png', 1),
('970418', 'BIDV', 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam', 'https://api.vietqr.io/img/BIDV.png', 1),
('970407', 'Techcombank', 'Ngân hàng TMCP Kỹ thương Việt Nam', 'https://api.vietqr.io/img/TCB.png', 1),
('970416', 'ACB', 'Ngân hàng TMCP Á Châu', 'https://api.vietqr.io/img/ACB.png', 1),
('970432', 'VPBank', 'Ngân hàng TMCP Việt Nam Thịnh Vượng', 'https://api.vietqr.io/img/VPB.png', 1),
('970403', 'Sacombank', 'Ngân hàng TMCP Sài Gòn Thương Tín', 'https://api.vietqr.io/img/STB.png', 1),
('970441', 'VIB', 'Ngân hàng TMCP Quốc tế Việt Nam', 'https://api.vietqr.io/img/VIB.png', 1),
('970437', 'HDBank', 'Ngân hàng TMCP Phát triển TP.HCM', 'https://api.vietqr.io/img/HDB.png', 1),
('970448', 'OCB', 'Ngân hàng TMCP Phương Đông', 'https://api.vietqr.io/img/OCB.png', 1),
('970405', 'Agribank', 'Ngân hàng Nông nghiệp và Phát triển Nông thôn Việt Nam', 'https://api.vietqr.io/img/VBA.png', 1),
('970426', 'MSB', 'Ngân hàng TMCP Hàng Hải Việt Nam', 'https://api.vietqr.io/img/MSB.png', 1),
('970440', 'SeABank', 'Ngân hàng TMCP Đông Nam Á', 'https://api.vietqr.io/img/SEAB.png', 1),
('970449', 'LPBank', 'Ngân hàng TMCP Lộc Phát Việt Nam', 'https://api.vietqr.io/img/LPB.png', 1),
('970428', 'Nam A Bank', 'Ngân hàng TMCP Nam Á', 'https://api.vietqr.io/img/NAB.png', 1),
('970454', 'BVBank', 'Ngân hàng TMCP Bản Việt', 'https://api.vietqr.io/img/BVB.png', 1),
('970409', 'Bac A Bank', 'Ngân hàng TMCP Bắc Á', 'https://api.vietqr.io/img/BAB.png', 1),
('970412', 'PVcomBank', 'Ngân hàng TMCP Đại Chúng Việt Nam', 'https://api.vietqr.io/img/PVCB.png', 1),
('970452', 'Kienlongbank', 'Ngân hàng TMCP Kiên Long', 'https://api.vietqr.io/img/KLB.png', 1),
('970400', 'Saigonbank', 'Ngân hàng TMCP Sài Gòn Công Thương', 'https://api.vietqr.io/img/SGB.png', 1),
('970438', 'BaoViet Bank', 'Ngân hàng TMCP Bảo Việt', 'https://api.vietqr.io/img/BVBANK.png', 1),
('970430', 'PGBank', 'Ngân hàng TMCP Thịnh vượng và Phát triển', 'https://api.vietqr.io/img/PGB.png', 1),
('970424', 'Shinhan Bank', 'Ngân hàng TNHH MTV Shinhan Việt Nam', 'https://api.vietqr.io/img/SHBVN.png', 1),
('970457', 'Woori Bank', 'Ngân hàng TNHH MTV Woori Việt Nam', 'https://api.vietqr.io/img/WVN.png', 1),
('970458', 'UOB', 'Ngân hàng UOB Việt Nam', 'https://api.vietqr.io/img/UOB.png', 1),
('970439', 'Public Bank', 'Ngân hàng Public Bank Việt Nam', 'https://api.vietqr.io/img/PBVN.png', 1),
('970421', 'VRB', 'Ngân hàng Liên doanh Việt - Nga', 'https://api.vietqr.io/img/VRB.png', 1);
