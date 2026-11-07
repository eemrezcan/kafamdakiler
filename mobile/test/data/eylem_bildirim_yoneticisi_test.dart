import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/eylem.dart';
import 'package:kafamdakiler/data/repositories/eylem_bildirim_yoneticisi.dart';
import 'package:kafamdakiler/data/repositories/hatirlatici_bildirim_yoneticisi.dart';
import 'package:kafamdakiler/data/services/bildirim_servisi.dart';
import 'package:kafamdakiler/utils/bildirim_plani.dart';

import '../test_destek.dart';

// New waiting actions are announced with a local notification (Onayla / Reddet buttons); a button writes the decision to
// the offline queue. The suggestions that need a look first never get the Onayla button.

void main() {
  late TestOrtami ortam;
  late SahteBildirimServisi servis;
  late EylemBildirimYoneticisi yonetici;
  var sahip = true;

  setUpAll(() => initializeDateFormatting('tr'));

  setUp(() {
    ortam = TestOrtami();
    servis = SahteBildirimServisi();
    sahip = true;
    yonetici = EylemBildirimYoneticisi(
      repo: ortam.eylemler,
      esitleyici: ortam.esitleyici,
      servis: servis,
      yazabilir: () => sahip,
    );
    ortam.api.eylemler = [ornekEylem(id: 'a', ozet: 'Ali\'yi ara')];
  });
  tearDown(() async {
    // A button also starts a send in the background; let it end before the database is closed.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await ortam.kapat();
  });

  group('announcing', () {
    test('a new waiting action gets one notification with the two buttons, and not a second one at the next sync', () async {
      await yonetici.esitleVeBildir();

      expect(servis.eylemBildirimleri, hasLength(1));
      final b = servis.eylemBildirimleri.single;
      expect(b.baslik, 'Ali\'yi ara');
      expect(b.govde, 'Hatırlatıcı kur · onayını bekliyor');
      expect(b.eylemId, 'a');
      expect(b.eylemler, isTrue);

      await yonetici.esitleVeBildir();
      expect(servis.eylemBildirimleri, hasLength(1), reason: 'announced already');

      ortam.api.eylemler = [...ortam.api.eylemler, ornekEylem(id: 'b', ozet: 'Faturayı öde')];
      await yonetici.esitleVeBildir();
      expect(servis.eylemBildirimleri.map((x) => x.eylemId), ['a', 'b'], reason: 'only the new one was added');
    });

    test('the notification id is stable per action, so it can be taken down', () async {
      await yonetici.esitleVeBildir();

      expect(servis.eylemBildirimleri.single.id, eylemBildirimKimligi('a'));
    });

    test('nothing waiting, nothing announced; decided ones are not announced', () async {
      ortam.api.eylemler = [
        ornekEylem(id: 'u', durum: EylemDurumu.uygulandi),
        ornekEylem(id: 'r', durum: EylemDurumu.reddedildi),
      ];

      await yonetici.esitleVeBildir();

      expect(servis.eylemBildirimleri, isEmpty);
    });

    test('an action from outside text, or one the source is unsure of, gets no Onayla button', () async {
      ortam.api.eylemler = [
        ornekEylem(id: 'd', ozet: 'Mailden gelen', disKaynak: true),
        ornekEylem(id: 'e', ozet: 'Belki', guven: 0.3),
        ornekEylem(id: 'k', ozet: 'Emin', guven: 0.95),
      ];

      await yonetici.esitleVeBildir();

      final harita = {for (final b in servis.eylemBildirimleri) b.eylemId!: b};
      expect(harita['d']!.eylemler, isFalse);
      expect(harita['d']!.govde, contains('dış kaynak'));
      expect(harita['e']!.eylemler, isFalse);
      expect(harita['e']!.govde, contains('emin değil'));
      expect(harita['k']!.eylemler, isTrue);
    });

    test('more than three new ones are announced by one summary without buttons', () async {
      ortam.api.eylemler = [for (var i = 0; i < 5; i++) ornekEylem(id: 'e$i', ozet: 'İş $i')];

      await yonetici.esitleVeBildir();

      final b = servis.eylemBildirimleri.single;
      expect(b.baslik, '5 eylem onay bekliyor');
      expect(b.eylemId, isNull);
      expect(b.eylemler, isFalse);
      expect(b.id, eylemOzetBildirimKimligi);

      await yonetici.esitleVeBildir();
      expect(servis.eylemBildirimleri, hasLength(1), reason: 'all five are marked as announced');
    });

    test('a user who cannot decide is told, but gets no buttons', () async {
      sahip = false;

      await yonetici.esitleVeBildir();

      expect(servis.eylemBildirimleri.single.eylemler, isFalse);
    });

    test('offline, the phone copy is used; with nothing cached nothing is announced', () async {
      ortam.api.cevrimdisi = true;
      await yonetici.esitleVeBildir();
      expect(servis.eylemBildirimleri, isEmpty);

      ortam.api.cevrimdisi = false;
      await ortam.eylemler.listele(); // the cache is filled while the connection is there
      ortam.api.cevrimdisi = true;
      await yonetici.esitleVeBildir();
      expect(servis.eylemBildirimleri, hasLength(1));
    });

    test('a refusal from the server (no permission) announces nothing and does not throw', () async {
      ortam.api.sunucuHatasi = 403;

      await yonetici.esitleVeBildir();

      expect(servis.eylemBildirimleri, isEmpty);
    });
  });

  group('notification buttons', () {
    setUp(() async {
      await ortam.eylemler.listele();
      ortam.api.cevrimdisi = true;
    });

    test('Onayla writes the approval to the queue, shows it at once and takes the notification down', () async {
      final acilsin = await yonetici.yanitla(const BildirimYaniti(eylem: BildirimEylemi.eylemOnayla, eylemId: 'a'));

      expect(acilsin, isFalse);
      final kuyruk = await ortam.esitleyici.bekleyenler();
      expect(kuyruk.single.hedefId, 'a');
      expect((await ortam.eylemler.getir('a'))!.durum, EylemDurumu.uygulandi);
      expect(servis.kapatilanlar, [eylemBildirimKimligi('a')]);
    });

    test('Reddet writes the rejection (a plain one: the kind is not forbidden)', () async {
      await yonetici.yanitla(const BildirimYaniti(eylem: BildirimEylemi.eylemReddet, eylemId: 'a'));

      expect((await ortam.esitleyici.bekleyenler()).single.govde, '{"birDahaOnerme":false}');
      expect((await ortam.eylemler.getir('a'))!.durum, EylemDurumu.reddedildi);
    });

    test('the decision goes to the server when the connection is back', () async {
      await yonetici.yanitla(const BildirimYaniti(eylem: BildirimEylemi.eylemOnayla, eylemId: 'a'));
      // The button also starts a send in the background; offline it fails and keeps the entry. Let it finish.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      ortam.api.cevrimdisi = false;
      ortam.api.cagrilar.clear();
      await ortam.esitleyici.gonder();

      expect(ortam.api.cagrilar, ['eylemUygula:a']);
    });

    test('a tap opens the queue and writes nothing; so does the summary and a user who cannot decide', () async {
      expect(await yonetici.yanitla(const BildirimYaniti(eylemId: 'a')), isTrue);
      expect(await yonetici.yanitla(const BildirimYaniti(eylem: BildirimEylemi.eylemOnayla, eylemId: '')), isTrue);
      sahip = false;
      expect(await yonetici.yanitla(const BildirimYaniti(eylem: BildirimEylemi.eylemOnayla, eylemId: 'a')), isTrue);

      expect(await ortam.esitleyici.bekleyenler(), isEmpty);
      expect(servis.kapatilanlar, isEmpty);
    });
  });

  group('sharing the plugin with the reminders', () {
    late HatirlaticiBildirimYoneticisi hatirlatici;

    setUp(() {
      hatirlatici = HatirlaticiBildirimYoneticisi(
        repo: ortam.hatirlaticilar,
        esitleyici: ortam.esitleyici,
        servis: servis,
        yazabilir: () => sahip,
        eylemler: yonetici,
      );
    });
    tearDown(() => hatirlatici.durdur());

    test('a response of an approval queue notification goes to the queue, not to the reminders list', () async {
      await ortam.eylemler.listele();
      ortam.api.cevrimdisi = true;
      var hatirlaticiListesi = 0;
      var kuyruk = 0;
      await hatirlatici.baslat(listeyiAc: () => hatirlaticiListesi++, kuyruguAc: () => kuyruk++);

      servis.yanitla!(const BildirimYaniti(eylemId: 'a'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect((kuyruk, hatirlaticiListesi), (1, 0), reason: 'a tap opens the approval queue');

      servis.yanitla!(const BildirimYaniti(eylem: BildirimEylemi.eylemOnayla, eylemId: 'a'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect((kuyruk, hatirlaticiListesi), (1, 0), reason: 'a button decides, it does not open anything');
      expect((await ortam.esitleyici.bekleyenler()).single.hedefId, 'a');
    });

    test('a reminder notification still opens the reminders list', () async {
      var hatirlaticiListesi = 0;
      var kuyruk = 0;
      await hatirlatici.baslat(listeyiAc: () => hatirlaticiListesi++, kuyruguAc: () => kuyruk++);

      servis.yanitla!(const BildirimYaniti(hatirlaticiId: 'h1'));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect((kuyruk, hatirlaticiListesi), (0, 1));
    });
  });

  group('the plan itself', () {
    test('the payload prefix is told apart from a reminder id', () {
      expect(eylemBildirimOneki, 'eylem:');
      expect(eylemBildirimKimligi('a'), isNot(bildirimKimligi('a')));
      expect(eylemBildirimKimligi('a'), eylemBildirimKimligi('a'));
    });

    test('nothing new, nothing planned', () {
      expect(eylemBildirimleriPlanla(const []), isEmpty);
    });
  });
}
