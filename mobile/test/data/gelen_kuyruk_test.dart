import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/eylem.dart';
import 'package:kafamdakiler/data/models/gelen.dart';

import '../test_destek.dart';

// The inbox on the phone: the cache, and the offline queue (place, delete, approve, reject) laid over it.

void main() {
  late TestOrtami ortam;

  const girdi = GelenIsleGirdi(yol: 'ogrenme/simyaci.md', baslik: 'Simyacı', etiketler: ['kaynak', 'okul']);

  setUp(() {
    ortam = TestOrtami();
    ortam.api.gelenKartlari = [
      ornekGelenKarti(kimlik: 'a', ozet: 'Önerili kart', eylemId: 'e-a'),
      ornekGelenKarti(kimlik: 'b', ozet: 'Önerisiz kart'),
      ornekGelenKarti(kimlik: 'c', ozet: 'Laptopta kart', laptoptaIslenecek: true),
    ];
    ortam.api.eylemler = [
      ornekEylem(id: 'e-a', ozet: 'Önerili kart → ogrenme/x.md'),
    ];
  });
  tearDown(() async => ortam.kapat());

  Map<String, GelenKarti> harita(List<GelenKarti> liste) => {for (final k in liste) k.kimlik: k};

  group('reading', () {
    test('fetches the cards with their suggestions and keeps them in the phone cache', () async {
      final sonuc = await ortam.gelen.listele();

      expect(sonuc.cevrimdisi, isFalse);
      expect(sonuc.liste.map((k) => k.kimlik), ['a', 'b', 'c']);
      final a = harita(await ortam.gelen.yerelListe())['a']!;
      expect(a.oneri!.eylemId, 'e-a');
      expect(a.oneri!.etiketler, ['kaynak', 'okul']);
      expect(a.oneri!.guven, 0.9);
      expect(harita(await ortam.gelen.yerelListe())['c']!.laptoptaIslenecek, isTrue);
      expect(harita(await ortam.gelen.yerelListe())['c']!.laptopNotu, contains('mimari-karar'));
    });

    test('offline, the cached list is returned and says so', () async {
      await ortam.gelen.listele();
      ortam.api.cevrimdisi = true;

      final sonuc = await ortam.gelen.listele();

      expect(sonuc.cevrimdisi, isTrue);
      expect(sonuc.liste, hasLength(3));
    });

    test('a server refusal (403 no permission, 503 brain off) is thrown, not hidden behind the cache', () async {
      await ortam.gelen.listele();
      ortam.api.sunucuHatasi = 503;

      await expectLater(ortam.gelen.listele(), throwsA(isA<DioException>()));
    });

    test('the list is replaced as a whole: a card that was placed elsewhere leaves the cache', () async {
      await ortam.gelen.listele();
      ortam.api.gelenKartlari = [ornekGelenKarti(kimlik: 'b')];

      await ortam.gelen.listele();

      expect(harita(await ortam.gelen.yerelListe()).keys, ['b']);
    });

    test('the JSON round trip keeps everything', () {
      final k = ornekGelenKarti(eylemId: 'e1', disKaynak: true, guven: 0.4);

      final geri = GelenKarti.fromJson(k.toJson());

      expect(geri.oneri!.disKaynak, isTrue);
      expect(geri.oneri!.eminDegil, isTrue);
      expect(geri.yakalandi, '2026-11-03T18:40');
    });
  });

  group('decisions made offline', () {
    setUp(() async {
      await ortam.gelen.listele();
      ortam.api.cevrimdisi = true;
    });

    test('placing a card by hand takes it off the list at once, without the network', () async {
      await ortam.gelen.isle('b', girdi);

      expect(harita(await ortam.gelen.yerelListe()).keys, ['a', 'c']);
      expect(await ortam.esitleyici.bekleyenler(), hasLength(1));
    });

    test('deleting a card takes it off the list at once', () async {
      await ortam.gelen.sil('c');

      expect(harita(await ortam.gelen.yerelListe()).keys, ['a', 'b']);
    });

    test('approving the suggestion places the card, so the card leaves; rejecting leaves the card without its suggestion', () async {
      await ortam.eylemler.uygula('e-a');
      expect(harita(await ortam.gelen.yerelListe()).keys, ['b', 'c']);

      // A second suggestion on another card, rejected.
      ortam.api.cevrimdisi = false;
      ortam.api.gelenKartlari = [ornekGelenKarti(kimlik: 'x', eylemId: 'e-x'), ornekGelenKarti(kimlik: 'b')];
      ortam.api.eylemler = [...ortam.api.eylemler, ornekEylem(id: 'e-x')];
      await ortam.gelen.listele();
      await ortam.eylemler.reddet('e-x');

      final x = harita(await ortam.gelen.yerelListe())['x']!;
      expect(x.oneri, isNull);
      expect(x.ozet, 'Kitap önerisi: Simyacı');
    });

    test('the listeners are told, so lists reload', () async {
      var kez = 0;
      ortam.gelen.addListener(() => kez++);

      await ortam.gelen.isle('b', girdi);
      await ortam.gelen.sil('c');

      expect(kez, 2);
    });

    test('nothing is sent while offline; everything goes in order when the connection is back', () async {
      await ortam.gelen.isle('b', girdi);
      await ortam.gelen.sil('c');
      await ortam.eylemler.uygula('e-a');
      expect(await ortam.esitleyici.gonder(), 0);

      ortam.api.cevrimdisi = false;
      ortam.api.cagrilar.clear();
      expect(await ortam.esitleyici.gonder(), 3);

      expect(ortam.api.cagrilar, [
        'gelenIsle:b:ogrenme/simyaci.md:Simyacı:kaynak,okul',
        'gelenSil:c',
        'eylemUygula:e-a',
      ]);
      expect(await ortam.esitleyici.bekleyenler(), isEmpty);
      expect(ortam.api.gelenKartlari.map((k) => k.kimlik), ['a'], reason: 'the fake server dropped b and c; a is placed by the approval, not here');
    });

    test('asking Claude again needs the network: offline it fails instead of being queued', () async {
      await expectLater(ortam.gelen.oneriIste('b'), throwsA(isA<DioException>()));

      expect(await ortam.esitleyici.bekleyenler(), isEmpty);
    });
  });

  group('what the server answers', () {
    setUp(() async {
      await ortam.gelen.listele();
    });

    test('400 (the path or a tag broke the rules) is kept as a refused entry with the reason, and the card is back on the list', () async {
      await ortam.gelen.isle('b', const GelenIsleGirdi(yol: 'finans/x.md', baslik: 'B', etiketler: ['kaynak']));
      expect(harita(await ortam.gelen.yerelListe()).keys, isNot(contains('b')), reason: 'gone at once');
      ortam.api.gelenYazmaHatasi = 400;

      await ortam.esitleyici.gonder();

      final reddedilen = await ortam.esitleyici.reddedilenler();
      expect(reddedilen, hasLength(1));
      expect(reddedilen.single.hata, contains('Yol vault'));
      expect(harita(await ortam.gelen.yerelListe()).keys, contains('b'), reason: 'a refused entry is not laid over the list');
    });

    test('404 (the card is gone: placed on the laptop, or sent before) is done, not an error', () async {
      await ortam.gelen.sil('b');
      ortam.api.gelenYazmaHatasi = 404;

      expect(await ortam.esitleyici.gonder(), 1);

      expect(await ortam.esitleyici.reddedilenler(), isEmpty);
      expect(await ortam.esitleyici.bekleyenler(reddedilenler: true), isEmpty);
    });

    test('a failed connection keeps the entry for the next try', () async {
      await ortam.gelen.sil('b');
      ortam.api.cevrimdisi = true;

      expect(await ortam.esitleyici.gonder(), 0);

      expect(await ortam.esitleyici.bekleyenler(), hasLength(1));
    });
  });

  group('the approval queue', () {
    test('an action that cannot be undone says so (geriAlinabilir); an older server without the field means yes', () {
      final json = ornekEylem().toJson();
      final eski = {...json}..remove('geriAlinabilir');

      expect(Eylem.fromJson(eski).geriAlinabilir, isTrue);
      final degismez = Eylem.fromJson({...json, 'geriAlinabilir': false});
      expect(degismez.geriAlinabilir, isFalse);
      expect(degismez.copyWith(durum: EylemDurumu.uygulandi).geriAlinabilir, isFalse, reason: 'a decision on the phone keeps it');
    });
  });
}
