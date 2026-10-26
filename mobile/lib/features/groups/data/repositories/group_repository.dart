import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/group_model.dart';

/// Kết quả gọi API tạo/tham gia nhóm: thành công/thất bại kèm thông báo và dữ liệu nhóm.
class GroupActionResult {
  final bool success;
  final String message;
  final GroupModel? group;

  GroupActionResult({required this.success, required this.message, this.group});
}

/// Gọi API Backend thật cho Module 5: Quản lý nhóm chia tiền.
class GroupRepository {
  final DioClient dioClient;

  GroupRepository({required this.dioClient});

  /// Lấy danh sách nhóm mà người dùng hiện tại là thành viên.
  Future<List<GroupModel>> getMyGroups() async {
    final response = await dioClient.dio.get('/groups');
    final list = response.data as List<dynamic>;
    return list.map((e) => GroupModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Tạo nhóm mới, người tạo tự động là Owner. Backend tự sinh mã mời 6 ký tự.
  Future<GroupActionResult> createGroup({
    required String name,
    required String category,
    String? avatarUrl,
  }) async {
    try {
      final response = await dioClient.dio.post(
        '/groups',
        data: {
          'name': name,
          'category': category,
          'avatarUrl': avatarUrl,
        },
      );
      final data = response.data as Map<String, dynamic>;
      return GroupActionResult(
        success: true,
        message: data['message'] as String? ?? 'Tạo nhóm thành công!',
        group: GroupModel.fromJson(data['data'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      return GroupActionResult(success: false, message: _extractError(e));
    }
  }

  /// Tham gia nhóm bằng mã mời 6 ký tự.
  Future<GroupActionResult> joinByInviteCode(String inviteCode) async {
    try {
      final response = await dioClient.dio.post(
        '/groups/join',
        data: {'inviteCode': inviteCode},
      );
      final data = response.data as Map<String, dynamic>;
      return GroupActionResult(
        success: true,
        message: data['message'] as String? ?? 'Đã tham gia nhóm thành công!',
        group: GroupModel.fromJson(data['data'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      return GroupActionResult(success: false, message: _extractError(e));
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Không thể kết nối tới server, vui lòng thử lại.';
  }
}
