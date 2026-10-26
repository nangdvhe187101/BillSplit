import 'dart:async';
import 'package:flutter/services.dart';
import '../../features/split/data/repositories/debt_repository.dart';

class BankNotificationEvent {
  final String packageName;
  final String title;
  final String text;

  BankNotificationEvent({
    required this.packageName,
    required this.title,
    required this.text,
  });

  factory BankNotificationEvent.fromMap(Map<dynamic, dynamic> map) {
    return BankNotificationEvent(
      packageName: map['package'] as String? ?? '',
      title: map['title'] as String? ?? '',
      text: map['text'] as String? ?? '',
    );
  }
}

class NotificationListenerService {
  static const MethodChannel _channel = MethodChannel('com.billsplit.app/notification');

  final StreamController<BankNotificationEvent> _notificationStreamController =
      StreamController<BankNotificationEvent>.broadcast();

  Stream<BankNotificationEvent> get onNotificationReceived => _notificationStreamController.stream;

  DebtRepository? _debtRepository;

  NotificationListenerService({DebtRepository? debtRepository}) {
    _debtRepository = debtRepository;
    _channel.setMethodCallHandler(_handleNativeMethodCall);
  }

  void updateDebtRepository(DebtRepository repository) {
    _debtRepository = repository;
  }

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'onBankNotification') {
      final arguments = call.arguments as Map<dynamic, dynamic>?;
      if (arguments != null) {
        final event = BankNotificationEvent.fromMap(arguments);
        _notificationStreamController.add(event);

        // Tự động gửi thông báo đến API gạch nợ tự động (Module 8) nếu có DebtRepository
        if (_debtRepository != null && event.text.isNotEmpty) {
          try {
            await _debtRepository!.autoSettle(
              rawBankMessage: '${event.title}\n${event.text}',
              bankShortName: event.packageName,
            );
          } catch (_) {
            // Không ngắt luồng nếu không khớp mã nợ
          }
        }
      }
    }
  }

  /// Kiểm tra xem ứng dụng đã được cấp quyền Notification Listener chưa
  Future<bool> isPermissionGranted() async {
    try {
      final result = await _channel.invokeMethod<bool>('isNotificationListenerGranted');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Mở màn hình cài đặt của Android để người dùng bật quyền Đọc thông báo
  Future<bool> openPermissionSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openNotificationListenerSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _notificationStreamController.close();
  }
}
