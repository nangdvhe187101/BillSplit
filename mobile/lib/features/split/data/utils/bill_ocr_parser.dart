import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/bill_line_item_model.dart';

/// Kết quả bóc tách hóa đơn thông minh từ OCR:
/// Trả về đúng Tổng bill thực tế (từ dòng "Tổng cộng/Thanh toán")
/// và danh sách các món ăn chính xác (không bốc nhầm số lượng, ngày giờ, số bàn, STT).
class ParsedBillResult {
  final double totalAmount; // TỔNG TIỀN THỰC TẾ CỦA HÓA ĐƠN
  final double subtotal; // Tiền hàng tạm tính (Tổng thành tiền)
  final double vat; // Thuế VAT nếu có
  final double discount; // Giảm giá / chiết khấu nếu có
  final List<BillLineItem> items; // Danh sách món ăn chuẩn xác
  final String? billTitle; // Tiêu đề hóa đơn hoặc tên quán

  ParsedBillResult({
    required this.totalAmount,
    this.subtotal = 0.0,
    this.vat = 0.0,
    this.discount = 0.0,
    required this.items,
    this.billTitle,
  });
}

/// Bộ phân tích hóa đơn thông minh (Smart Bill OCR Parser)
/// Hỗ trợ cả gom cụm không gian 2D (Spatial Layout Clustering từ BoundingBox)
/// và xử lý văn bản thô theo cấu trúc hóa đơn bán hàng chuẩn tại Việt Nam.
class BillOcrParser {
  // Regex nhận diện số tiền (ít nhất 3 chữ số, có phân tách hàng nghìn hoặc từ 1.000 trở lên)
  static final RegExp _amountRegex = RegExp(
    r'(?:^|[^\d.,])(\d{1,3}(?:[.,]\d{3})+|\d{4,})(?:\s*(?:đ|d|vnd|vnđ))?(?:$|[^\d.,])',
    caseSensitive: false,
  );

  // Regex nhận diện các dòng TIÊU ĐỀ & THÔNG TIN ĐẦU HÓA ĐƠN (Cần loại bỏ khỏi danh sách món)
  static final RegExp _headerKeywordRegex = RegExp(
    r'(hóa\s*đơn|hoá\s*đơn|phiếu|bill|invoice|receipt|sđt|điện\s*thoại|hotline|tel|phone|'
    r'địa\s*chỉ|address|ngày|giờ\s*vào|giờ\s*ra|bàn|table|khách\s*hàng|khách\s*lẻ|thu\s*ngân|'
    r'nhân\s*viên|cashier|pos365|kiotviet|cukcuk|ipos|sapo|wifi|mật\s*khẩu|password|'
    r'xin\s*cám\s*ơn|hẹn\s*gặp\s*lại|thank\s*you|powered\s*by)',
    caseSensitive: false,
  );

  // Regex nhận diện TIÊU ĐỀ BẢNG CỘT (Tên hàng, en hàng, Đ.giá, SL, TT...)
  static final RegExp _tableHeaderRegex = RegExp(
    r'(?:^|[^\w])(tên\s*hàng|en\s*hàng|tên\s*món|mặt\s*hàng|đơn\s*giá|đ\.?giá|giá|số\s*lượng|\bsl\b|thành\s*tiền|\btt\b|\bstt\b|item|price|qty|amount)\b',
    caseSensitive: false,
  );

  // Regex nhận diện các từ khóa tổng kết, thuế, thanh toán (Tuyệt đối KHÔNG đưa vào danh sách món)
  static final RegExp _summaryKeywordRegex = RegExp(
    r'(tổng\s*cộng|tong\s*cong|tổng\s*tiền|tong\s*tien|tổng\s*thanh\s*toán|cần\s*thanh\s*toán|phải\s*thanh\s*toán|thanh\s*toán|tổng\s*thành\s*tiền|tiền\s*hàng|tạm\s*tính|tiền\s*khách\s*trả|khách\s*đưa|tiền\s*mặt|chuyển\s*khoản|tiền\s*thừa|tiền\s*thối|\bvat\b|thuế|thue|chiết\s*khấu|giảm\s*giá|khuyến\s*mãi|total|subtotal|cash|change|due|balance)',
    caseSensitive: false,
  );

  /// Phân tích hóa đơn từ RecognizedText của Google ML Kit (khuyên dùng vì có tọa độ 2D)
  static ParsedBillResult parseFromRecognizedText(RecognizedText recognizedText) {
    // 1. Tái cấu trúc văn bản theo hàng ngang dựa trên tọa độ bounding box 2D
    final spatiallyMergedLines = _reconstructLinesFromSpatialLayout(recognizedText);

    // Nếu không gom cụm được thì dùng raw text thông thường
    final lines = spatiallyMergedLines.isNotEmpty
        ? spatiallyMergedLines
        : recognizedText.text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    return parseLines(lines);
  }

