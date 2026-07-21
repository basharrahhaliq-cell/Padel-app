import 'package:flutter_test/flutter_test.dart';
import 'package:padel_app/src/utils/validators.dart';

void main() {
  group('Lebanese phone validation', () {
    test('accepts common mobile formats and normalizes to +961', () {
      expect(LebanesePhone.normalize('03 123 456'), '+9613123456');
      expect(LebanesePhone.normalize('70123456'), '+96170123456');
      expect(LebanesePhone.normalize('+961 3 123456'), '+9613123456');
      expect(LebanesePhone.normalize('961-71-123-456'), '+96171123456');
      expect(LebanesePhone.normalize('0096176123456'), '+96176123456');
      expect(LebanesePhone.normalize('81 234 567'), '+96181234567');
      expect(LebanesePhone.normalize('(78) 123-456'), '+96178123456');
    });

    test('accepts landlines', () {
      expect(LebanesePhone.normalize('01 234 567'), '+9611234567');
      expect(LebanesePhone.normalize('05 462 123'), '+9615462123');
    });

    test('rejects invalid numbers', () {
      expect(LebanesePhone.normalize(''), isNull);
      expect(LebanesePhone.normalize('abc'), isNull);
      expect(LebanesePhone.normalize('12345'), isNull);
      expect(LebanesePhone.normalize('02 123 456'), isNull); // no area 2
      expect(LebanesePhone.normalize('70 1234'), isNull); // too short
      expect(LebanesePhone.normalize('70 1234567'), isNull); // too long
      expect(LebanesePhone.normalize('+1 555 123 4567'), isNull); // US
    });

    test('isValid mirrors normalize', () {
      expect(LebanesePhone.isValid('03123456'), isTrue);
      expect(LebanesePhone.isValid('99 999 999'), isFalse);
    });
  });
}
