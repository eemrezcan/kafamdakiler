import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/asistan.dart';
import 'package:kafamdakiler/data/models/brifing.dart';
import 'package:kafamdakiler/data/models/eylem.dart';
import 'package:kafamdakiler/data/models/is_karti.dart';
import 'package:kafamdakiler/data/models/yakalama.dart';
import 'package:kafamdakiler/data/repositories/asistan_repository.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';

import '../test_destek.dart';

/// The assistant feed's data side (K-0024, sözleşme §7): the page kept for offline, the queue laid on it, the one input and what
/// the sender does with each write.
void main() {
  late TestOrtami ortam;

  setUp(() => ortam = TestOrtami());
  tearDown(() async => ortam.kapat());

  final saat8 = DateTime.utc(2026, 10, 31, 8);

  final yakalama = Yakalama(
    id: 'y1',
    metin: 'Flutter state yönetimi',
    hedef: 'projects/kafamdakiler',
    durum: YakalamaDurumu.bekliyor,
    yakalandiAt: saat8,
    olusturulma: saat8,
  );

  List<AkisOgesi> sunucuAkisi() => [
        ornekAkis('s6', AkisTuru.not, zaman: saat8.subtract(const Duration(minutes: 5)), yakalama: yakalama),
        ornekAkis('s5', AkisTuru.isKarti, zaman: saat8.subtract(const Duration(minutes: 10)), isKarti: const IsKarti(kimlik: 'takvim', baslik: 'Takvim', tip: 'kod', asama: 'karar', sahip: 'kullanici', bekleyenSoru: 1)),
        ornekAkis('s4', AkisTuru.onay, zaman: saat8.subtract(const Duration(minutes: 20)), eylem: ornekEylem(id: 'e9', ozet: 'Cuma 15:00 toplantı')),
        ornekAkis('s3', AkisTuru.soru, zaman: saat8.subtract(const Duration(minutes: 30)), soru: const AsistanSorusu(id: 'q1', metin: 'Yarına kalsın mı?', secenekler: ['Yarına al', 'Bugün yaparım'])),
        ornekAkis('s2', AkisTuru.sonuc, zaman: saat8.subtract(const Duration(minutes: 40)), sonuclar: [ornekSonuc()]),
        ornekAkis('s1', AkisTuru.kullanici, zaman: saat8.subtract(const Duration(minutes: 41)), metin: 'yarın e-kampüse bak'),
      ];

  Future<List<AkisOgesi>> liste([String suzgec = AkisSuzgeci.hepsi]) async => (await ortam.asistan.ilkSayfa(suzgec: suzgec)).liste;

  group('reading', () {
    test('the newest page is kept; offline the kept page comes back, filtered on the phone', () async {
      ortam.api.akisOgeleri = sunucuAkisi();

      final canli = await ortam.asistan.ilkSayfa();
      expect(canli.cevrimdisi, isFalse);
      expect(canli.liste.map((o) => o.id), ['s6', 's5', 's4', 's3', 's2', 's1']);

      ortam.api.cevrimdisi = true;
      expect((await ortam.asistan.ilkSayfa()).cevrimdisi, isTrue);
      expect((await liste(AkisSuzgeci.bekleyen)).map((o) => o.id), ['s5', 's4', 's3'], reason: 'a work card with a question, an approval, a question');
      expect((await liste(AkisSuzgeci.isler)).map((o) => o.id), ['s5']);
      expect((await liste(AkisSuzgeci.notlar)).map((o) => o.id), ['s6']);
    });

    test('the filter goes to the server as it is; only the unfiltered page is kept', () async {
      ortam.api.akisOgeleri = sunucuAkisi();

      await liste(AkisSuzgeci.isler);
      expect(ortam.api.akisIstekleri, ['isler|']);

      ortam.api.cevrimdisi = true;
      await expectLater(ortam.asistan.ilkSayfa(), throwsA(isA<DioException>()), reason: 'a filtered read kept nothing');
    });

    test('offline with nothing kept: the error; a server error is thrown even with a kept page', () async {
      ortam.api.cevrimdisi = true;
      await expectLater(liste(), throwsA(isA<DioException>()));

      ortam.api.cevrimdisi = false;
      ortam.api.akisOgeleri = sunucuAkisi();
      await liste();
      ortam.api.sunucuHatasi = 403;
      await expectLater(liste(), throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 403)));
    });

    test('an older page is asked for with the time of the oldest item, and carries none of the phone\'s own messages', () async {
      ortam.api.akisOgeleri = [
        for (var i = 0; i < 45; i++) ornekAkis('s$i', AkisTuru.kullanici, zaman: saat8.subtract(Duration(minutes: i)), metin: 'm$i'),
      ];
      ortam.api.cevrimdisi = false;
      final ilk = await liste();
      expect(ilk, hasLength(AsistanRepository.sayfaBoyu));
      ortam.api.cevrimdisi = true;
      await ortam.asistan.girdiGonder(metin: 'yerel');
      ortam.api.cevrimdisi = false;

      final sayfa = await ortam.asistan.dahaEski(ilk.last.zaman);

      expect(sayfa.map((o) => o.id), ['s40', 's41', 's42', 's43', 's44']);
      expect(ortam.api.akisIstekleri.last, startsWith('hepsi|'));
    });

    test('every kind of item parses, and comes back through JSON as the cache does it', () {
      final json = [
        {'id': 'a', 'zaman': '2026-10-31T08:00:00+03:00', 'tur': 'kullanici', 'metin': 'merhaba', 'fotografUrl': '/api/dosyalar/f1'},
        {
          'id': 'b',
          'zaman': '2026-10-31T08:01:00Z',
          'tur': 'sonuc',
          'sonuclar': [
            {'tur': 'not', 'baslik': 'Not', 'ozet': 'Kafamdakiler', 'durum': 'uygulandi', 'eylemId': null, 'hedef': {'kimlik': 'y1', 'rota': null}, 'geriAlinabilir': true},
            {'tur': 'plan-ekle', 'baslik': 'Plan', 'durum': 'izinYok', 'geriAlinabilir': false, 'mesaj': 'İzin yok'},
          ],
        },
        {'id': 'c', 'zaman': '2026-10-31T08:02:00Z', 'tur': 'soru', 'soru': {'id': 'q', 'metin': 'Hangisi?', 'secenekler': ['A', 'B']}},
        {'id': 'd', 'zaman': '2026-10-31T08:03:00Z', 'tur': 'is', 'is': {'kimlik': 'x', 'baslik': 'İş', 'asama': 'plan', 'sahip': 'vps'}},
        {'id': 'e', 'zaman': '2026-10-31T08:04:00Z', 'tur': 'bilinmeyen-tur'},
      ];

      final liste = [for (final j in json) AkisOgesi.fromJson(j)];
      expect(liste[0].fotografUrl, '/api/dosyalar/f1');
      expect(liste[0].zaman, DateTime.utc(2026, 10, 31, 5));
      expect(liste[1].sonuclar.first.hedefKimlik, 'y1');
      expect(liste[1].sonuclar.first.geriAlinabilir, isTrue);
      expect(liste[1].sonuclar.last.durum, SonucDurumu.izinYok);
      expect(liste[2].soru!.secenekler, ['A', 'B']);
      expect(liste[3].isKarti!.sahip, 'vps');
      expect(liste[4].tur, 'bilinmeyen-tur', reason: 'a kind this version does not know is kept as it came');

      final yeniden = [for (final o in liste) AkisOgesi.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, dynamic>)];
      expect(yeniden[1].sonuclar.first.hedefKimlik, 'y1');
      expect(yeniden[2].soru!.id, 'q');
    });

    test('a briefing item carries the day\'s cards with the votes', () {
      final o = AkisOgesi.fromJson({
        'id': 'br',
        'zaman': '2026-10-31T04:30:00Z',
        'tur': 'brifing',
        'metin': 'Günaydın.',
        'brifing': {
          'gun': '2026-10-31',
          'uretimAni': '2026-10-31T04:30:00Z',
          'yontem': 'claude',
          'kartlar': [
            {'sira': 0, 'tur': 'plan', 'baslik': 'Plan', 'metin': '7 iş', 'oy': 1},
          ],
        },
      });
      expect(o.brifing!.kartlar.single.oy, 1);
      expect(o.brifing!.yontem, Brifing.claudeYontemi);
    });
  });

  group('the input', () {
    test('an input shows at once as the person\'s own message marked "gönderilecek", newest first, in "Hepsi" and "Bekleyen" only', () async {
      ortam.api.akisOgeleri = sunucuAkisi();
      await liste();
      ortam.api.cevrimdisi = true;

      await ortam.asistan.girdiGonder(metin: '  cuma 10\'da diş randevusu, bir gün önce hatırlat ', kaynak: AsistanKaynagi.ses);

      final hepsi = await liste();
      expect(hepsi.first.id, startsWith('yerel:'));
      expect(hepsi.first.tur, AkisTuru.kullanici);
      expect(hepsi.first.metin, 'cuma 10\'da diş randevusu, bir gün önce hatırlat', reason: 'trimmed');
      expect(hepsi.first.bekliyor, isTrue);
      expect(hepsi.length, 7);
      expect((await liste(AkisSuzgeci.bekleyen)).first.id, startsWith('yerel:'));
      expect((await liste(AkisSuzgeci.isler)).any((o) => o.id.startsWith('yerel:')), isFalse);
      expect((await liste(AkisSuzgeci.notlar)).any((o) => o.id.startsWith('yerel:')), isFalse);
    });

    test('the body: the input id is the queue id, the day is the phone\'s, the source is kept; an empty text is none', () async {
      await ortam.asistan.girdiGonder(metin: '   ', fotografKaynagi: null);
      await ortam.asistan.girdiGonder(metin: 'merhaba', kaynak: AsistanKaynagi.paylas);

      final kuyruk = await ortam.esitleyici.bekleyenler();
      expect(kuyruk, hasLength(2));
      final ikinci = jsonDecode(kuyruk[1].govde)['girdi'] as Map<String, dynamic>;
      expect(ikinci['id'], kuyruk[1].id);
      expect(kuyruk[1].hedefId, kuyruk[1].id);
      expect(ikinci['metin'], 'merhaba');
      expect(ikinci['kaynak'], 'paylas');
      expect(ikinci['bugun'], '2026-10-31');
      expect((jsonDecode(kuyruk[0].govde)['girdi'] as Map).containsKey('metin'), isFalse);
    });

    test('sending: the input goes to the server with its id; the phone\'s own copy leaves the feed', () async {
      ortam.api.akisOgeleri = sunucuAkisi();
      await ortam.asistan.girdiGonder(metin: 'merhaba');
      final kuyruk = await ortam.esitleyici.bekleyenler();

      expect(await ortam.esitleyici.gonder(), 1);

      final g = ortam.api.asistanGirdileri.single;
      expect(g.id, kuyruk.single.id);
      expect(g.metin, 'merhaba');
      expect((await liste()).any((o) => o.id.startsWith('yerel:')), isFalse);
    });

    test('a photo: a copy is kept in the app\'s folder, shown with the message, uploaded first and its id goes into the input', () async {
      final kaynak = File('${ortam.fotografKlasoru.path}${Platform.pathSeparator}secilen.jpg')..writeAsBytesSync([1, 2, 3]);
      await liste(); // an empty feed that was read is a kept page
      ortam.api.cevrimdisi = true;

      await ortam.asistan.girdiGonder(metin: 'beyaz tahta', fotografKaynagi: kaynak.path);

      final yerel = (await liste()).first;
      expect(yerel.yerelFotograf, isNotNull);
      expect(yerel.yerelFotograf, isNot(kaynak.path), reason: 'a copy, not the picker\'s file');
      expect(File(yerel.yerelFotograf!).existsSync(), isTrue);

      ortam.api.cevrimdisi = false;
      expect(await ortam.esitleyici.gonder(), 1);
      expect(ortam.api.yuklenenDosyalar.single, yerel.yerelFotograf);
      expect(ortam.api.asistanGirdileri.single.fotografId, 'f1');
      expect(File(yerel.yerelFotograf!).existsSync(), isFalse, reason: 'the server has the photo now');
    });

    test('a photo alone is an input too', () async {
      final kaynak = File('${ortam.fotografKlasoru.path}${Platform.pathSeparator}tek.jpg')..writeAsBytesSync([1]);
      await ortam.asistan.girdiGonder(fotografKaynagi: kaynak.path);
      await ortam.esitleyici.gonder();

      expect(ortam.api.asistanGirdileri.single.metin, isNull);
      expect(ortam.api.asistanGirdileri.single.fotografId, 'f1');
    });

    test('a photo that is already uploaded is not uploaded again when the send is retried', () async {
      final kaynak = File('${ortam.fotografKlasoru.path}${Platform.pathSeparator}iki.jpg')..writeAsBytesSync([1]);
      await ortam.asistan.girdiGonder(metin: 'x', fotografKaynagi: kaynak.path);
      // The upload works, the input fails once on the server side (5xx): the entry stays queued with the photo id.
      ortam.api.gunYazmaHatasi = 503;
      await ortam.esitleyici.gonder();
      expect(ortam.api.yuklenenDosyalar, hasLength(1));

      ortam.api.gunYazmaHatasi = null;
      await ortam.esitleyici.gonder();

      expect(ortam.api.yuklenenDosyalar, hasLength(1), reason: 'one upload for two sends');
      expect(ortam.api.asistanGirdileri.single.fotografId, 'f1');
    });

    test('an input the server refuses for good stays on the feed with the reason; deleting it takes it and its photo off', () async {
      final kaynak = File('${ortam.fotografKlasoru.path}${Platform.pathSeparator}uc.jpg')..writeAsBytesSync([1]);
      await ortam.asistan.girdiGonder(metin: 'x', fotografKaynagi: kaynak.path);
      ortam.api.gunYazmaHatasi = 400;
      await ortam.esitleyici.gonder();

      final satir = (await liste()).first;
      expect(satir.bekliyor, isFalse);
      expect(satir.gonderilemedi, 'Sunucu bu işi kabul etmedi.');

      await ortam.asistan.girdiyiSil(satir.id.replaceFirst('yerel:', ''));
      expect(await liste().then((l) => l.where((o) => o.id.startsWith('yerel:'))), isEmpty);
      expect(await ortam.esitleyici.bekleyenler(reddedilenler: true), isEmpty);
    });

    test('no connection: the input waits and is not lost', () async {
      await ortam.asistan.girdiGonder(metin: 'x');
      ortam.api.cevrimdisi = true;

      expect(await ortam.esitleyici.gonder(), 0);
      expect(await ortam.esitleyici.bekleyenler(), hasLength(1));
    });
  });

  group('questions, approvals and undo', () {
    test('an answered question leaves the list and shows as the person\'s message; the answer is sent to the question\'s route', () async {
      ortam.api.akisOgeleri = sunucuAkisi();
      await liste();
      ortam.api.cevrimdisi = true;

      await ortam.asistan.cevapla('q1', ' Yarına al ');

      final l = await liste();
      expect(l.any((o) => o.tur == AkisTuru.soru), isFalse);
      expect(l.first.metin, 'Yarına al');
      expect(l.first.bekliyor, isTrue);

      ortam.api.cevrimdisi = false;
      await ortam.esitleyici.gonder();
      expect(ortam.api.asistanCevaplari, [('q1', 'Yarına al')]);
    });

    test('an answer to a question that is gone or answered elsewhere (404, 409) counts as done', () async {
      await ortam.asistan.cevapla('q1', 'A');
      ortam.api.gunYazmaHatasi = 409;

      expect(await ortam.esitleyici.gonder(), 1);
      expect(await ortam.esitleyici.reddedilenler(), isEmpty);
    });

    test('an approval decided here leaves "waiting": "Ekle" and "Geç" are the queue\'s own decisions', () async {
      ortam.api.akisOgeleri = [
        ornekAkis('o1', AkisTuru.onay, eylem: ornekEylem(id: 'e1')),
        ornekAkis('o2', AkisTuru.onay, eylem: ornekEylem(id: 'e2')),
      ];
      await liste();
      ortam.api.cevrimdisi = true;

      await ortam.asistan.onayla(ornekEylem(id: 'e1'));
      await ortam.asistan.reddet(ornekEylem(id: 'e2'));

      expect(await liste(), isEmpty);
      final turler = (await ortam.esitleyici.bekleyenler()).map((b) => (b.tur, b.hedefId)).toList();
      expect(turler, [(BekleyenTur.eylemUygula, 'e1'), (BekleyenTur.eylemReddet, 'e2')]);
    });

    test('"Geri al" on an applied result queues the undo and marks the result; it cannot be undone twice', () async {
      ortam.api.akisOgeleri = sunucuAkisi();
      await liste();
      ortam.api.cevrimdisi = true;

      await ortam.asistan.geriAl(ornekSonuc());

      final sonuc = (await liste()).firstWhere((o) => o.id == 's2').sonuclar.single;
      expect(sonuc.geriAlinabilir, isFalse);
      expect(sonuc.mesaj, 'Geri alınıyor');
      final kuyruk = await ortam.esitleyici.bekleyenler();
      expect(kuyruk.single.tur, BekleyenTur.eylemGeriAl);
      expect(kuyruk.single.hedefId, 'e1');
    });

    test('"Geri al" on a note deletes the capture; its row leaves the feed and a result about it is marked', () async {
      ortam.api.akisOgeleri = [
        ornekAkis('n1', AkisTuru.not, yakalama: yakalama),
        ornekAkis('n2', AkisTuru.sonuc, sonuclar: [ornekSonuc(tur: sonucTuruNot, baslik: 'Not', eylemId: null, hedefKimlik: 'y1')]),
      ];
      await liste();
      ortam.api.cevrimdisi = true;

      await ortam.asistan.geriAl(ornekSonuc(tur: sonucTuruNot, eylemId: null, hedefKimlik: 'y1'));

      final l = await liste();
      expect(l.any((o) => o.tur == AkisTuru.not), isFalse);
      expect(l.single.sonuclar.single.mesaj, 'Geri alınıyor');
      final kuyruk = await ortam.esitleyici.bekleyenler();
      expect(kuyruk.single.tur, BekleyenTur.yakalamaSil);
      expect(kuyruk.single.hedefId, 'y1');

      ortam.api.cevrimdisi = false;
      expect(await ortam.esitleyici.gonder(), 1);
      expect(ortam.api.silinenYakalamalar, ['y1'], reason: 'the capture\'s own delete route');
    });

    test('the undo is sent to the approval queue\'s own route', () async {
      ortam.api.eylemler = [ornekEylem(id: 'e7', durum: EylemDurumu.uygulandi)];
      await ortam.asistan.geriAl(ornekSonuc(eylemId: 'e7'));
      expect(await ortam.esitleyici.gonder(), 1);
      expect(ortam.api.cagrilar, contains('eylemGeriAl:e7'));
    });
  });

  test('the number that waits is the server\'s', () async {
    ortam.api.asistanBekleyenSayisi = 4;
    expect(await ortam.asistan.bekleyenSayisi(), 4);
  });
}
