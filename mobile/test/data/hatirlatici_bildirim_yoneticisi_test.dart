import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/hatirlatici.dart';
import 'package:kafamdakiler/data/repositories/hatirlatici_bildirim_yoneticisi.dart';
import 'package:kafamdakiler/data/services/bildirim_servisi.dart';
import 'package:kafamdakiler/utils/bildirim_plani.dart';

import '../test_destek.dart';

// The glue between the reminders and the notification scheduler: when the plan is set up again, and what the
// notification buttons do.

void main() {
  late TestOrtami ortam;
  late SahteBildirimServisi servis;
  late HatirlaticiBildirimYoneticisi yonetici;
  var sahip = true;

  setUpAll(() => initializeDateFormatting('tr'));

  setUp(() {
    ortam = TestOrtami();
    servis = SahteBildirimServisi();
    sahip = true;
    yonetici = HatirlaticiBildirimYoneticisi(
      repo: ortam.hatirlaticilar,
      esitleyici: ortam.esitleyici,
      servis: servis,
      yazabilir: () => sahip,
      simdi: () => DateTime.utc(2026, 10, 31, 9),
    );
  });
  tearDown(() async {
    yonetici.durdur();
    await ortam.kapat();
  });

  test('after a sync the cache is refreshed and the plan is set up from the new data', () async {
    ortam.api.hatirlaticilar = [ornekHatirlatici(id: 'a', baslik: 'Bir', sonrakiAn: DateTime.utc(2026, 11, 2, 6))];
    await yonetici.esitleVeKur();

    expect(servis.son.map((b) => b.baslik), ['Bir']);

    ortam.api.hatirlaticilar = [
      ornekHatirlatici(id: 'a', baslik: 'Bir', sonrakiAn: DateTime.utc(2026, 11, 2, 6)),
      ornekHatirlatici(id: 'b', baslik: 'İki', sonrakiAn: DateTime.utc(2026, 11, 3, 6)),
    ];
    await yonetici.esitleVeKur();
    expect(servis.son.map((b) => b.baslik), ['Bir', 'İki'], reason: 'the whole plan is replaced, not added to');
  });

  test('offline, the plan is built from the phone copy', () async {
    ortam.api.hatirlaticilar = [ornekHatirlatici(id: 'a')];
    await yonetici.esitleVeKur();

    ortam.api.cevrimdisi = true;
    await yonetici.esitleVeKur();
    expect(servis.son, hasLength(1));
  });

  test('a local write plans again at once, without the network', () async {
    ortam.api.cevrimdisi = true;
    await yonetici.baslat(listeyiAc: () {});
    expect(servis.baslatildi, isTrue);

    await ortam.hatirlaticilar.ekle(HatirlaticiYaz(baslik: 'Yeni', gun: DateTime.utc(2026, 11, 20)));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(servis.son.map((b) => b.baslik), ['Yeni']);
  });

  test('a reminder marked done is dropped from the plan', () async {
    ortam.api.hatirlaticilar = [ornekHatirlatici(id: 'a')];
    await yonetici.esitleVeKur();
    expect(servis.son, hasLength(1));

    ortam.api.cevrimdisi = true;
    await ortam.hatirlaticilar.yaptim('a');
    await yonetici.kur();
    expect(servis.son, isEmpty);
  });

  test('signing out cancels everything', () async {
    ortam.api.hatirlaticilar = [ornekHatirlatici(id: 'a')];
    await yonetici.esitleVeKur();
    await yonetici.temizle();
    expect(servis.son, isEmpty);
  });

  group('notification buttons', () {
    setUp(() async {
      ortam.api.hatirlaticilar = [ornekHatirlatici(id: 'a')];
      await ortam.hatirlaticilar.listele();
      ortam.api.cevrimdisi = true;
    });

    test('Yaptım writes to the queue, and a tap on the notification opens the list', () async {
      expect(await yonetici.yanitla(const BildirimYaniti(eylem: BildirimEylemi.yaptim, hatirlaticiId: 'a')), isFalse);
      expect((await ortam.esitleyici.bekleyenler()).single.hedefId, 'a');
      expect((await ortam.hatirlaticilar.yerelListe()).single.durum, HatirlaticiDurumu.tamam);

      expect(await yonetici.yanitla(const BildirimYaniti(hatirlaticiId: 'a')), isTrue);
      expect(await ortam.esitleyici.bekleyenler(), hasLength(1), reason: 'a tap writes nothing');
    });

    test('the two snooze buttons queue their durations', () async {
      await yonetici.yanitla(const BildirimYaniti(eylem: BildirimEylemi.birSaatErtele, hatirlaticiId: 'a'));
      await yonetici.yanitla(const BildirimYaniti(eylem: BildirimEylemi.yarinErtele, hatirlaticiId: 'a'));

      final govdeler = (await ortam.esitleyici.bekleyenler()).map((b) => b.govde).toList();
      expect(govdeler, ['{"sure":"1s"}', '{"sure":"yarin"}']);
    });

    test('Yaptım and the snoozes take the nags already in the tray down; a tap does not', () async {
      final nagler = [for (var n = 1; n <= enCokIsrarSayisi; n++) bildirimKimligi('a', israrNo: n)];

      await yonetici.yanitla(const BildirimYaniti(hatirlaticiId: 'a'));
      expect(servis.kapatilanlar, isEmpty);

      await yonetici.yanitla(const BildirimYaniti(eylem: BildirimEylemi.yaptim, hatirlaticiId: 'a'));
      expect(servis.kapatilanlar, nagler);

      servis.kapatilanlar.clear();
      await yonetici.yanitla(const BildirimYaniti(eylem: BildirimEylemi.birSaatErtele, hatirlaticiId: 'a'));
      expect(servis.kapatilanlar, nagler);
    });

    test('Yaptım drops the pending nags from the plan, a snooze moves them', () async {
      // "Now" is 2026-10-31 09:00Z; the moment is 10 minutes ahead.
      final an = DateTime.utc(2026, 10, 31, 9, 10);
      ortam.api.cevrimdisi = false;
      ortam.api.hatirlaticilar = [ornekHatirlatici(id: 'n', israrli: true, israrEnCok: 2, sonrakiAn: an)];
      await ortam.hatirlaticilar.listele();
      ortam.api.cevrimdisi = true;
      await yonetici.kur();
      expect(servis.son.map((b) => b.israrNo), [0, 1, 2]);
      expect(servis.son.first.an, an);

      await yonetici.yanitla(const BildirimYaniti(eylem: BildirimEylemi.birSaatErtele, hatirlaticiId: 'n'));
      await yonetici.kur();
      expect(servis.son.map((b) => b.israrNo), [0, 1, 2]);
      expect(servis.son.every((b) => b.an.isAfter(an)), isTrue, reason: 'the whole series moved after the snooze');

      await yonetici.yanitla(const BildirimYaniti(eylem: BildirimEylemi.yaptim, hatirlaticiId: 'n'));
      await yonetici.kur();
      expect(servis.son, isEmpty);
    });

    test('a user who cannot write only opens the list', () async {
      sahip = false;
      expect(await yonetici.yanitla(const BildirimYaniti(eylem: BildirimEylemi.yaptim, hatirlaticiId: 'a')), isTrue);
      expect(await ortam.esitleyici.bekleyenler(), isEmpty);
    });
  });

  test('the notification that opened the app is answered at start', () async {
    ortam.api.hatirlaticilar = [ornekHatirlatici(id: 'a')];
    await ortam.hatirlaticilar.listele();
    ortam.api.cevrimdisi = true;
    servis.acilis = const BildirimYaniti(eylem: BildirimEylemi.yaptim, hatirlaticiId: 'a');

    await yonetici.baslat(listeyiAc: () {});

    expect(await ortam.esitleyici.bekleyenler(), hasLength(1));
  });

  test('the first reminder asks for the notification permission', () async {
    await yonetici.izinIste();
    expect(servis.izinIstekleri, 1);
  });
}
