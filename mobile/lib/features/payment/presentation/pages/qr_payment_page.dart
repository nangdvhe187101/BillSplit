import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/vietqr_encoder.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../split/data/repositories/debt_repository.dart';

import '../widgets/debt_reminder_dialog.dart';

class QrPaymentPage extends StatefulWidget {
  final String? debtId;
  final String debtorName;
  final double amount;
  final String debtCode;
  final String title;

  const QrPaymentPage({
    super.key,
    this.debtId,
    required this.debtorName,
    required this.amount,
    required this.debtCode,
    required this.title,
  });

  @override
  State<QrPaymentPage> createState() => _QrPaymentPageState();
}

class _QrPaymentPageState extends State<QrPaymentPage> {
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'vi_VN');
  String _qrPayload = '';
  String _bankBin = '970422'; // Mặc định MBBank
  String _bankAccountNo = '0912345678';
  String _bankAccountName = 'NGUYEN VAN A';
  bool _isSettling = false;

  @override
  void initState() {
    super.initState();
    _initQrPayload();
  }

  void _initQrPayload() {
    // Lấy thông tin tài khoản ngân hàng của chủ nợ đang đăng nhập
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _bankBin = authState.user.bankBin;
      _bankAccountNo = authState.user.bankAccountNo;
      _bankAccountName = authState.user.bankAccountName;
    }

    // Tự sinh chuỗi VietQR chuẩn EMVCo TLV hoàn toàn offline
    _qrPayload = VietQrEncoder.encode(
      bankBin: _bankBin,
      accountNo: _bankAccountNo,
      amount: widget.amount,
      memo: '${widget.debtCode} TRANO',
    );
  }

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label: $value'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onManualSettlePressed() {
    if (widget.debtId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy khoản nợ để xác nhận (thiếu debtId).'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xác nhận đã nhận tiền?'),
        content: Text(
          'Đánh dấu khoản nợ ${_currencyFormat.format(widget.amount)} đ của "${widget.debtorName}" là đã thanh toán thủ công?',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmManualSettle();
            },
            child: const Text('Xác nhận gạch nợ'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmManualSettle() async {
    setState(() => _isSettling = true);

    final dioClient = context.read<DioClient>();
    final repository = DebtRepository(dioClient: dioClient);
    final result = await repository.manualSettle(widget.debtId!);

    if (!mounted) return;
    setState(() => _isSettling = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? AppColors.success : AppColors.error,
      ),
    );

    if (result.success) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final memo = '${widget.debtCode} TRANO';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quét mã VietQR để trả nợ'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // CARD MÃ QR VIETQR NỔI BẬT (Tone Trắng Nhẹ + Xanh Bầu Trời)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primarySoft.withValues(alpha: 0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Tag tiêu đề nợ
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.title.isNotEmpty ? widget.title : 'Thanh toán nợ chi tiêu',
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_currencyFormat.format(widget.amount)} đ',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Người trả: ${widget.debtorName}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    // Khung QR hiển thị ảnh
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.primaryLight, width: 1.5),
                      ),
                      child: QrImageView(
                        data: _qrPayload,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.primaryDark,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Cảnh báo giữ nguyên nội dung
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFFD97706), size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Giữ nguyên nội dung chuyển khoản để hệ thống tự động gạch nợ!',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // CHI TIẾT CHUYỂN KHOẢN (Cho sao chép thủ công)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thông tin chuyển khoản',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildCopyRow('Chủ tài khoản', _bankAccountName),
                    const Divider(color: AppColors.border, height: 16),
                    _buildCopyRow('Số tài khoản', _bankAccountNo),
                    const Divider(color: AppColors.border, height: 16),
                    _buildCopyRow('Nội dung chuyển khoản', memo),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // NÚT HÀNH ĐỘNG
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => DebtReminderDialog(
                            debtorName: widget.debtorName,
                            expenseTitle: widget.title,
                            amount: widget.amount,
                            debtCode: memo,
                            bankBin: _bankBin,
                            bankAccountNo: _bankAccountNo,
                            bankAccountName: _bankAccountName,
                          ),
                        );
                      },
                      icon: const Icon(Icons.share_rounded, color: AppColors.primary),
                      label: const Text('Nhắc nợ & Chia sẻ'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSettling ? null : _onManualSettlePressed,
                      icon: _isSettling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline, color: Colors.white),
                      label: const Text('Xác nhận đã trả'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCopyRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.copy_rounded, color: AppColors.primary, size: 20),
          onPressed: () => _copyToClipboard(label, value),
        ),
      ],
    );
  }
}
