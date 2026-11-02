import 'debt_detail_model.dart';

/// Model tổng hợp các khoản nợ được cộng dồn theo từng người (Person).
/// Cho phép xem tổng nợ hiện tại (ví dụ: bill A 50k + bill B 20k = 70k)
/// đồng thời lưu trữ đầy đủ danh sách lịch sử từng bill chi tiết của người đó.
class PersonDebtSummaryModel {
  final String? debtorId;
  final String debtorName;
  final String? phoneNumber;
  final double totalPendingAmount;
  final int pendingCount;
  final double totalPaidAmount;
  final int paidCount;
  final List<DebtDetailModel> debts;

  PersonDebtSummaryModel({
    this.debtorId,
    required this.debtorName,
    this.phoneNumber,
    required this.totalPendingAmount,
    required this.pendingCount,
    required this.totalPaidAmount,
    required this.paidCount,
    required this.debts,
  });

  bool get isAppUser => debtorId != null && debtorId!.isNotEmpty;
  bool get hasPendingDebts => totalPendingAmount > 0;
  bool get isFullySettled => totalPendingAmount == 0 && totalPaidAmount > 0;

  List<DebtDetailModel> get pendingDebts =>
      debts.where((d) => d.status.toLowerCase() == 'pending').toList();

  List<DebtDetailModel> get paidDebts =>
      debts.where((d) => d.status.toLowerCase() == 'paid').toList();

  factory PersonDebtSummaryModel.fromJson(Map<String, dynamic> json) {
    final debtsList = (json['debts'] as List<dynamic>? ?? [])
        .map((e) => DebtDetailModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return PersonDebtSummaryModel(
      debtorId: json['debtorId'] as String?,
      debtorName: json['debtorName'] as String? ?? 'Khách ngoài',
      phoneNumber: json['phoneNumber'] as String?,
      totalPendingAmount: (json['totalPendingAmount'] as num?)?.toDouble() ?? 0.0,
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      totalPaidAmount: (json['totalPaidAmount'] as num?)?.toDouble() ?? 0.0,
      paidCount: (json['paidCount'] as num?)?.toInt() ?? 0,
      debts: debtsList,
    );
  }

  /// Tự tạo PersonDebtSummaryModel từ danh sách DebtDetailModel phẳng (cho Fallback hoặc Guest Mode)
  static List<PersonDebtSummaryModel> fromFlatDebts(List<DebtDetailModel> flatDebts) {
    final Map<String, List<DebtDetailModel>> grouped = {};

    for (final debt in flatDebts) {
      final key = debt.debtorId ?? 'custom_${debt.debtorName}';
      grouped.putIfAbsent(key, () => []).add(debt);
    }

    final List<PersonDebtSummaryModel> summaries = [];

    for (final entry in grouped.entries) {
      final list = entry.value;
      list.sort((a, b) {
        final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

      final first = list.first;
      final pendingList = list.where((d) => d.status.toLowerCase() == 'pending').toList();
      final paidList = list.where((d) => d.status.toLowerCase() == 'paid').toList();

      final totalPending = pendingList.fold<double>(0.0, (sum, d) => sum + d.amount);
      final totalPaid = paidList.fold<double>(0.0, (sum, d) => sum + d.amount);

      summaries.add(
        PersonDebtSummaryModel(
          debtorId: first.debtorId,
          debtorName: first.debtorName,
          totalPendingAmount: totalPending,
          pendingCount: pendingList.length,
          totalPaidAmount: totalPaid,
          paidCount: paidList.length,
          debts: list,
        ),
      );
    }

    summaries.sort((a, b) {
      final cmp = b.totalPendingAmount.compareTo(a.totalPendingAmount);
      if (cmp != 0) return cmp;
      return b.pendingCount.compareTo(a.pendingCount);
    });

    return summaries;
  }
}

