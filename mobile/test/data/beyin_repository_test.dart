import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/beyin.dart';

import '../test_destek.dart';

void main() {
  group('models parse what /api/beyin answers (taken from a real answer)', () {
    test('project detail', () {
      final p = ProjeDetay.fromJson({
        'kimlik': 'kitap-kulubu',
        'baslik': 'Kitap Kulübü Sitesi',
        'durum': 'Okuma listesi sayfası bitti.',
        'siradakiAdim': 'Buluşma takvimi sayfası',
        'acikGorevler': [
          {
            'kimlik': 'bulusma-takvimi-sayfasi',
            'baslik': 'Buluşma takvimi sayfası',
            'durum': 'aktif',
            'bitis': '2026-11-10',
            'oncelik': 'yuksek',
            'sonrakiAdim': 'Ay görünümünü çiz',
          },
          {'kimlik': 'mobil', 'baslik': 'Mobil', 'durum': 'bekliyor', 'bitis': null, 'oncelik': null, 'sonrakiAdim': null},
        ],
        'sonGunluk': [
          {'zaman': '2026-11-03 18:42', 'baslik': 'Okuma listesi', 'metin': 'Liste sayfası bitti.'},
        ],
      });

      expect(p.acikGorevler.first.bitis, DateTime.utc(2026, 11, 10));
      expect(p.acikGorevler.last.bitis, isNull);
      expect(p.sonGunluk.single.zaman, '2026-11-03 18:42');
      expect(ProjeOzet.fromJson({'kimlik': 'a', 'baslik': 'A'}).hedef, 'projects/a');
    });

    test('search hit and note', () {
      final a = AramaSonucu.fromJson({'yol': 'gelen/x.md', 'baslik': 'X', 'proje': null, 'alan': 'gelen', 'alinti': 'ö'});
      expect(a.alan, 'gelen');

      final n = BeyinNotu.fromJson({'yol': 'a/b.md', 'baslik': 'B', 'etiketler': ['mimari'], 'govde': '# Başlık'});
      expect(n.etiketler, ['mimari']);
    });
  });

  group('project list on the phone', () {
    late TestOrtami ortam;

    setUp(() {
      ortam = TestOrtami();
      ortam.api.projeler = const [
        ProjeOzet(kimlik: 'balkon-bahcesi', baslik: 'Balkon Bahçesi'),
        ProjeOzet(kimlik: 'kitap-kulubu', baslik: 'Kitap Kulübü'),
      ];
    });
    tearDown(() async => ortam.kapat());

    test('every successful read replaces the kept list', () async {
      expect(await ortam.beyin.yerelProjeler(), isEmpty);

      final ilk = await ortam.beyin.projeleriGetir();
      expect(ilk.cevrimdisi, isFalse);
      expect((await ortam.beyin.yerelProjeler()).map((p) => p.kimlik), ['balkon-bahcesi', 'kitap-kulubu']);

      ortam.api.projeler = const [ProjeOzet(kimlik: 'staj', baslik: 'Staj')];
      await ortam.beyin.projeleriGetir();
      expect((await ortam.beyin.yerelProjeler()).map((p) => p.kimlik), ['staj'], reason: 'replaced, not appended');
    });

    test('offline: the kept list comes back and says so', () async {
      await ortam.beyin.projeleriGetir();
      ortam.api.beyinCevrimdisi = true;

      final sonuc = await ortam.beyin.projeleriGetir();

      expect(sonuc.cevrimdisi, isTrue);
      expect(sonuc.liste.map((p) => p.baslik), ['Balkon Bahçesi', 'Kitap Kulübü']);
      expect(await ortam.beyin.projeleriYenile(), isFalse);
    });

    test('503: thrown to the screen, the kept list stays for the picker', () async {
      await ortam.beyin.projeleriGetir();
      ortam.api.beyinHatasi = 503;

      await expectLater(ortam.beyin.projeleriGetir(), throwsA(isA<Exception>()));
      expect(await ortam.beyin.yerelProjeler(), hasLength(2));
      expect(await ortam.beyin.projeleriYenile(), isFalse);
    });

    test('403: thrown, and the phone forgets the project names', () async {
      await ortam.beyin.projeleriGetir();
      ortam.api.beyinHatasi = 403;

      await expectLater(ortam.beyin.projeleriGetir(), throwsA(isA<Exception>()));
      expect(await ortam.beyin.yerelProjeler(), isEmpty);
    });

    test('sign-out wipes the kept list with the rest of the cache', () async {
      await ortam.beyin.projeleriGetir();

      await ortam.db.hepsiniTemizle();

      expect(await ortam.beyin.yerelProjeler(), isEmpty);
    });
  });
}
