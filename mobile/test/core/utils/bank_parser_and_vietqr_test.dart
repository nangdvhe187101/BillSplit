import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/crc16.dart';
import 'package:mobile/core/utils/universal_bank_parser.dart';
import 'package:mobile/core/utils/vietqr_encoder.dart';

void main() {
  group('VietQR & CRC16 Tests', () {
    test('CRC16 calculates known checksum correctly', () {
      // Chuỗi mẫu "123456789" có CRC-16/CCITT-FALSE là 0x29B1
      final hex = Crc16.calculateHex('123456789');
      expect(hex, '29B1');
    });

    test('VietQrEncoder encodes EMVCo payload with exact tags and CRC', () {
      final payload = VietQrEncoder.encode(
        bankBin: '970422', // MBBank
        accountNo: '0912345678',
        amount: 150000,
        memo: 'BS8K2M TRANO',
      );

      expect(payload.startsWith('000201010212'), isTrue);
      expect(payload.contains('A000000727'), isTrue);
      expect(payload.contains('970422'), isTrue);
      expect(payload.contains('0912345678'), isTrue);
      expect(payload.contains('5406150000'), isTrue);
      expect(payload.contains('BS8K2M TRANO'), isTrue);
      expect(payload.contains('6304'), isTrue);
      expect(payload.length > 50, isTrue);
    });
  });

  group('UniversalBankParser Tests', () {
    test('Parses MBBank outgoing transaction (-)', () {
      const msg = 'TK 0912345678|GD: -150,000VND 25/10/26 12:30|SD: 2,450,000VND|ND: HAIDILAO AN TRUA';
      final result = UniversalBankParser.parse(bankName: 'MBBank', content: msg);

      expect(result, isNotNull);
      expect(result!.isMoneyIn, isFalse);
      expect(result.amount, 150000.0);
      expect(result.debtCode, isNull);
    });

    test('Parses TPBank incoming transaction (+) with debt code BS8K2M', () {
      const msg = 'So du TK 00012345678 +200,000VND luc 25/10/2026. ND: BS8K2M TRANO TIEN LAU';
      final result = UniversalBankParser.parse(bankName: 'TPBank', content: msg);

      expect(result, isNotNull);
      expect(result!.isMoneyIn, isTrue);
      expect(result.amount, 200000.0);
      expect(result.debtCode, 'BS8K2M');
    });

    test('Parses Vietcombank incoming transaction with lowercase code bs7x2a', () {
      const msg = 'VCB: +50.000 VND vao 001100... luc 14:00. ND: bs7x2a tra no tien com';
      final result = UniversalBankParser.parse(bankName: 'Vietcombank', content: msg);

      expect(result, isNotNull);
      expect(result!.isMoneyIn, isTrue);
      expect(result.amount, 50000.0);
      expect(result.debtCode, 'BS7X2A');
    });

    test('Ignores spam promo messages without amount', () {
      const msg = 'Uu dai hoan tien 50% khi mo the tin dung MB JCB ngay hom nay!';
      final result = UniversalBankParser.parse(bankName: 'MBBank', content: msg);

      expect(result, isNull);
    });
  });
}
