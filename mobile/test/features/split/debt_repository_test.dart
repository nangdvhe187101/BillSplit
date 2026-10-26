import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/dio_client.dart';
import 'package:mobile/features/split/data/repositories/debt_repository.dart';

/// Adapter giả lập Backend để test [DebtRepository] mà không cần gọi mạng thật.
/// Dùng interface `HttpClientAdapter` có sẵn trong package `dio`, không cần
/// thêm thư viện mock ngoài phạm vi (project chưa có mockito/mocktail).
class _FakeHttpClientAdapter implements HttpClientAdapter {
  final int statusCode;
  final Map<String, dynamic> responseBody;

  _FakeHttpClientAdapter({required this.statusCode, required this.responseBody});

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final jsonBytes = Utf8Encoder().convert(_encodeJson(responseBody));
    return ResponseBody.fromBytes(
      jsonBytes,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  String _encodeJson(Map<String, dynamic> map) {
    // Encode thủ công đơn giản vì test chỉ cần cấu trúc phẳng đã biết trước.
    return const JsonEncoderStub().convert(map);
  }
}

/// Stub encode JSON tối giản dùng riêng cho test này (tránh phụ thuộc thêm package).
class JsonEncoderStub {
  const JsonEncoderStub();

  String convert(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return '"${value.replaceAll('"', '\\"')}"';
    if (value is num || value is bool) return '$value';
    if (value is List) return '[${value.map(convert).join(',')}]';
    if (value is Map) {
      final entries = value.entries.map((e) => '"${e.key}":${convert(e.value)}');
      return '{${entries.join(',')}}';
    }
    return '"$value"';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});

  group('DebtRepository Tests', () {
    test('splitExpense trả về danh sách DebtDetailModel khi Backend thành công (201/200)', () async {
      final dioClient = DioClient(storage: const FlutterSecureStorage());
      dioClient.dio.httpClientAdapter = _FakeHttpClientAdapter(
        statusCode: 200,
        responseBody: {
          'message': 'Tạo bill chia nợ thành công!',
          'debts': [
            {
              'id': 'd1111111-1111-1111-1111-111111111111',
              'expenseId': 'e1111111-1111-1111-1111-111111111111',
              'expenseTitle': 'Ăn trưa phở',
              'creditorId': 'c1111111-1111-1111-1111-111111111111',
              'creditorName': 'Bạn',
              'debtorId': 'b1111111-1111-1111-1111-111111111111',
              'debtorName': 'Trần Văn B',
              'amount': 48333,
              'debtCode': 'BSZ5F3N',
              'status': 'Pending',
            },
          ],
        },
      );

      final repository = DebtRepository(dioClient: dioClient);
      final result = await repository.splitExpense(
        title: 'Ăn trưa phở',
        totalAmount: 165000,
        category: 'Food',
        debts: [
          {'debtorId': 'b1111111-1111-1111-1111-111111111111', 'customDebtorName': null, 'amount': 48333},
        ],
      );

      expect(result.success, true);
      expect(result.debts.length, 1);
      expect(result.debts.first.debtCode, 'BSZ5F3N');
      expect(result.debts.first.amount, 48333);
      expect(result.debts.first.debtorName, 'Trần Văn B');
    });

    test('splitExpense trả về success=false khi Backend báo lỗi 400', () async {
      final dioClient = DioClient(storage: const FlutterSecureStorage());
      dioClient.dio.httpClientAdapter = _FakeHttpClientAdapter(
        statusCode: 400,
        responseBody: {'message': 'Tổng các phần chia không khớp với hóa đơn.'},
      );

      final repository = DebtRepository(dioClient: dioClient);
      final result = await repository.splitExpense(
        title: 'Bill lỗi',
        totalAmount: 100000,
        category: 'Food',
        debts: [
          {'debtorId': null, 'customDebtorName': 'Khách lạ', 'amount': 50000},
        ],
      );

      expect(result.success, false);
      expect(result.message, 'Tổng các phần chia không khớp với hóa đơn.');
      expect(result.debts, isEmpty);
    });
  });
}
