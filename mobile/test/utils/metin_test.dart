import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/utils/metin.dart';

void main() {
  group('dosyaAdiUret', () {
    test('lower case, Turkish letters made plain, separators become one dash', () {
      expect(dosyaAdiUret('Kitap önerisi: Simyacı'), 'kitap-onerisi-simyaci');
      expect(dosyaAdiUret('İŞ ÇIKIŞI — Ğüzel'), 'is-cikisi-guzel');
    });

    test('dashes at the ends are dropped and the name is cut at 80 characters', () {
      expect(dosyaAdiUret('  ...Merhaba!  '), 'merhaba');
      expect(dosyaAdiUret('a' * 120), hasLength(80));
    });

    test('nothing to keep gives an empty name', () {
      expect(dosyaAdiUret('???'), isEmpty);
    });
  });
}
