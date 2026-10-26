import 'crc16.dart';

/// Bộ sinh chuỗi payload VietQR theo chuẩn EMVCo TLV (Tag-Length-Value)
/// Hỗ trợ tạo QR động chứa số tài khoản, số tiền và nội dung gắn mã định danh
class VietQrEncoder {
  /// Sinh định dạng Tag-Length-Value: [ID 2 số][Độ dài 2 số][Giá trị]
  static String formatTlv(String tag, String value) {
    final lengthStr = value.length.toString().padLeft(2, '0');
    return '$tag$lengthStr$value';
  }

  /// Tạo chuỗi VietQR chuẩn EMVCo đầy đủ
  /// - [bankBin]: Mã BIN 6 số của ngân hàng thụ hưởng (ví dụ: "970422" cho MBBank)
  /// - [accountNo]: Số tài khoản ngân hàng thụ hưởng
  /// - [amount]: Số tiền giao dịch (làm tròn số nguyên đồng)
  /// - [memo]: Nội dung chuyển khoản (chứa mã định danh, ví dụ: "BS8K2M TRANO")
  static String encode({
    required String bankBin,
    required String accountNo,
    required double amount,
    required String memo,
  }) {
    final buffer = StringBuffer();

    // 00: Payload Format Indicator (Cố định '01')
    buffer.write(formatTlv('00', '01'));

    // 01: Point of Initiation Method ('12': Dynamic QR - có sẵn số tiền)
    buffer.write(formatTlv('01', '12'));

    // 38: Merchant Account Information (Napas VietQR)
    final merchantInfoBuffer = StringBuffer();
    // 00: AID của Napas
    merchantInfoBuffer.write(formatTlv('00', 'A000000727'));
    // 01: Thông tin tài khoản thụ hưởng (Sub-tag 00: BIN, Sub-tag 01: STK)
    final bankAccountBuffer = StringBuffer();
    bankAccountBuffer.write(formatTlv('00', bankBin));
    bankAccountBuffer.write(formatTlv('01', accountNo));
    merchantInfoBuffer.write(formatTlv('01', bankAccountBuffer.toString()));
    // 02: Service Code chuyển nhanh Napas247
    merchantInfoBuffer.write(formatTlv('02', 'QRIBFTTA'));

    buffer.write(formatTlv('38', merchantInfoBuffer.toString()));

    // 53: Transaction Currency Code ('704' = VNĐ theo ISO 4217)
    buffer.write(formatTlv('53', '704'));

    // 54: Transaction Amount
    final formattedAmount = amount.toInt().toString();
    buffer.write(formatTlv('54', formattedAmount));

    // 58: Country Code ('VN')
    buffer.write(formatTlv('58', 'VN'));

    // 62: Additional Data Field (Chứa Purpose of Transaction)
    final additionalDataBuffer = StringBuffer();
    // Sub-tag 08: Purpose of Transaction
    additionalDataBuffer.write(formatTlv('08', memo));
    buffer.write(formatTlv('62', additionalDataBuffer.toString()));

    // 63: CRC Checksum (Bao gồm tiền tố '6304' và 4 ký tự CRC16 ở đuôi)
    buffer.write('6304');
    final rawPayload = buffer.toString();
    final crcHex = Crc16.calculateHex(rawPayload);

    return '$rawPayload$crcHex';
  }
}
