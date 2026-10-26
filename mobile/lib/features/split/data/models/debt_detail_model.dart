/// Model ánh xạ đúng `DebtDetailDto` trả về từ Backend sau khi tạo bill chia nợ.
/// Dùng mã nợ và id nợ THẬT từ server, không tự sinh ở local nữa.
class DebtDetailModel {
  final String id;
  final String expenseId;
  final String expenseTitle;
  final String creditorId;
  final String creditorName;
  final String? debtorId;
  final String debtorName;
  final double amount;
  final String debtCode;
  final String status;

  DebtDetailModel({
    required this.id,
    required this.expenseId,
    required this.expenseTitle,
    required this.creditorId,
    required this.creditorName,
    this.debtorId,
    required this.debtorName,
    required this.amount,
    required this.debtCode,
    required this.status,
  });

  factory DebtDetailModel.fromJson(Map<String, dynamic> json) {
    return DebtDetailModel(
      id: json['id'] as String,
      expenseId: json['expenseId'] as String,
      expenseTitle: json['expenseTitle'] as String,
      creditorId: json['creditorId'] as String,
      creditorName: json['creditorName'] as String,
      debtorId: json['debtorId'] as String?,
      debtorName: json['debtorName'] as String,
      amount: (json['amount'] as num).toDouble(),
      debtCode: json['debtCode'] as String,
      status: json['status'] as String,
    );
  }
}
