import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/bildirim_ogesi.dart';
import 'package:kafamdakiler/data/repositories/bildirim_repository.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';

import '../test_destek.dart';

/// The notification centre's data side (K-0024, sözleşme §6): the list kept for offline, the read marks laid on it, the number
/// on the bell and what the sender does with the marks.
void main() {
  late TestOrtami ortam;

  setUp(() => ortam = TestOrtami());
  tearDown(() async => ortam.kapat());

  BildirimOgesi bildirim(String id, {DateTime? zaman, bool okundu = false, String baslik = 'Başlık', String? kaynak}) => BildirimOgesi(
        id: id,
        baslik: baslik,
        metin: 'Metin $id',
        zaman: zaman ?? DateTime.utc(2026, 11, 10, 8),
        okundu: okundu,
        kaynakTuru: kaynak,
      );

  group('reading', () {
    test('the newest page is kept; offline the kept page comes back and says so', () async {
      ortam.api.bildirimler = [bildirim('a'), bildirim('b', okundu: true)];

      final canli = await ortam.bildirimMerkezi.ilkSayfa();
      expect(canli.cevrimdisi, isFalse);
      expect(canli.liste.map((b) => b.id), ['a', 'b']);

      ortam.api.cevrimdisi = true;
      final yedek = await ortam.bildirimMerkezi.ilkSayfa();
      expect(yedek.cevrimdisi, isTrue);
      expect(yedek.liste.map((b) => (b.id, b.okundu)), [('a', false), ('b', true)]);
    });

    test('offline with nothing kept: the error; a server error is thrown even with a kept page', () async {
      ortam.api.cevrimdisi = true;
      await expectLater(ortam.bildirimMerkezi.ilkSayfa(), throwsA(isA<DioException>()));

      ortam.api.cevrimdisi = false;
      ortam.api.bildirimler = [bildirim('a')];
      await ortam.bildirimMerkezi.ilkSayfa();
      ortam.api.sunucuHatasi = 503;
      await expectLater(ortam.bildirimMerkezi.ilkSayfa(), throwsA(isA<DioException>()));
    });

    test('an older page is asked for with the time of the oldest row', () async {
      ortam.api.bildirimler = [
        for (var i = 0; i < 35; i++) bildirim('n$i', zaman: DateTime.utc(2026, 11, 10, 8).subtract(Duration(hours: i))),
      ];

      final ilk = await ortam.bildirimMerkezi.ilkSayfa();
      expect(ilk.liste, hasLength(BildirimRepository.sayfaBoyu));

      final sayfa = await ortam.bildirimMerkezi.dahaEski(ilk.liste.last.zaman!);
      expect(sayfa.map((b) => b.id), ['n30', 'n31', 'n32', 'n33', 'n34']);
      expect(ortam.api.bildirimIstekleri, [null, ilk.liste.last.zaman]);
    });

    test('a row parses with the server\'s "olusmaAni"; a row of the older cache without it has no time', () {
      final a = BildirimOgesi.fromJson({'id': 'a', 'baslik': 'x', 'metin': 'y', 'olusmaAni': '2026-11-10T08:00:00+03:00', 'okundu': true, 'anahtar': 'k'});
      expect(a.zaman, DateTime.utc(2026, 11, 10, 5));
      expect(a.okundu, isTrue);
      final b = BildirimOgesi.fromJson({'id': 'b', 'baslik': 'x', 'metin': 'y', 'olusmaAni': '2026-11-10T05:00:00Z', 'kaynakTuru': 'hatirlatici', 'hedefKimligi': 'h1'});
      expect(b.zaman, DateTime.utc(2026, 11, 10, 5));
      expect(b.hatirlaticiMi, isTrue);
      final c = BildirimOgesi.fromJson({'id': 'c', 'baslik': 'x', 'metin': 'y'});
      expect(c.zaman, isNull);
      expect(c.okundu, isFalse);
      // The kept page is read back with the same name.
      expect(BildirimOgesi.fromJson(a.toJson()).zaman, a.zaman);
    });
  });

  group('read marks', () {
    test('a queued mark is laid on the list at once, offline too; the others stay unread', () async {
      ortam.api.bildirimler = [bildirim('a'), bildirim('b')];
      await ortam.bildirimMerkezi.ilkSayfa();
      ortam.api.cevrimdisi = true;

      await ortam.bildirimMerkezi.okundu('a');

      final liste = (await ortam.bildirimMerkezi.ilkSayfa()).liste;
      expect(liste.map((b) => (b.id, b.okundu)), [('a', true), ('b', false)]);
      final kuyruk = await ortam.esitleyici.bekleyenler();
      expect(kuyruk.single.tur, BekleyenTur.bildirimOkundu);
      expect(kuyruk.single.hedefId, 'a');
    });

    test('"all read" marks every row', () async {
      ortam.api.bildirimler = [bildirim('a'), bildirim('b')];
      await ortam.bildirimMerkezi.ilkSayfa();
      ortam.api.cevrimdisi = true;

      await ortam.bildirimMerkezi.hepsiOkundu();

      expect((await ortam.bildirimMerkezi.ilkSayfa()).liste.every((b) => b.okundu), isTrue);
      expect((await ortam.esitleyici.bekleyenler()).single.tur, BekleyenTur.bildirimHepsiOkundu);
    });

    test('the marks are sent to their routes; a mark of a notification that is gone (404) counts as done', () async {
      await ortam.bildirimMerkezi.okundu('a');
      await ortam.bildirimMerkezi.hepsiOkundu();

      expect(await ortam.esitleyici.gonder(), 2);
      expect(ortam.api.okunduIstekleri, ['a', 'hepsi']);

      await ortam.bildirimMerkezi.okundu('silinmis');
      ortam.api.gunYazmaHatasi = 404;
      expect(await ortam.esitleyici.gonder(), 1);
      expect(await ortam.esitleyici.reddedilenler(), isEmpty);
    });

    test('a mark that cannot be sent waits for the connection', () async {
      await ortam.bildirimMerkezi.okundu('a');
      ortam.api.cevrimdisi = true;

      expect(await ortam.esitleyici.gonder(), 0);
      expect(await ortam.esitleyici.bekleyenler(), hasLength(1));
    });
  });

  group('the number on the bell', () {
    test('the server\'s number, less the marks that wait; "all read" is zero; never below zero', () async {
      ortam.api.okunmamisBildirim = 3;
      expect(await ortam.bildirimMerkezi.okunmamisSayi(), 3);

      await ortam.bildirimMerkezi.okundu('a');
      expect(await ortam.bildirimMerkezi.okunmamisSayi(), 2);

      await ortam.bildirimMerkezi.okundu('b');
      await ortam.bildirimMerkezi.okundu('c');
      await ortam.bildirimMerkezi.okundu('d');
      expect(await ortam.bildirimMerkezi.okunmamisSayi(), 0);

      ortam.api.okunmamisBildirim = 7;
      await ortam.bildirimMerkezi.hepsiOkundu();
      expect(await ortam.bildirimMerkezi.okunmamisSayi(), 0);
    });
  });
}
