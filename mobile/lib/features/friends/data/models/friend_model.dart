/// Model ánh xạ đúng `FriendDto` trả về từ Backend.
/// Khi status là "Pending", bankBin/bankAccountNo/bankAccountName đều rỗng
/// (Backend chủ động giấu thông tin ngân hàng cho tới khi lời mời được đồng ý).
class FriendModel {
  final String friendshipId;
  final String friendUserId;
  final String fullName;
  final String phoneNumber;
  final String? avatarUrl;
  final String bankBin;
  final String bankAccountNo;
  final String bankAccountName;
  final String status;
  final double netBalance;

  FriendModel({
    required this.friendshipId,
    required this.friendUserId,
    required this.fullName,
    required this.phoneNumber,
    this.avatarUrl,
    required this.bankBin,
    required this.bankAccountNo,
    required this.bankAccountName,
    required this.status,
    required this.netBalance,
  });

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      friendshipId: json['id'] as String,
      friendUserId: json['friendUserId'] as String,
      fullName: json['fullName'] as String,
      phoneNumber: json['phoneNumber'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      bankBin: json['bankBin'] as String? ?? '',
      bankAccountNo: json['bankAccountNo'] as String? ?? '',
      bankAccountName: json['bankAccountName'] as String? ?? '',
      status: json['status'] as String,
      netBalance: (json['netBalance'] as num? ?? 0).toDouble(),
    );
  }
}
