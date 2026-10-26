/// Thuật toán tính CRC-16/CCITT-FALSE cho mã VietQR EMVCo
/// Đa thức: 0x1021, Giá trị khởi tạo: 0xFFFF
class Crc16 {
  static int calculate(List<int> bytes) {
    int crc = 0xFFFF;
    for (final b in bytes) {
      crc ^= (b << 8);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc;
  }

  /// Trả về chuỗi Hexadecimal 4 ký tự in hoa (ví dụ: "7D2A")
  static String calculateHex(String input) {
    final bytes = input.codeUnits;
    final crc = calculate(bytes);
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}
