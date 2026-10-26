/// Model thông tin người dùng trên ứng dụng Mobile
class UserModel {
  final String id;
  final String phoneNumber;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final String bankBin;
  final String bankAccountNo;
  final String bankAccountName;

  UserModel({
    required this.id,
    required this.phoneNumber,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    required this.bankBin,
    required this.bankAccountNo,
    required this.bankAccountName,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      phoneNumber: json['phoneNumber'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      bankBin: json['bankBin'] as String,
      bankAccountNo: json['bankAccountNo'] as String,
      bankAccountName: json['bankAccountName'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'email': email,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
      'bankBin': bankBin,
      'bankAccountNo': bankAccountNo,
      'bankAccountName': bankAccountName,
    };
  }
}
