import '../models/bill_line_item_model.dart';

/// Bộ phân tích heuristic bóc tách danh sách món ăn + giá tiền từ văn bản
/// quét được bằng Google ML Kit (chạy offline, không cần kết nối mạng).
///
/// Nguyên tắc: Mỗi dòng hóa đơn in nhiệt thường có dạng:
///   "Phở nạm gầu          55,000"
///   "Phở nạm gầu x1        55.000đ"
///   "2  Trứng trần         10000"
/// Ta tìm số tiền hợp lệ cuối dòng (ưu tiên số lớn nhất, có định dạng tiền
/// VNĐ) và coi phần còn lại của dòng là tên món.
class BillOcrParser {
  // Số tiền hợp lệ: ít nhất 3 chữ số, có thể có dấu . , hoặc đuôi "đ"/"d"/"vnd"
  static final RegExp _priceRegex = RegExp(
    r'(\d{1,3}(?:[.,]\d{3})+|\d{4,})\s*(?:đ|d|vnd)?\s*$',
    caseSensitive: false,
  );

  // Các dòng tiêu đề/tổng kết cần loại bỏ, không phải món ăn thực sự
  static final RegExp _skipLineRegex = RegExp(
    r'(tổng|total|thành tiền|tạm tính|vat|thuế|giảm giá|discount|'
    r'khuyến mãi|phục vụ|service|subtotal|thank|cảm ơn|hóa đơn|'
    r'invoice|receipt|địa chỉ|address|hotline|sđt|bàn số|table)',
    caseSensitive: false,
  );

  /// Bóc tách danh sách [BillLineItem] từ văn bản thô OCR trả về.
  /// Trả về danh sách rỗng nếu không tìm được dòng món ăn hợp lệ nào.
  static List<BillLineItem> parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final items = <BillLineItem>[];
    int autoIndex = 0;

    for (final line in lines) {
      if (_skipLineRegex.hasMatch(line)) continue;

      final match = _priceRegex.firstMatch(line);
      if (match == null) continue;

      final priceText = match.group(1)!;
      final price = _parsePrice(priceText);
      if (price < 1000) continue; // Bỏ số quá nhỏ (khả năng là STT, số lượng)

      var name = line.substring(0, match.start).trim();
      // Loại bỏ số lượng/đơn giá dạng "x2", "2x" còn sót ở cuối tên món
      name = name.replaceAll(RegExp(r'[xX]\s*\d+\s*$'), '').trim();
      // Loại bỏ số thứ tự đầu dòng dạng "1.", "1)", "01 "
      name = name.replaceFirst(RegExp(r'^\d{1,2}[.)\s]+'), '').trim();

      if (name.isEmpty) {
        name = 'Món ${autoIndex + 1}';
      }

      items.add(
        BillLineItem(
          id: 'ocr-${DateTime.now().millisecondsSinceEpoch}-$autoIndex',
          name: name,
          price: price,
        ),
      );
      autoIndex++;
    }

    return items;
  }

  static double _parsePrice(String raw) {
    // "55,000" hoặc "55.000" -> 55000 ; "55000" -> 55000
    final cleaned = raw.replaceAll(RegExp(r'[.,]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }
}
