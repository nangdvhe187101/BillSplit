import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/split/data/utils/bill_ocr_parser.dart';

void main() {
  group('BillOcrParser Tests', () {
    test('Bóc tách đúng hóa đơn quán phở (3 tô riêng + quẩy/trứng chung)', () {
      const rawText = '''
QUÁN PHỞ HÀ NỘI
Bàn số: 5
Phở nạm gầu          55,000
Phở chín             40,000
Phở tái chín         45,000
Đĩa quẩy             10,000
Trứng trần x3        15,000
Tạm tính            165,000
Cảm ơn quý khách
''';

      final items = BillOcrParser.parse(rawText);

      expect(items.length, 5);
      expect(items[0].name, 'Phở nạm gầu');
      expect(items[0].price, 55000);
      expect(items[1].name, 'Phở chín');
      expect(items[1].price, 40000);
      expect(items[2].name, 'Phở tái chín');
      expect(items[2].price, 45000);
      expect(items[3].name, 'Đĩa quẩy');
      expect(items[3].price, 10000);
      expect(items[4].price, 15000);

      final total = items.fold(0.0, (sum, i) => sum + i.price);
      expect(total, 165000);
    });

    test('Bỏ qua dòng tổng kết, tiêu đề và địa chỉ', () {
      const rawText = '''
Địa chỉ: 123 Nguyễn Văn A
Hotline: 0909123456
Nước ép cam           50000
Tổng cộng            50000
VAT 10%                5000
''';

      final items = BillOcrParser.parse(rawText);

      expect(items.length, 1);
      expect(items[0].name, 'Nước ép cam');
      expect(items[0].price, 50000);
    });

    test('Bỏ số tiền quá nhỏ (khả năng là số thứ tự hoặc số lượng)', () {
      const rawText = '''
1. Trà đá              5
Phở bò                45000
''';

      final items = BillOcrParser.parse(rawText);

      expect(items.length, 1);
      expect(items[0].name, 'Phở bò');
    });

    test('Trả về danh sách rỗng khi không có dòng món ăn hợp lệ', () {
      const rawText = '''
Cảm ơn quý khách
Hẹn gặp lại
''';

      final items = BillOcrParser.parse(rawText);

      expect(items, isEmpty);
    });
  });
}
