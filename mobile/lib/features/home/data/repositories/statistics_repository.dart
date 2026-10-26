import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/dashboard_stats_model.dart';

class StatisticsRepository {
  final DioClient dioClient;

  StatisticsRepository({required this.dioClient});

  Future<DashboardStatsModel> getDashboardStats() async {
    try {
      final response = await dioClient.dio.get('/statistics/dashboard');
      if (response.statusCode == 200 && response.data != null) {
        return DashboardStatsModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Không thể tải dữ liệu thống kê');
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message ?? 'Lỗi kết nối máy chủ';
      throw Exception(errorMsg);
    }
  }
}
