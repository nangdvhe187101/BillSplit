import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Client Dio quản lý gọi RESTful API đến Backend ASP.NET Core
/// Tự động đính kèm JWT Bearer Token vào Header và xử lý lỗi mạng tập trung
class DioClient {
  // IP Wi-Fi nội bộ của máy tính để điện thoại thật kết nối trực tiếp qua LAN (hoặc dùng 10.0.2.2 nếu chạy máy ảo)
  static const String defaultBaseUrl = 'http://192.168.1.193:5206/api';

  final Dio dio;
  final FlutterSecureStorage secureStorage;

  DioClient({
    String baseUrl = defaultBaseUrl,
    FlutterSecureStorage? storage,
  })  : secureStorage = storage ?? const FlutterSecureStorage(),
        dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Lấy token từ secure storage và gắn vào header Authorization
          final token = await secureStorage.read(key: 'jwt_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          // Xử lý lỗi tập trung (ví dụ 401 Unauthorized khi token hết hạn)
          if (error.response?.statusCode == 401) {
            // Có thể trigger logout event hoặc xóa token cũ
          }
          return handler.next(error);
        },
      ),
    );
  }
}
