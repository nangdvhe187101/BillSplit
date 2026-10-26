/// Model đại diện cho một người tham gia chia bill (bản thân, bạn bè trong app hoặc khách ngoài)
class SplitMember {
  final String id;
  final String name;
  final String? phoneNumber;
  final String? avatarUrl;
  final bool isAppUser;
  final bool isPayer; // true: Bạn (người trả tiền), false: Người nợ cần trả

  bool participatesShared; // true: Có tham gia phần ăn chung, false: Chỉ trả món riêng
  double personalAmount;   // Số tiền món riêng (ví dụ ly nước ép 50.000 đ)
  String? personalNote;    // Tên món riêng (ví dụ "Nước ép cam", "Bia riêng")
  double amount;           // Tổng số tiền cuối cùng cần phân bổ

  SplitMember({
    required this.id,
    required this.name,
    this.phoneNumber,
    this.avatarUrl,
    this.isAppUser = true,
    this.isPayer = false,
    this.participatesShared = true,
    this.personalAmount = 0.0,
    this.personalNote,
    this.amount = 0.0,
  });
}
