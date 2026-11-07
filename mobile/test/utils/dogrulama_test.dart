import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/enums.dart';
import 'package:kafamdakiler/utils/dogrulama.dart';
import 'package:kafamdakiler/utils/gun_degeri.dart';

void main() {
  group('"Nereye kadar geldin?" (konumDogrula)', () {
    test('must be a number', () {
      expect(konumDogrula('', baslangic: 12), isNotNull);
      expect(konumDogrula('abc', baslangic: 12), isNotNull);
    });

    test('must be above the start position', () {
      expect(konumDogrula('12', baslangic: 12), contains('büyük'));
      expect(konumDogrula('5', baslangic: 12), contains('büyük'));
      expect(konumDogrula('13', baslangic: 12), isNull);
    });

    test('must not exceed the total when the item has one', () {
      expect(konumDogrula('161', baslangic: 12, toplam: 160), contains('Toplamdan'));
      expect(konumDogrula('160', baslangic: 12, toplam: 160), isNull);
    });

    test('without a total any larger number is fine', () {
      expect(konumDogrula('9999', baslangic: 12), isNull);
    });

    test('accepts a decimal comma', () {
      expect(konumDogrula('12,5', baslangic: 12), isNull);
      expect(sayiCoz('12,5'), 12.5);
    });
  });

  group('password rules', () {
    test('the new password follows Identity\'s defaults, one message at a time', () {
      expect(yeniSifreDogrula(''), 'Yeni şifre gerekli.');
      expect(yeniSifreDogrula('Ab1!'), 'Şifre en az 6 karakter olmalı.');
      expect(yeniSifreDogrula('Abcdef!'), contains('rakam'));
      expect(yeniSifreDogrula('ABCDE1!'), contains('küçük harf'));
      expect(yeniSifreDogrula('abcde1!'), contains('büyük harf'));
      expect(yeniSifreDogrula('Abcde12'), contains('harf ve rakam olmayan'));
      expect(yeniSifreDogrula('Yeni-Parola-2!'), isNull);
    });

    test('Turkish letters count as letters, a space counts as the special character', () {
      expect(yeniSifreDogrula('Şifre1ç!'), isNull);
      expect(yeniSifreDogrula('Abcde 1'), isNull);
    });

    test('the repeat must be filled and equal', () {
      expect(sifreTekrarDogrula('', 'Abc1!x'), 'Şifreyi tekrar yaz.');
      expect(sifreTekrarDogrula('Abc1!y', 'Abc1!x'), 'Şifreler aynı değil.');
      expect(sifreTekrarDogrula('Abc1!x', 'Abc1!x'), isNull);
    });

    test('the current password only has to be given', () {
      expect(mevcutSifreDogrula(''), 'Mevcut şifre gerekli.');
      expect(mevcutSifreDogrula(' '), isNull);
    });
  });

  group('habit form rules', () {
    test('EnAz target must be above zero, EnCok may be zero', () {
      expect(hedefDogrula('0', HedefYonu.enAz), isNotNull);
      expect(hedefDogrula('0', HedefYonu.enCok), isNull);
      expect(hedefDogrula('', HedefYonu.enAz), isNotNull);
      expect(hedefDogrula('8', HedefYonu.enAz), isNull);
    });

    test('weekly count is 1-6', () {
      expect(haftalikSayiDogrula('0'), isNotNull);
      expect(haftalikSayiDogrula('7'), isNotNull);
      expect(haftalikSayiDogrula('3'), isNull);
    });

    test('name is required and limited', () {
      expect(zorunluMetin('  ', 'Ad'), isNotNull);
      expect(zorunluMetin('x' * 101, 'Ad', max: 100), isNotNull);
      expect(zorunluMetin('Su', 'Ad', max: 100), isNull);
    });
  });

  group('item form rules', () {
    test('total must exceed the start position when given', () {
      expect(ogeToplamDogrula('', 0), isNull);
      expect(ogeToplamDogrula('10', 10), isNotNull);
      expect(ogeToplamDogrula('11', 10), isNull);
    });

    test('rating 1-5, note 2000 characters', () {
      expect(puanDogrula(null), isNull);
      expect(puanDogrula(0), isNotNull);
      expect(puanDogrula(6), isNotNull);
      expect(puanDogrula(5), isNull);
      expect(notDogrula('x' * 2001), isNotNull);
    });
  });

  group('gunDegeri', () {
    test('EnAz is partial up to 1', () {
      expect(gunDegeri(olcu: Olcu.sayili, hedefYonu: HedefYonu.enAz, hedef: 30, miktar: 15), 0.5);
      expect(gunDegeri(olcu: Olcu.sayili, hedefYonu: HedefYonu.enAz, hedef: 30, miktar: 90), 1);
    });

    test('EnCok is 1 until the limit is exceeded', () {
      expect(gunDegeri(olcu: Olcu.sayili, hedefYonu: HedefYonu.enCok, hedef: 2, miktar: 0), 1);
      expect(gunDegeri(olcu: Olcu.sayili, hedefYonu: HedefYonu.enCok, hedef: 2, miktar: 2), 1);
      expect(gunDegeri(olcu: Olcu.sayili, hedefYonu: HedefYonu.enCok, hedef: 2, miktar: 3), 0);
    });

    test('yes/no is 1 once ticked', () {
      expect(gunDegeri(olcu: Olcu.evetHayir, hedefYonu: HedefYonu.enAz, hedef: null, miktar: 1), 1);
      expect(gunDegeri(olcu: Olcu.evetHayir, hedefYonu: HedefYonu.enAz, hedef: null, miktar: 0), 0);
    });
  });
}
