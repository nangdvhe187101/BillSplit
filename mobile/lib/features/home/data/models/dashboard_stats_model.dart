class CategoryExpenseModel {
  final String category;
  final double amount;
  final double percentage;

  CategoryExpenseModel({
    required this.category,
    required this.amount,
    required this.percentage,
  });

  factory CategoryExpenseModel.fromJson(Map<String, dynamic> json) {
    return CategoryExpenseModel(
      category: json['category'] as String? ?? 'Khác',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MonthlyTrendModel {
  final String month;
  final double spent;
  final double collected;

  MonthlyTrendModel({
    required this.month,
    required this.spent,
    required this.collected,
  });

  factory MonthlyTrendModel.fromJson(Map<String, dynamic> json) {
    return MonthlyTrendModel(
      month: json['month'] as String? ?? '',
      spent: (json['spent'] as num?)?.toDouble() ?? 0.0,
      collected: (json['collected'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DashboardTransactionModel {
  final String id;
  final String expenseTitle;
  final String creditorName;
  final String debtorName;
  final double amount;
  final String debtCode;
  final String status;
  final String? settlementType;
  final DateTime? paidAt;
  final DateTime createdAt;

  DashboardTransactionModel({
    required this.id,
    required this.expenseTitle,
    required this.creditorName,
    required this.debtorName,
    required this.amount,
    required this.debtCode,
    required this.status,
    this.settlementType,
    this.paidAt,
    required this.createdAt,
  });

  factory DashboardTransactionModel.fromJson(Map<String, dynamic> json) {
    return DashboardTransactionModel(
      id: json['id'] as String? ?? '',
      expenseTitle: json['expenseTitle'] as String? ?? 'Khoản chi',
      creditorName: json['creditorName'] as String? ?? '',
      debtorName: json['debtorName'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      debtCode: json['debtCode'] as String? ?? '',
      status: json['status'] as String? ?? 'Pending',
      settlementType: json['settlementType'] as String?,
      paidAt: json['paidAt'] != null ? DateTime.tryParse(json['paidAt'] as String) : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class DashboardStatsModel {
  final double totalReceivable;
  final double totalPayable;
  final double netBalance;
  final List<CategoryExpenseModel> categoryBreakdown;
  final List<MonthlyTrendModel> monthlyTrends;
  final List<DashboardTransactionModel> recentTransactions;

  DashboardStatsModel({
    required this.totalReceivable,
    required this.totalPayable,
    required this.netBalance,
    required this.categoryBreakdown,
    required this.monthlyTrends,
    required this.recentTransactions,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    return DashboardStatsModel(
      totalReceivable: (json['totalReceivable'] as num?)?.toDouble() ?? 0.0,
      totalPayable: (json['totalPayable'] as num?)?.toDouble() ?? 0.0,
      netBalance: (json['netBalance'] as num?)?.toDouble() ?? 0.0,
      categoryBreakdown: (json['categoryBreakdown'] as List<dynamic>?)
              ?.map((e) => CategoryExpenseModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      monthlyTrends: (json['monthlyTrends'] as List<dynamic>?)
              ?.map((e) => MonthlyTrendModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recentTransactions: (json['recentTransactions'] as List<dynamic>?)
              ?.map((e) => DashboardTransactionModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
