/// Kết quả bóc tách thông tin từ thông báo biến động số dư ngân hàng
class ParsedBankNotification {
  final String bankName;
  final double amount;
  final bool isMoneyIn; // true: Tiền vào (+), false: Tiền ra (-)
  final String? debtCode; // Mã định danh BSxxxxx (nếu tìm thấy)
  final String rawContent;
  final DateTime timestamp;

  ParsedBankNotification({
    required this.bankName,
    required this.amount,
    required this.isMoneyIn,
    this.debtCode,
    required this.rawContent,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'ParsedBankNotification(bank: $bankName, amount: $amount, in: $isMoneyIn, code: $debtCode)';
  }
}

/// Bộ phân tích thông báo ngân hàng tổng quát (Universal Bank Parser)
class UniversalBankParser {
  // Regex bắt mã định danh nợ dạng BS + 4-6 ký tự chữ/số (mặc định chuẩn BS + 5 ký tự)
  static final RegExp _debtCodeRegex = RegExp(r'\b(BS[A-Za-z0-9]{4,6})\b', caseSensitive: false);

  // Regex nhận diện số tiền có dấu biến động +/- hoặc gắn liền với đơn vị tiền tệ VND/VNĐ/đ/d
  // hoặc có dấu phân tách hàng nghìn (chấm hoặc phẩy)
  static final RegExp _amountWithPrefixRegex = RegExp(
    r'(?:[\+\-]\s*)([\d]{1,3}(?:[.,]\d{3})+|\d+)(?:\s*(?:VND|VNĐ|đ|d))?',
    caseSensitive: false,
  );

  static final RegExp _amountWithSuffixRegex = RegExp(
    r'([\d]{1,3}(?:[.,]\d{3})+)(?:\s*(?:VND|VNĐ|đ|d))',
    caseSensitive: false,
  );

  static final RegExp _amountGeneralSeparatorRegex = RegExp(
    r'([\d]{1,3}(?:[.,]\d{3})+)',
  );

  // Từ khóa chỉ chiều Tiền vào (+)
  static final List<String> _moneyInKeywords = [
    '+',
    'cong',
    'tang',
    'nhan tu',
    'chuyen den',
    'tien vao',
    'nhan tien',
    'nhan chuyen khoan',
  ];

  // Từ khóa chỉ chiều Tiền ra (-)
  static final List<String> _moneyOutKeywords = [
    '-',
    'tru',
    'giam',
    'thanh toan',
    'chuyen di',
    'chuyen tien',
    'rut tien',
    'phi',
    'so du giam',
  ];

  /// Phân tích nội dung thông báo
  static ParsedBankNotification? parse({
    required String bankName,
    required String content,
    DateTime? timestamp,
  }) {
    if (content.trim().isEmpty) return null;

    final lower = content.toLowerCase();
    final time = timestamp ?? DateTime.now();

    // 1. Trích xuất số tiền theo thứ tự ưu tiên chính xác nhất:
    // Ưu tiên 1: Có dấu +/- phía trước (ví dụ: +200,000VND hoặc -150.000)
    // Ưu tiên 2: Có dấu phân tách hàng nghìn kèm đơn vị VND/VNĐ/đ
    // Ưu tiên 3: Có dấu phân tách hàng nghìn
    double? extractedAmount;
    bool? signFromAmount;

    final matchWithPrefix = _amountWithPrefixRegex.firstMatch(content);
    if (matchWithPrefix != null) {
      final matchedFull = matchWithPrefix.group(0)!;
      if (matchedFull.contains('+')) {
        signFromAmount = true;
      } else if (matchedFull.contains('-')) {
        signFromAmount = false;
      }

      final rawNum = matchWithPrefix.group(1);
      if (rawNum != null) {
        final clean = rawNum.replaceAll('.', '').replaceAll(',', '');
        extractedAmount = double.tryParse(clean);
      }
    }

    if (extractedAmount == null) {
      final matchWithSuffix = _amountWithSuffixRegex.firstMatch(content);
      if (matchWithSuffix != null) {
        final rawNum = matchWithSuffix.group(1);
        if (rawNum != null) {
          final clean = rawNum.replaceAll('.', '').replaceAll(',', '');
          extractedAmount = double.tryParse(clean);
        }
      }
    }

    if (extractedAmount == null) {
      final generalMatches = _amountGeneralSeparatorRegex.allMatches(content);
      for (final m in generalMatches) {
        final rawNum = m.group(1);
        if (rawNum != null) {
          final clean = rawNum.replaceAll('.', '').replaceAll(',', '');
          final val = double.tryParse(clean);
          if (val != null && val >= 1000) {
            extractedAmount = val;
            break;
          }
        }
      }
    }

    // Nếu không tìm được số tiền hợp lệ
    if (extractedAmount == null || extractedAmount < 1000) {
      return null;
    }

    // 2. Xác định chiều tiền (Tiền vào hay Tiền ra)
    bool isMoneyIn = false;
    if (signFromAmount != null) {
      isMoneyIn = signFromAmount;
    } else {
      bool directionDetected = false;
      for (final kw in _moneyInKeywords) {
        if (lower.contains(kw)) {
          isMoneyIn = true;
          directionDetected = true;
          break;
        }
      }
      if (!directionDetected) {
        for (final kw in _moneyOutKeywords) {
          if (lower.contains(kw)) {
            isMoneyIn = false;
            directionDetected = true;
            break;
          }
        }
      }
    }

    // 3. Trích xuất mã định danh nợ BSxxxxx
    String? debtCode;
    final codeMatch = _debtCodeRegex.firstMatch(content);
    if (codeMatch != null) {
      debtCode = codeMatch.group(1)?.toUpperCase();
    }

    return ParsedBankNotification(
      bankName: bankName,
      amount: extractedAmount,
      isMoneyIn: isMoneyIn,
      debtCode: debtCode,
      rawContent: content,
      timestamp: time,
    );
  }
}
