import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/debt_detail_model.dart';

/// Kết quả gọi API tạo bill chia nợ: thành công/thất bại kèm thông báo và danh sách nợ thật.
class SplitExpenseResult {
  final bool success;
  final String message;
  final List<DebtDetailModel> debts;

  SplitExpenseResult({
    required this.success,
    required this.message,
    this.debts = const [],
  });
}

/// Gọi API Backend thật cho các thao tác liên quan tới chia nợ (Module 7: Smart Bill Split).
class DebtRepository {
  final DioClient dioClient;

  DebtRepository({required this.dioClient});

  /// Xác nhận thủ công khoản nợ [debtId] đã được thanh toán (do chủ nợ tự bấm xác nhận).
  Future<SplitExpenseResult> manualSettle(String debtId) async {
    try {
      final response = await dioClient.dio.post('/debts/$debtId/manual-settle');
      final data = response.data as Map<String, dynamic>;
      return SplitExpenseResult(
        success: true,
        message: data['message'] as String? ?? 'Đã xác nhận gạch nợ thành công!',
      );
    } on DioException catch (e) {
      final serverMessage = (e.response?.data is Map)
          ? (e.response?.data as Map)['message'] as String?
          : null;
      return SplitExpenseResult(
        success: false,
        message: serverMessage ?? 'Không thể kết nối tới server, vui lòng thử lại.',
      );
    }
  }

  /// Gửi hóa đơn + danh sách người nợ lên Backend để tạo Expense và các Debt thật.
  /// [debtorId] null nếu là khách ngoài (không có tài khoản trong app).
  Future<SplitExpenseResult> splitExpense({
    required String title,
    required double totalAmount,
    required String category,
    String? groupId,
    required List<Map<String, dynamic>> debts, // {debtorId, customDebtorName, amount}
  }) async {
    try {
      final response = await dioClient.dio.post(
        '/debts/split',
        data: {
          'title': title,
          'totalAmount': totalAmount,
          'category': category,
          'groupId': groupId,
          'debts': debts,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final debtsJson = (data['debts'] as List<dynamic>? ?? [])
          .map((e) => DebtDetailModel.fromJson(e as Map<String, dynamic>))
          .toList();

      return SplitExpenseResult(
        success: true,
        message: data['message'] as String? ?? 'Tạo bill chia nợ thành công!',
        debts: debtsJson,
      );
    } on DioException catch (e) {
      final serverMessage = (e.response?.data is Map)
          ? (e.response?.data as Map)['message'] as String?
          : null;
      return SplitExpenseResult(
        success: false,
        message: serverMessage ?? 'Không thể kết nối tới server, vui lòng thử lại.',
      );
    }
  }

  /// Gạch nợ tự động từ nội dung thông báo biến động số dư ngân hàng (Module 8 & Module 6)
  Future<SplitExpenseResult> autoSettle({
    required String rawBankMessage,
    String? bankShortName,
  }) async {
    try {
      final response = await dioClient.dio.post(
        '/debts/auto-settle',
        data: {
          'rawBankMessage': rawBankMessage,
          'bankShortName': bankShortName,
        },
      );

      final data = response.data as Map<String, dynamic>;
      return SplitExpenseResult(
        success: true,
        message: data['message'] as String? ?? 'Gạch nợ tự động thành công!',
      );
    } on DioException catch (e) {
      final serverMessage = (e.response?.data is Map)
          ? (e.response?.data as Map)['message'] as String?
          : null;
      return SplitExpenseResult(
        success: false,
        message: serverMessage ?? 'Không tìm thấy mã nợ hợp lệ trong tin nhắn.',
      );
    }
  }
}
