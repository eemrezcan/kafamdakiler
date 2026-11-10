import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/brifing.dart';
import 'package:kafamdakiler/data/repositories/hatirlatici_bildirim_yoneticisi.dart';
import 'package:kafamdakiler/data/services/bildirim_servisi.dart';

import '../test_destek.dart';

// The briefing on the phone (K2.7): what is kept for offline, the setting, and the notification joining the reminders' plan.

Brifing ornek({String gun = '2026-11-08', int kart = 3}) => Brifing(
      gun: gun,
      uretimAni: DateTime.utc(2026, 11, 8, 3, 30),
      yontem: 'claude',
      kartlar: [for (var i = 0; i < kart; i++) BrifingKarti(sira: i, tur: BrifingTuru.plan, baslik: 'Kart $i', metin: 'Metin $i')],
    );

void main() {
  late TestOrtami ortam;

  setUpAll(() => initializeDateFormatting('tr'));
  setUp(() => ortam = TestOrtami());
  tearDown(() async => ortam.kapat());

  group('reading', () {
    test('today\'s briefing is fetched and kept', () async {
      ortam.api.brifingYaniti = ornek();
      final okuma = await ortam.brifing.bugun();
      expect(okuma.guncel, isTrue);
      expect(okuma.brifing.kartlar, hasLength(3));
      expect((await ortam.brifing.son())!.gun, '2026-11-08');
    });

    test('offline, the last kept briefing is returned and marked as not today\'s', () async {
      ortam.api.brifingYaniti = ornek();
      await ortam.brifing.bugun();

      ortam.api.cevrimdisi = true;
      final okuma = await ortam.brifing.bugun();
      expect(okuma.guncel, isFalse);
      expect(okuma.brifing.kartlar.first.baslik, 'Kart 0');
    });

    test('before the hour (404) the last kept briefing is shown too', () async {
      ortam.api.brifingYaniti = ornek(gun: '2026-11-07');
      await ortam.brifing.bugun();

      ortam.api.brifingYaniti = null;
      final okuma = await ortam.brifing.bugun();
      expect(okuma.guncel, isFalse);
      expect(okuma.brifing.gun, '2026-11-07');
    });

    test('offline with nothing kept is an error; a refusal (403) is an error even with something kept', () async {
      ortam.api.cevrimdisi = true;
      await expectLater(ortam.brifing.bugun(), throwsA(anything));

      ortam.api.cevrimdisi = false;
      ortam.api.brifingYaniti = ornek();
      await ortam.brifing.bugun();
      ortam.api.brifingHatasi = 403;
      await expectLater(ortam.brifing.bugun(), throwsA(anything));
    });

    test('only the newest 14 briefings are kept', () async {
      for (var i = 1; i <= 16; i++) {
        ortam.api.brifingYaniti = ornek(gun: '2026-10-${(10 + i).toString().padLeft(2, '0')}');
        await ortam.brifing.bugun();
      }
      final satirlar = await ortam.db.select(ortam.db.brifingOnbellek).get();
      expect(satirlar, hasLength(14));
      expect((await ortam.brifing.son())!.gun, '2026-10-26');
    });
  });

  group('votes', () {
    test('a vote goes to the server and the kept copy shows it', () async {
      ortam.api.brifingYaniti = ornek();
      final okuma = await ortam.brifing.bugun();
      final yeni = await ortam.brifing.oyVer(okuma.brifing, 1, 1);
      expect(ortam.api.brifingOylari, [('2026-11-08', 1, 1)]);
      expect(yeni.kartlar[1].oy, 1);
      expect((await ortam.brifing.son())!.kartlar[1].oy, 1);
    });
  });

  group('the setting', () {
    test('it starts as 06:30 on, and a written hour or "off" is read back', () async {
      expect((await ortam.brifing.ayar()).saatMetni, '06:30');
      await ortam.brifing.ayarYaz(const BrifingAyari(saat: 7, dakika: 15));
      expect((await ortam.brifing.ayar()).saatMetni, '07:15');
      await ortam.brifing.ayarYaz(const BrifingAyari(acik: false));
      expect((await ortam.brifing.ayar()).acik, isFalse);
    });
  });

  test('signing out clears the kept briefings and the setting', () async {
    ortam.api.brifingYaniti = ornek();
    await ortam.brifing.bugun();
    await ortam.brifing.ayarYaz(const BrifingAyari(saat: 7, dakika: 0));
    await ortam.db.hepsiniTemizle();
    expect(await ortam.brifing.son(), isNull);
    expect((await ortam.brifing.ayar()).saatMetni, '06:30');
  });

  group('the notification plan', () {
    late SahteBildirimServisi servis;
    var okuyabilir = true;

    HatirlaticiBildirimYoneticisi yoneticiOlustur({bool brifingli = true}) => HatirlaticiBildirimYoneticisi(
          repo: ortam.hatirlaticilar,
          esitleyici: ortam.esitleyici,
          servis: servis,
          yazabilir: () => true,
          brifing: brifingli ? ortam.brifing : null,
          brifingOkuyabilir: () => okuyabilir,
          // 2026-11-08 05:00 Istanbul.
          simdi: () => DateTime.utc(2026, 11, 8, 2),
        );

    setUp(() {
      servis = SahteBildirimServisi();
      okuyabilir = true;
    });

    test('the briefing joins the reminders in one plan, in time order', () async {
      ortam.api.hatirlaticilar = [ornekHatirlatici(id: 'a', baslik: 'Bir', sonrakiAn: DateTime.utc(2026, 11, 9, 6))];
      final yonetici = yoneticiOlustur();
      await yonetici.esitleVeKur();
      expect(servis.son.map((b) => b.baslik), ['Sabah brifingi', 'Bir']);
      expect(servis.son.first.an, DateTime.utc(2026, 11, 8, 3, 30));
    });

    test('changing the hour and planning again moves it; turning it off takes it out', () async {
      final yonetici = yoneticiOlustur();
      await yonetici.kur();
      expect(servis.son.single.an, DateTime.utc(2026, 11, 8, 3, 30));

      await ortam.brifing.ayarYaz(const BrifingAyari(saat: 8, dakika: 0));
      await yonetici.kur();
      expect(servis.son.single.an, DateTime.utc(2026, 11, 8, 5));

      await ortam.brifing.ayarYaz(const BrifingAyari(acik: false));
      await yonetici.kur();
      expect(servis.son, isEmpty);
    });

    test('a user who may not read the briefing, or no briefing wired in, gets none', () async {
      okuyabilir = false;
      final yonetici = yoneticiOlustur();
      await yonetici.kur();
      expect(servis.son, isEmpty);

      final yalin = yoneticiOlustur(brifingli: false);
      okuyabilir = true;
      await yalin.kur();
      expect(servis.son, isEmpty);
    });

    test('a tap on the notification opens the briefing, not the reminders list', () async {
      final yonetici = yoneticiOlustur();
      var brifingAcildi = 0;
      var listeAcildi = 0;
      await yonetici.baslat(listeyiAc: () => listeAcildi++, brifingiAc: () => brifingAcildi++);
      servis.yanitla!(const BildirimYaniti(brifing: true));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(brifingAcildi, 1);
      expect(listeAcildi, 0);
      yonetici.durdur();
    });
  });
}
