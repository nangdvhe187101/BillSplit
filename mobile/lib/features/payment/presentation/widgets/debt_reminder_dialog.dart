import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';

class DebtReminderDialog extends StatelessWidget {
  final String debtorName;
  final String expenseTitle;
  final double amount;
  final String debtCode;
  final String bankBin;
  final String bankAccountNo;
  final String bankAccountName;

  const DebtReminderDialog({
    super.key,
    required this.debtorName,
    required this.expenseTitle,
    required this.amount,
    required this.debtCode,
    required this.bankBin,
    required this.bankAccountNo,
    required this.bankAccountName,
  });

  String _generateReminderText() {
    final currencyFormat = NumberFormat('#,###', 'vi_VN');
    final formattedAmount = '${currencyFormat.format(amount)} đ';

    return '''Alo $debtorName ơi, bữa "$expenseTitle" phần của bạn là $formattedAmount nhé.
Khi nào tiện bạn quét mã VietQR hoặc chuyển khoản giúp mình nha:
• Ngân hàng: BIN $bankBin
• Số tài khoản: $bankAccountNo
• Chủ tài khoản: $bankAccountName
• Số tiền: $formattedAmount
• Nội dung chuyển khoản: $debtCode

Cảm ơn bạn nhiều nha! 🙏''';
  }

  @override
  Widget build(BuildContext context) {
    final reminderText = _generateReminderText();

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.send_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nhắc nợ văn minh',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      Text(
                        'Soạn sẵn lời nhắn & thông tin chuyển khoản',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                reminderText,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: reminderText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép nội dung nhắc nợ vào bộ nhớ tạm!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Sao chép'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Share.share(
                        reminderText,
                        subject: 'Nhắc nợ bill $expenseTitle',
                      );
                    },
                    icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'Chia sẻ Zalo/SMS',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
