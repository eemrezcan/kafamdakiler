import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/eylem.dart';

import '../test_destek.dart';

// The approval queue on the phone: the cache, and the offline decision queue laid over it (the reminders pattern).

void main() {
  late TestOrtami ortam;

  setUp(() {
    ortam = TestOrtami();
    ortam.api.eylemler = [
      ornekEylem(id: 'a', ozet: 'Ali\'yi ara', createdAt: DateTime.utc(2026, 11, 1, 8)),
      ornekEylem(id: 'b', ozet: 'Faturayı öde', createdAt: DateTime.utc(2026, 11, 2, 8)),
      ornekEylem(id: 'u', ozet: 'Uygulanmış', durum: EylemDurumu.uygulandi),
      ornekEylem(id: 'h', ozet: 'Patlayan', durum: EylemDurumu.hatali),
    ];
  });
  tearDown(() async => ortam.kapat());

  Map<String, Eylem> harita(List<Eylem> liste) => {for (final e in liste) e.id: e};

  group('reading', () {
    test('fetches the waiting, applied and failed ones and keeps them in the phone cache', () async {
      final sonuc = await ortam.eylemler.listele();

      expect(sonuc.cevrimdisi, isFalse);
      expect(sonuc.liste.map((e) => e.id).toSet(), {'a', 'b', 'u', 'h'});
      expect(ortam.api.cagrilar, ['eylemleriGetir:bekliyor', 'eylemleriGetir:uygulandi', 'eylemleriGetir:hatali']);
      expect((await ortam.eylemler.yerelListe()).map((e) => e.id).toSet(), {'a', 'b', 'u', 'h'});
    });

    test('offline, the cached list is returned and says so', () async {
      await ortam.eylemler.listele();
      ortam.api.cevrimdisi = true;

      final sonuc = await ortam.eylemler.listele();

      expect(sonuc.cevrimdisi, isTrue);
      expect(sonuc.liste, hasLength(4));
    });

    test('a server refusal (403: no permission) is thrown, not hidden behind the cache', () async {
      ortam.api.sunucuHatasi = 403;

      await expectLater(ortam.eylemler.listele(), throwsA(isA<DioException>()));
    });

    test('the payload survives the cache as it was sent', () async {
      ortam.api.eylemler = [ornekEylem(id: 'a', yuk: {'baslik': 'Ali\'yi ara', 'gun': '2030-01-01', 'saat': '10:30:00'})];
      await ortam.eylemler.listele();

      final e = (await ortam.eylemler.getir('a'))!;

      expect(e.yuk, {'baslik': 'Ali\'yi ara', 'gun': '2030-01-01', 'saat': '10:30:00'});
      expect(e.turAdi, 'Hatırlatıcı kur');
    });
  });

  group('decisions made offline', () {
    setUp(() async {
      await ortam.eylemler.listele();
      ortam.api.cevrimdisi = true;
    });

    test('approve, reject and undo show at once, without the network', () async {
      await ortam.eylemler.uygula('a');
      await ortam.eylemler.reddet('b');
      await ortam.eylemler.geriAl('u');

      final liste = harita(await ortam.eylemler.yerelListe());
      expect(liste['a']!.durum, EylemDurumu.uygulandi);
      expect(liste['b']!.durum, EylemDurumu.reddedildi);
      expect(liste['u']!.durum, EylemDurumu.geriAlindi);
      expect(liste['h']!.durum, EylemDurumu.hatali, reason: 'untouched');
      expect(await ortam.esitleyici.bekleyenler(), hasLength(3));
    });

    test('a corrected payload replaces the suggested one on the screen', () async {
      await ortam.eylemler.uygula('a', yuk: {'baslik': 'Düzeltilmiş', 'gun': '2031-02-03'});

      expect((await ortam.eylemler.getir('a'))!.yuk['baslik'], 'Düzeltilmiş');
    });

    test('a decision only counts when the action is in the state it needs', () async {
      await ortam.eylemler.geriAl('a'); // waiting: nothing to undo
      await ortam.eylemler.uygula('u'); // already applied
      await ortam.eylemler.reddet('h'); // failed

      final liste = harita(await ortam.eylemler.yerelListe());
      expect(liste['a']!.durum, EylemDurumu.bekliyor);
      expect(liste['u']!.durum, EylemDurumu.uygulandi);
      expect(liste['h']!.durum, EylemDurumu.hatali);
    });

    test('approve then undo, in queue order, ends as undone', () async {
      await ortam.eylemler.uygula('a');
      await ortam.eylemler.geriAl('a');

      expect((await ortam.eylemler.getir('a'))!.durum, EylemDurumu.geriAlindi);
    });

    test('the listeners are told, so lists reload', () async {
      var kez = 0;
      ortam.eylemler.addListener(() => kez++);

      await ortam.eylemler.uygula('a');
      await ortam.eylemler.reddet('b');
      await ortam.eylemler.geriAl('u');

      expect(kez, 3);
    });

    test('nothing is sent while offline; everything goes in order when the connection is back', () async {
      await ortam.eylemler.uygula('a', yuk: {'baslik': 'Düz', 'gun': '2031-02-03'});
      await ortam.eylemler.reddet('b', birDahaOnerme: true);
      await ortam.eylemler.geriAl('u');
      expect(await ortam.esitleyici.gonder(), 0);

      ortam.api.cevrimdisi = false;
      ortam.api.cagrilar.clear();
      expect(await ortam.esitleyici.gonder(), 3);

      expect(ortam.api.cagrilar, [
        'eylemUygula:a:yuk={"baslik":"Düz","gun":"2031-02-03"}',
        'eylemReddet:b:true',
        'eylemGeriAl:u',
      ]);
      expect(await ortam.esitleyici.bekleyenler(), isEmpty);
      expect(ortam.api.eylemler.firstWhere((e) => e.id == 'a').yuk['baslik'], 'Düz');
    });

    test('approving without a correction sends no payload at all', () async {
      await ortam.eylemler.uygula('a');
      ortam.api.cevrimdisi = false;
      ortam.api.cagrilar.clear();

      await ortam.esitleyici.gonder();

      expect(ortam.api.cagrilar, ['eylemUygula:a']);
    });
  });

  group('what the server answers', () {
    test('409 (already decided elsewhere) is not an error: the entry is dropped from the queue quietly', () async {
      await ortam.eylemler.listele();
      await ortam.eylemler.uygula('a');
      ortam.api.eylemKararHatasi = 409;

      expect(await ortam.esitleyici.gonder(), 1);

      expect(await ortam.esitleyici.bekleyenler(reddedilenler: true), isEmpty);
      expect(await ortam.esitleyici.reddedilenler(), isEmpty);
    });

    test('400 (the corrected payload broke the rules) is kept as a refused entry and the action is waiting again', () async {
      await ortam.eylemler.listele();
      await ortam.eylemler.uygula('a', yuk: {'baslik': '', 'gun': '2031-02-03'});
      expect((await ortam.eylemler.getir('a'))!.durum, EylemDurumu.uygulandi, reason: 'shown at once');
      ortam.api.eylemKararHatasi = 400;

      await ortam.esitleyici.gonder();

      final reddedilen = await ortam.esitleyici.reddedilenler();
      expect(reddedilen, hasLength(1));
      expect(reddedilen.single.hata, startsWith('400'));
      expect((await ortam.eylemler.getir('a'))!.durum, EylemDurumu.bekliyor, reason: 'a refused entry is not laid over the list');
    });

    test('a failed connection keeps the entry for the next try', () async {
      await ortam.eylemler.listele();
      await ortam.eylemler.reddet('a');
      ortam.api.cevrimdisi = true;

      expect(await ortam.esitleyici.gonder(), 0);

      expect(await ortam.esitleyici.bekleyenler(), hasLength(1));
    });
  });

  group('announcing', () {
    test('only the waiting ones that were not announced are listed; marking them removes them', () async {
      await ortam.eylemler.listele();

      expect((await ortam.eylemler.bildirilmemisBekleyenler()).map((e) => e.id).toSet(), {'a', 'b'});

      await ortam.eylemler.bildirildiIsaretle(['a']);
      expect((await ortam.eylemler.bildirilmemisBekleyenler()).map((e) => e.id), ['b']);
    });

    test('the mark survives a refresh from the server', () async {
      await ortam.eylemler.listele();
      await ortam.eylemler.bildirildiIsaretle(['a', 'b']);

      ortam.api.eylemler = [...ortam.api.eylemler, ornekEylem(id: 'c', ozet: 'Yeni')];
      await ortam.eylemler.listele();

      expect((await ortam.eylemler.bildirilmemisBekleyenler()).map((e) => e.id), ['c']);
    });

    test('an action decided on the phone is not announced any more', () async {
      await ortam.eylemler.listele();
      await ortam.eylemler.reddet('a');

      expect((await ortam.eylemler.bildirilmemisBekleyenler()).map((e) => e.id), ['b']);
    });
  });
}
