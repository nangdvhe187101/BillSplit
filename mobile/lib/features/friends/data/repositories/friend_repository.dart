import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/friend_model.dart';

/// Kết quả chung cho các thao tác bạn bè: thành công/thất bại kèm thông báo.
class FriendActionResult {
  final bool success;
  final String message;

  FriendActionResult({required this.success, required this.message});
}

/// Gọi API Backend thật cho Module 4: Bạn bè & Bù trừ nợ.
class FriendRepository {
  final DioClient dioClient;

  FriendRepository({required this.dioClient});

  /// Lấy danh sách bạn bè đã được chấp nhận (Accepted), kèm bù trừ nợ 2 chiều.
  Future<List<FriendModel>> getFriends() async {
    final response = await dioClient.dio.get('/friends');
    final list = response.data as List<dynamic>;
    return list.map((e) => FriendModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Lấy danh sách lời mời kết bạn đang chờ MÌNH đồng ý.
  Future<List<FriendModel>> getPendingRequests() async {
    final response = await dioClient.dio.get('/friends/pending');
    final list = response.data as List<dynamic>;
    return list.map((e) => FriendModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Gửi lời mời kết bạn tới số điện thoại đã đăng ký. Lời mời ở trạng thái
  /// Pending cho tới khi người kia đồng ý (bankBin/bankAccountNo chưa lộ ra).
  Future<FriendActionResult> addFriendByPhone(String phoneNumber) async {
    try {
      final response = await dioClient.dio.post(
        '/friends/add',
        data: {'phoneNumber': phoneNumber},
      );
      final data = response.data as Map<String, dynamic>;
      return FriendActionResult(
        success: true,
        message: data['message'] as String? ?? 'Đã gửi lời mời kết bạn.',
      );
    } on DioException catch (e) {
      return FriendActionResult(success: false, message: _extractError(e));
    }
  }

  /// Đồng ý lời mời kết bạn [friendshipId] gửi tới mình.
  Future<FriendActionResult> acceptRequest(String friendshipId) async {
    try {
      final response = await dioClient.dio.post('/friends/$friendshipId/accept');
      final data = response.data as Map<String, dynamic>;
      return FriendActionResult(
        success: true,
        message: data['message'] as String? ?? 'Đã đồng ý lời mời kết bạn.',
      );
    } on DioException catch (e) {
      return FriendActionResult(success: false, message: _extractError(e));
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
