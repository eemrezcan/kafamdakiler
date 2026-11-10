import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/enums.dart';
import 'package:kafamdakiler/data/models/gun_gorunum.dart';
import 'package:kafamdakiler/data/models/hatirlatici.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';
import 'package:kafamdakiler/utils/aliskanlik_gunu.dart';

import '../test_destek.dart';

/// The day view's data side (K-0024, sözleşme §1-§5): reads kept for offline, the queued writes laid on the day, and what
/// the sender does with each of them.
void main() {
  late TestOrtami ortam;

  setUp(() => ortam = TestOrtami());
  tearDown(() async => ortam.kapat());

  final bugun = sabitBugun; // 2026-10-31
  final yarin = DateTime.utc(2026, 11, 1);
  final dun = DateTime.utc(2026, 10, 30);

  final isler = [
    ornekYapilacak(kimlik: 'e:1', baslik: 'Ders', saat: '09:00'),
    ornekYapilacak(kimlik: 'm:aa11bb', baslik: 'E-kampüs', saat: '14:00', tahminDk: 15, hatirlatici: const HatirlaticiOzet(id: 'r1', saat: '14:00')),
    ornekYapilacak(kimlik: 'm:cc22dd', baslik: 'Slaytlar', tahminDk: 120),
    ornekYapilacak(kimlik: 'g:rapor', baslik: 'Rapor', tahminDk: 60),
    ornekYapilacak(kimlik: 'm:ee33ff', baslik: 'Tahminsiz'),
  ];

  Future<GunGorunum> yerel() async => (await ortam.gun.yerel(bugun))!;

  /// Reads the day once while online, so it is on the phone; then the connection is lost.
  Future<void> gunuAl({GunGorunum? gun}) async {
    ortam.api.gunGorunumleri[tarihMetni(bugun)] = gun ?? ornekGun(ogeler: isler, dunden: const [DundenKalan(maddeId: 'ab12cd', baslik: 'Market', tahminDk: 45)]);
    await ortam.gun.oku(bugun);
    ortam.api.cevrimdisi = true;
  }

  group('reads', () {
    test('a read is kept; without a connection the kept day comes back and says so', () async {
      ortam.api.gunGorunumleri['2026-10-31'] = ornekGun(ogeler: isler);

      final canli = await ortam.gun.oku(bugun);
      expect(canli.cevrimdisi, isFalse);
      expect(canli.gun.ogeler, hasLength(5));

      ortam.api.cevrimdisi = true;
      final yedek = await ortam.gun.oku(bugun);
      expect(yedek.cevrimdisi, isTrue);
      expect(yedek.gun.ogeler.map((o) => o.kimlik), canli.gun.ogeler.map((o) => o.kimlik));
    });

    test('offline with nothing kept: the error is thrown; a server error is thrown even with a kept day', () async {
      ortam.api.cevrimdisi = true;
      await expectLater(ortam.gun.oku(bugun), throwsA(isA<DioException>()));

      ortam.api.cevrimdisi = false;
      await ortam.gun.oku(bugun);
      ortam.api.sunucuHatasi = 403;
      await expectLater(ortam.gun.oku(bugun), throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 403)));
    });

    test('the day parses with every field of the contract', () {
      final gun = GunGorunum.fromJson({
        'tarih': '2026-11-10',
        'bugun': true,
        'kapandi': false,
        'ozet': 'Bugün 7 iş var.',
        'yuk': {'acikTahminDk': 440, 'etkinlikDk': 60, 'kapasiteDk': 360, 'asimDk': 140, 'bosDk': 0, 'tahminsizSayi': 1},
        'dundenKalanlar': [
          {'maddeId': 'ab12cd', 'baslik': 'Market', 'tahminDk': 45, 'proje': null},
        ],
        'ogeler': [
          {
            'kimlik': 'm:aa11bb',
            'tur': 'plan',
            'baslik': 'Spor salonu',
            'saat': '18:30',
            'bitisSaati': null,
            'tumGun': false,
            'tahminDk': 90,
            'durum': 'acik',
            'bolunmus': {'sira': 1, 'toplam': 2},
            'hatirlatici': {'id': 'f3a1', 'saat': '18:30', 'tekrar': 'haftalik', 'gunler': ['sal', 'per'], 'acil': false, 'israrli': true, 'onceGun': 1},
            'maddeId': 'aa11bb',
          },
          {'kimlik': 'e:3b2', 'tur': 'etkinlik', 'baslik': 'Ders', 'tumGun': false, 'durum': 'acik', 'yer': 'B-204'},
        ],
        'kaynaklar': {'plan': 'tamam', 'google': 'bagli', 'sonEsitleme': '2026-11-10T08:00:00+03:00'},
      });

      expect(gun.tarih, DateTime.utc(2026, 11, 10));
      expect(gun.yuk.toplamDk, 500);
      expect(gun.yuk.asimDk, 140);
      expect(gun.dundenKalanlar.single.maddeId, 'ab12cd');
      final spor = gun.ogeler.first;
      expect(spor.tur, YapilacakTuru.plan);
      expect(spor.bolunmus!.toplam, 2);
      expect(spor.hatirlatici!.tekrar, Tekrar.haftalik);
      expect(spor.hatirlatici!.gunler, [HaftaGunu.sal, HaftaGunu.per]);
      expect(spor.hatirlatici!.israrli, isTrue);
      expect(gun.ogeler.last.yapilabilir, isFalse);
      expect(gun.ogeler.last.yer, 'B-204');
      expect(gun.kaynaklar.sonEsitleme, isNotNull);
      // And back to JSON and in again, as the cache does.
      expect(GunGorunum.fromJson(gun.toJson()).ogeler.first.hatirlatici!.gunler, [HaftaGunu.sal, HaftaGunu.per]);
    });

    test('the calendar range is kept per range and used offline', () async {
      ortam.api.takvimYaniti = TakvimAraligi(gunler: [
        TakvimGunu(tarih: bugun, sayilar: const TakvimSayilari(plan: 2, hatirlatici: 1), yukAsimi: true),
      ], yaklasan: [ornekYapilacak(kimlik: 'h:r1', baslik: 'Kira öde')]);
      final bas = DateTime.utc(2026, 10, 26);
      final bit = DateTime.utc(2026, 11, 1);

      final canli = await ortam.gun.takvim(bas, bit);
      expect(canli.cevrimdisi, isFalse);
      expect(ortam.api.takvimIstekleri, ['2026-10-26/2026-11-01']);

      ortam.api.cevrimdisi = true;
      final yedek = await ortam.gun.takvim(bas, bit);
      expect(yedek.cevrimdisi, isTrue);
      expect(yedek.aralik.gun(bugun)!.sayilar.toplam, 3);
      expect(yedek.aralik.gun(bugun)!.yukAsimi, isTrue);
      expect(yedek.aralik.yaklasan.single.baslik, 'Kira öde');
      await expectLater(ortam.gun.takvim(DateTime.utc(2026, 11, 2), DateTime.utc(2026, 11, 8)), throwsA(isA<DioException>()));
    });
  });

  group('queued writes laid on the day', () {
    test('a tick marks the row done, takes its estimate off the load and is its own queue entry with the typed id', () async {
      await gunuAl();
      final once = await yerel();
      expect(once.yuk.acikTahminDk, 195);

      await ortam.gun.yaptim(bugun, isler[2]);

      final gun = await yerel();
      expect(gun.ogeler.firstWhere((o) => o.kimlik == 'm:cc22dd').yapildi, isTrue);
      expect(gun.yuk.acikTahminDk, 75, reason: '195 - 120');
      expect(gun.yuk.bosDk, 285);
      final kuyruk = await ortam.esitleyici.bekleyenler();
      expect(kuyruk.single.tur, BekleyenTur.gunYaptim);
      expect(kuyruk.single.hedefId, 'm:cc22dd');
      expect(kuyruk.single.tarih, '2026-10-31');
    });

    test('a tick on a done row asks for the tick back; events and rows not sent yet cannot be ticked', () async {
      await gunuAl();
      await ortam.gun.yaptim(bugun, isler[0]);
      await ortam.gun.ogeEkle(bugun, const YeniOgeYaz(baslik: 'Yeni'));
      final yeniSatir = (await yerel()).ogeler.firstWhere((o) => o.yerel);
      await ortam.gun.yaptim(bugun, yeniSatir);
      expect(await ortam.esitleyici.bekleyenler(), hasLength(1), reason: 'only the new row\'s own add is queued');

      await ortam.gun.yaptim(bugun, ornekYapilacak(kimlik: 'm:cc22dd', baslik: 'Slaytlar', durum: 'yapildi'));
      final geri = (await ortam.esitleyici.bekleyenler()).last;
      expect(geri.tur, BekleyenTur.gunYaptim);
      expect(geri.govde, '{"geri":true}');
    });

    test('a finished task through the old task write is done on the day too', () async {
      await gunuAl();
      await ortam.esitleyici.beyinGorevBitirKuyrugaAl('rapor');
      expect((await yerel()).ogeler.firstWhere((o) => o.kimlik == 'g:rapor').yapildi, isTrue);
    });

    test('a new row shows at once with its estimate, hour and reminder, in hour order, as "yerel:"', () async {
      await gunuAl();

      await ortam.gun.ogeEkle(
        bugun,
        const YeniOgeYaz(
          baslik: 'Diş randevusu',
          saat: '10:30',
          tahminDk: 30,
          hatirlatici: HatirlaticiGovde(tekrar: Tekrar.haftalik, gunler: [HaftaGunu.cum], acil: true),
        ),
      );

      final gun = await yerel();
      final satir = gun.ogeler.firstWhere((o) => o.baslik == 'Diş randevusu');
      expect(satir.yerel, isTrue);
      expect(satir.saat, '10:30');
      expect(satir.hatirlatici!.acil, isTrue);
      expect(gun.ogeler.indexOf(satir), 1, reason: 'between 09:00 and 14:00');
      expect(gun.yuk.acikTahminDk, 225);
      expect(gun.yuk.tahminsizSayi, 1);
    });

    test('a new row for another day is not laid on this day', () async {
      await gunuAl();
      await ortam.gun.ogeEkle(yarin, const YeniOgeYaz(baslik: 'Yarın için'));
      expect((await yerel()).ogeler.where((o) => o.baslik == 'Yarın için'), isEmpty);
    });

    test('a reminder set, changed and removed on a row shows on the row; its hour becomes the row\'s when it had none', () async {
      await gunuAl();
      final slayt = isler[2];

      await ortam.gun.hatirlaticiYaz(bugun, slayt, const HatirlaticiGovde(saat: '16:00', tekrar: Tekrar.gunluk));
      var satir = (await yerel()).ogeler.firstWhere((o) => o.kimlik == 'm:cc22dd');
      expect(satir.hatirlatici!.tekrar, Tekrar.gunluk);
      expect(satir.saat, '16:00');
      expect((await ortam.esitleyici.bekleyenler()).single.govde, contains('"guncelle":false'));

      await ortam.gun.hatirlaticiYaz(bugun, satir, const HatirlaticiGovde(saat: '16:00', tekrar: Tekrar.yok));
      expect((await ortam.esitleyici.bekleyenler()).last.govde, contains('"guncelle":true'), reason: 'the row had a reminder: a change');

      await ortam.gun.hatirlaticiSil(bugun, satir);
      satir = (await yerel()).ogeler.firstWhere((o) => o.kimlik == 'm:cc22dd');
      expect(satir.hatirlatici, isNull);
    });

    test('"Bırak" takes yesterday\'s item off the list; "Bugüne al" moves it onto today as a "yerel:" row', () async {
      await gunuAl(gun: ornekGun(ogeler: isler, dunden: const [DundenKalan(maddeId: 'ab12cd', baslik: 'Market', tahminDk: 45), DundenKalan(maddeId: 'cd34ef', baslik: 'Fatura')]));

      await ortam.gun.dundenBirak(bugun, const DundenKalan(maddeId: 'ab12cd', baslik: 'Market'));
      var gun = await yerel();
      expect(gun.dundenKalanlar.map((d) => d.maddeId), ['cd34ef']);
      final birak = (await ortam.esitleyici.bekleyenler()).single;
      expect(birak.tur, BekleyenTur.dundenBirak);
      expect(birak.tarih, '2026-10-31', reason: 'dated today, the route of the new call');
      expect(gun.ogeler.where((o) => o.baslik == 'Market'), isEmpty, reason: 'letting go adds nothing');

      await ortam.gun.bugunAl(bugun, const DundenKalan(maddeId: 'cd34ef', baslik: 'Fatura', tahminDk: 20));
      gun = await yerel();
      expect(gun.dundenKalanlar, isEmpty);
      final fatura = gun.ogeler.firstWhere((o) => o.baslik == 'Fatura');
      expect(fatura.yerel, isTrue);
      expect(fatura.tahminDk, 20);
      final tasi = (await ortam.esitleyici.bekleyenler()).last;
      expect(tasi.tur, BekleyenTur.gunDevret);
      expect(tasi.hedefId, 'm:cd34ef');
      expect(tasi.tarih, tarihMetni(dun), reason: 'the carry-over is dated yesterday');
    });

    test('carrying rows to tomorrow takes plan items, tasks and reminders off today; events and rows without an id are left alone', () async {
      await gunuAl();

      await ortam.gun.yarinaDevret(bugun, [isler[2], isler[3], isler[1], isler[0], ornekYapilacak(kimlik: 'yerel:x', baslik: 'Yerel')]);

      final gun = await yerel();
      expect(gun.ogeler.map((o) => o.kimlik), ['e:1', 'm:ee33ff'], reason: 'the event stays; the three carried rows are gone');
      final kuyruk = await ortam.esitleyici.bekleyenler();
      expect(kuyruk.map((b) => b.tur), everyElement(BekleyenTur.gunDevret));
      expect(kuyruk.map((b) => b.hedefId), ['m:cc22dd', 'g:rapor', 'm:aa11bb']);
      expect(gun.yuk.acikTahminDk, 0);
    });

    test('a carry-over is sent to its own route with the queue id as the Idempotency-Key', () async {
      await ortam.gun.yarinaDevret(bugun, [isler[3]]);
      final satir = (await ortam.esitleyici.bekleyenler()).single;

      expect(await ortam.esitleyici.gonder(), 1);

      final y = ortam.api.gunYazimlari.single;
      expect(y.tur, 'devret');
      expect(y.tarih, '2026-10-31');
      expect(y.kimlik, 'g:rapor');
      expect(y.anahtar, satir.id);
    });

    test('a note and a split are the old plan and task writes, with the ids they need', () async {
      await gunuAl();

      await ortam.gun.notEkle(bugun, isler[2], '  önce 3. ünite  ');
      await ortam.gun.gunlereBol(bugun, isler[3], 3);
      await ortam.gun.gunlereBol(bugun, isler[2], 3); // a plan row without a task: nothing to split

      final kuyruk = await ortam.esitleyici.bekleyenler();
      expect(kuyruk.map((b) => b.tur), [BekleyenTur.beyinMaddeNot, BekleyenTur.beyinGunlereBol]);
      expect(kuyruk[0].hedefId, 'cc22dd');
      expect(kuyruk[0].govde, contains('önce 3. ünite'));
      expect(kuyruk[1].hedefId, 'rapor');
      expect(kuyruk[1].govde, contains('"baslangic":"2026-10-31"'));
    });

    test('a write the server refused is no longer laid on the day', () async {
      await gunuAl();
      await ortam.gun.yaptim(bugun, isler[2]);
      expect((await yerel()).ogeler.firstWhere((o) => o.kimlik == 'm:cc22dd').yapildi, isTrue);

      ortam.api.cevrimdisi = false;
      ortam.api.gunYazmaHatasi = 409;
      await ortam.esitleyici.gonder();

      expect((await yerel()).ogeler.firstWhere((o) => o.kimlik == 'm:cc22dd').yapildi, isFalse);
      final reddedilen = (await ortam.esitleyici.reddedilenler()).single;
      expect(reddedilen.hata, 'Sunucu bu işi kabul etmedi.');
    });
  });

  group('sending', () {
    test('every write goes to its route; the queue id is the Idempotency-Key where the server takes one', () async {
      await ortam.gun.yaptim(bugun, isler[2]);
      await ortam.gun.ogeEkle(bugun, const YeniOgeYaz(baslik: 'Yeni', saat: '10:00', tahminDk: 30, proje: 'okul', hatirlatici: HatirlaticiGovde(acil: true)));
      await ortam.gun.hatirlaticiYaz(bugun, isler[2], const HatirlaticiGovde(tekrar: Tekrar.haftalik, gunler: [HaftaGunu.sal, HaftaGunu.per]));
      await ortam.gun.hatirlaticiSil(bugun, isler[1]);
      await ortam.gun.dundenBirak(bugun, const DundenKalan(maddeId: 'ab12cd', baslik: 'Market'));
      await ortam.gun.gunAyariYaz(const GunAyari(haftaIciDk: 420, haftaSonuDk: 120));
      final kuyruk = await ortam.esitleyici.bekleyenler();

      expect(await ortam.esitleyici.gonder(), 6);

      final y = ortam.api.gunYazimlari;
      expect(y.map((e) => e.tur), ['yaptim', 'ogeEkle', 'hatirlaticiKur', 'hatirlaticiSil', 'dundenBirak', 'ayarYaz']);
      expect(y[0].kimlik, 'm:cc22dd');
      expect(y[0].govde, {'geri': false});
      expect(y[0].anahtar, kuyruk[0].id);
      expect(y[1].tarih, '2026-10-31');
      expect(y[1].anahtar, kuyruk[1].id);
      expect((y[1].govde as Map)['baslik'], 'Yeni');
      expect((y[1].govde as Map)['tahminDk'], 30);
      expect(((y[1].govde as Map)['hatirlatici'] as Map)['acil'], isTrue);
      expect(y[2].govde, {'tekrar': 'haftalik', 'gunler': ['sal', 'per'], 'acil': false, 'israrli': false, 'onceGun': 0});
      expect(y[3].kimlik, 'm:aa11bb');
      expect(y[4].kimlik, 'ab12cd');
      expect(y[5].govde, {'haftaIciDk': 420, 'haftaSonuDk': 120});
      expect(await ortam.esitleyici.bekleyenler(), isEmpty);
    });

    test('a refusal (409, 400) is kept on the entry with the server\'s sentence and the next entries still go', () async {
      await ortam.gun.yaptim(bugun, isler[3]);
      await ortam.gun.yaptim(bugun, isler[2]);
      ortam.api.gunYazmaHatasi = 409;

      expect(await ortam.esitleyici.gonder(), 0);

      final reddedilen = await ortam.esitleyici.reddedilenler();
      expect(reddedilen, hasLength(2));
      expect(reddedilen.first.hata, 'Sunucu bu işi kabul etmedi.');
      expect(await ortam.esitleyici.bekleyenler(), isEmpty);
    });

    test('no connection: nothing is lost, the entries wait', () async {
      await ortam.gun.yaptim(bugun, isler[2]);
      ortam.api.cevrimdisi = true;

      expect(await ortam.esitleyici.gonder(), 0);
      expect(await ortam.esitleyici.bekleyenler(), hasLength(1));
    });

    test('removing a reminder that is gone (404) and letting go of an item that is gone (404) count as done', () async {
      await ortam.gun.hatirlaticiSil(bugun, isler[1]);
      await ortam.gun.dundenBirak(bugun, const DundenKalan(maddeId: 'ab12cd', baslik: 'Market'));
      ortam.api.gunYazmaHatasi = 404;

      expect(await ortam.esitleyici.gonder(), 2);
      expect(await ortam.esitleyici.reddedilenler(), isEmpty);
    });
  });

  group('the capacity setting', () {
    test('the defaults when nothing is known; the server\'s answer is kept for offline', () async {
      ortam.api.cevrimdisi = true;
      expect((await ortam.gun.gunAyari()).haftaIciDk, 360);
      expect((await ortam.gun.gunAyari()).haftaSonuDk, 180);

      ortam.api.cevrimdisi = false;
      ortam.api.gunAyariYaniti = const GunAyari(haftaIciDk: 300, haftaSonuDk: 90);
      expect((await ortam.gun.gunAyari()).haftaIciDk, 300);

      ortam.api.cevrimdisi = true;
      expect((await ortam.gun.gunAyari()).haftaSonuDk, 90);
    });

    test('a change is shown at once, stays after the server\'s older answer and is sent', () async {
      ortam.api.gunAyariYaniti = const GunAyari(haftaIciDk: 300, haftaSonuDk: 90);

      await ortam.gun.gunAyariYaz(const GunAyari(haftaIciDk: 420, haftaSonuDk: 150));

      expect((await ortam.gun.gunAyari()).haftaIciDk, 420, reason: 'the queued value wins over the old server one');
      await ortam.esitleyici.gonder();
      expect(ortam.api.gunAyariYaniti.haftaIciDk, 420);
      expect((await ortam.gun.gunAyari()).haftaSonuDk, 150);
    });
  });

  group('load figures', () {
    test('worked out again from the open rows: over, free and rows without an estimate', () {
      const yuk = GunYuku(etkinlikDk: 60, kapasiteDk: 180);

      final asan = yuk.yenidenHesapla(acikTahminDk: 200, tahminsizSayi: 2);
      expect(asan.asimDk, 80);
      expect(asan.bosDk, 0);
      expect(asan.tahminsizSayi, 2);

      final bos = yuk.yenidenHesapla(acikTahminDk: 20, tahminsizSayi: 0);
      expect(bos.asimDk, 0);
      expect(bos.bosDk, 100);
    });

    test('the time text', () {
      expect(sureMetni(0), '0 dk');
      expect(sureMetni(45), '45 dk');
      expect(sureMetni(60), '1 sa');
      expect(sureMetni(440), '7 sa 20 dk');
    });
  });
}