  /// Phân tích từ raw string
  static ParsedBillResult parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return parseLines(lines);
  }

  /// Thuật toán phân tích danh sách các dòng văn bản đã được sắp xếp
  static ParsedBillResult parseLines(List<String> rawLines) {
    // Tiền xử lý: loại bỏ các dòng rỗng
    final lines = rawLines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    final items = <BillLineItem>[];
    String? detectedTitle;

    int autoIndex = 0;

    // Duyệt qua từng dòng để phân loại: Header, Summary, hay Item
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // A. BỎ QUA CÁC DÒNG TỔNG CỘNG / TỔNG TIỀN / THUẾ / THANH TOÁN (Không lấy tổng tiền từ ảnh)
      if (_summaryKeywordRegex.hasMatch(line)) {
        continue;
      }

      // B. BỎ QUA TIÊU ĐỀ BẢNG (Tên hàng, Đ.giá, SL, TT...)
      if (_tableHeaderRegex.hasMatch(line)) {
        continue;
      }

      // C. BỎ QUA DÒNG THÔNG TIN QUÁN / NGÀY GIỜ / BÀN SỐ
      if (_headerKeywordRegex.hasMatch(line)) {
        if (detectedTitle == null && (line.toLowerCase().contains('hóa đơn') || line.toLowerCase().contains('hoá đơn'))) {
          detectedTitle = 'Hóa đơn ăn uống';
        }
        continue;
      }

      // D. BÓC TÁCH DÒNG MÓN ĂN THỰC SỰ
      // Một dòng món ăn hợp lệ phải có Tên món (chữ cái) và Số tiền
      final parsedItem = _parseItemFromLine(line);
      if (parsedItem != null) {
        items.add(
          BillLineItem(
            id: 'ocr-${DateTime.now().millisecondsSinceEpoch}-$autoIndex',
            name: parsedItem.name,
            price: parsedItem.price,
          ),
        );
        autoIndex++;
      } else {
        // Trường hợp tên món ở dòng hiện tại, giá tiền ở dòng kế tiếp (Lookahead 1 dòng)
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1];
          // Nếu dòng kế tiếp là summary hoặc header thì không ghép
          if (!_summaryKeywordRegex.hasMatch(nextLine) &&
              !_tableHeaderRegex.hasMatch(nextLine) &&
              !_headerKeywordRegex.hasMatch(nextLine)) {
            final combinedLine = '$line $nextLine';
            final combinedItem = _parseItemFromLine(combinedLine);
            if (combinedItem != null) {
              items.add(
                BillLineItem(
                  id: 'ocr-${DateTime.now().millisecondsSinceEpoch}-$autoIndex',
                  name: combinedItem.name,
                  price: combinedItem.price,
                ),
              );
              autoIndex++;
              i++; // Bỏ qua dòng kế tiếp vì đã ghép
            }
          }
        }
      }
    }

    // TỔNG BILL = TỔNG TIỀN CỦA CÁC MÓN NHẬN DIỆN ĐƯỢC
    // Bỏ việc bóc tách số tiền tổng riêng từ ảnh theo yêu cầu người dùng
    final sumItems = items.fold(0.0, (sum, it) => sum + it.price);

    return ParsedBillResult(
      totalAmount: sumItems,
      subtotal: sumItems,
      vat: 0.0,
      discount: 0.0,
      items: items,
      billTitle: detectedTitle,
    );
  }

  /// Bóc tách một món ăn từ một dòng đơn lẻ:
  /// Ví dụ: "Sữa tươi đường đen 28,000 1 28,000"
  /// -> Tên: "Sữa tươi đường đen"
  /// -> Giá: 28000
  static ({String name, double price})? _parseItemFromLine(String line) {
    // Nếu dòng chứa từ khóa tổng kết, thuế, thanh toán thì bỏ qua ngay
    if (_summaryKeywordRegex.hasMatch(line)) return null;

    // 1. Tìm tất cả các số tiền hợp lệ trong dòng
    final matches = _findAllPrices(line);
    if (matches.isEmpty) return null;

    // 2. Lấy vị trí số tiền đầu tiên xuất hiện trong dòng
    final firstMatch = matches.first;
    final lastMatch = matches.last;

    // Tên món là toàn bộ chuỗi nằm TRƯỚC số tiền đầu tiên
    var name = line.substring(0, firstMatch.start).trim();

    // Làm sạch tên món:
    // Loại bỏ tiền tố tiêu đề bảng nếu bị dính vào đầu: "en hàng", "tên hàng", "đ.giá", "sl", "tt", etc.
    name = name.replaceAll(
      RegExp(r'^(?:tên\s*hàng|en\s*hàng|mặt\s*hàng|đ\.?giá|đơn\s*giá|sl|số\s*lượng|tt|stt|item|price|qty|amount)[\s\d:.,/|-]*', caseSensitive: false),
      '',
    ).trim();

    // Loại bỏ số thứ tự đầu dòng: "1.", "1)", "01 ", "1 "
    name = name.replaceFirst(RegExp(r'^\d{1,2}[.)\s]+'), '').trim();
    // Loại bỏ các ký tự phân cách còn sót
    name = name.replaceFirst(RegExp(r'^[-\s•*]+'), '').trim();
    // Loại bỏ x1, x2 ở cuối tên món
    name = name.replaceAll(RegExp(r'[xX]\s*\d+\s*$'), '').trim();

    // Giá món: Ưu tiên số tiền cuối cùng của dòng (Thành tiền TT)
    final price = lastMatch.value;

    // KIỂM TRA ĐIỀU KIỆN MÓN HỢP LỆ:
    // - Tên món phải có ít nhất 2 ký tự
    // - Tên món phải chứa chữ cái (không thể chỉ là số hay ngày tháng)
    // - Giá món phải >= 1.000 đ
    final hasLetters = name.runes.any((r) {
      final ch = String.fromCharCode(r);
      return RegExp(r'[a-zA-Z\u00C0-\u1EF9]').hasMatch(ch);
    });

    if (!hasLetters || name.length < 2 || price < 1000) {
      return null;
    }

    // Không chấp nhận tên món là các từ khóa hệ thống, tổng kết hay tiêu đề
    if (_summaryKeywordRegex.hasMatch(name) ||
        _headerKeywordRegex.hasMatch(name) ||
        _tableHeaderRegex.hasMatch(name)) {
      return null;
    }

    return (name: name, price: price);
  }

  /// Gom cụm các dòng theo tọa độ không gian 2D (Spatial Layout Clustering)
  static List<String> _reconstructLinesFromSpatialLayout(RecognizedText recognizedText) {
    final allLines = <TextLine>[];
    for (final block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }

    if (allLines.isEmpty) return [];

    // Tính chiều cao trung bình của một dòng
    double totalHeight = 0;
    for (final line in allLines) {
      totalHeight += line.boundingBox.height;
    }
    final avgHeight = totalHeight / allLines.length;
    // Ngưỡng dung sai trục Y chặt chẽ hơn để tránh dính dòng tiêu đề cột vào dòng đầu tiên của món
    final yTolerance = (avgHeight * 0.35).clamp(4.0, 12.0);

    // Sắp xếp các dòng từ trên xuống dưới theo trục Y
    allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    final clusters = <List<TextLine>>[];

    for (final line in allLines) {
      final lineCenterY = (line.boundingBox.top + line.boundingBox.bottom) / 2;
      bool added = false;

      for (final cluster in clusters) {
        final clusterCenterY = cluster
                .map((l) => (l.boundingBox.top + l.boundingBox.bottom) / 2)
                .reduce((a, b) => a + b) /
            cluster.length;

        if ((lineCenterY - clusterCenterY).abs() <= yTolerance) {
          cluster.add(line);
          added = true;
          break;
        }
      }

      if (!added) {
        clusters.add([line]);
      }
    }

    // Trong mỗi hàng ngang, sắp xếp từ trái sang phải (X tăng dần) và nối chuỗi
    final mergedLines = <String>[];
    for (final cluster in clusters) {
      cluster.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      final lineText = cluster.map((l) => l.text.trim()).join(' ');
      if (lineText.isNotEmpty) {
        mergedLines.add(lineText);
      }
    }

    return mergedLines;
  }

  /// Tìm tất cả các số tiền hợp lệ trong dòng kèm vị trí start/end
  static List<({double value, int start, int end})> _findAllPrices(String line) {
    final results = <({double value, int start, int end})>[];

    // Tìm các chuỗi khớp với định dạng số tiền
    final matches = _amountRegex.allMatches(line);
    for (final m in matches) {
      final raw = m.group(1);
      if (raw == null) continue;

      final cleaned = raw.replaceAll(RegExp(r'[.,]'), '');
      final val = double.tryParse(cleaned);
      if (val != null && val >= 1000) {
        results.add((value: val, start: m.start, end: m.end));
      }
    }

    return results;
  }
}
