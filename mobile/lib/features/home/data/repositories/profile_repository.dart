import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../auth/data/models/user_model.dart';

class ProfileRepository {
  final DioClient dioClient;
  final LocalStorageService localStorage;

  ProfileRepository({
    required this.dioClient,
    required this.localStorage,
  });

  Future<({bool success, String message, UserModel? user})> updateProfile({
    required String fullName,
    required String bankBin,
    required String bankAccountNo,
    required String bankAccountName,
    String? avatarUrl,
  }) async {
    try {
      final response = await dioClient.dio.put(
        '/users/profile',
        data: {
          'fullName': fullName,
          'bankBin': bankBin,
          'bankAccountNo': bankAccountNo,
          'bankAccountName': bankAccountName,
          'avatarUrl': avatarUrl,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        final user = UserModel(
          id: data['id'] as String,
          phoneNumber: data['phoneNumber'] as String,
          email: data['email'] as String,
          fullName: data['fullName'] as String,
          avatarUrl: data['avatarUrl'] as String?,
          bankBin: data['bankBin'] as String,
          bankAccountNo: data['bankAccountNo'] as String,
          bankAccountName: data['bankAccountName'] as String,
        );

        // Cập nhật lại cache offline
        await localStorage.saveUserJson(jsonEncode(user.toJson()));
        return (success: true, message: 'Cập nhật hồ sơ thành công', user: user);
      }
      return (success: false, message: 'Không thể cập nhật hồ sơ', user: null);
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message ?? 'Lỗi kết nối máy chủ';
      return (success: false, message: errorMsg.toString(), user: null);
    } catch (e) {
      return (success: false, message: e.toString(), user: null);
    }
  }
}
