import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/zaman_cizelgesi.dart';

import '../test_destek.dart';

// The timeline on the phone (K2.3c): the JSON shape, what is kept for offline, and the errors that must not be hidden by a copy.

ZamanCizelgesi ornek({String gun = '2026-10-31', String google = GoogleDurumu.bagli}) => ZamanCizelgesi(
      gun: gun,
      google: google,
      plan: 'tamam',
      saatli: [
        ZamanCizelgesiOgesi(
          tur: ZamanCizelgesiTuru.etkinlik,
          kimlik: '1',
          baslik: 'Ekip toplantısı',
          baslangic: DateTime.utc(2026, 10, 31, 6, 30),
          saat: '09:30',
          bitis: DateTime.utc(2026, 10, 31, 7, 30),
          bitisSaati: '10:30',
          sureDk: 60,
          yer: 'Ofis',
        ),
        ZamanCizelgesiOgesi(
          tur: ZamanCizelgesiTuru.hatirlatici,
          kimlik: 'h1',
          baslik: 'İlaç',
          baslangic: DateTime.utc(2026, 10, 31, 11),
          saat: '14:00',
        ),
      ],
      saatsiz: const [ZamanCizelgesiOgesi(tur: ZamanCizelgesiTuru.plan, kimlik: 'm1', baslik: 'Rapor', durum: 'acik', bolum: 'Yapılacaklar', tahminDk: 45)],
      kapasite: const ZamanCizelgesiKapasitesi(planDk: 400, etkinlikDk: 120, toplamDk: 520, kapasiteDk: 480, asimDk: 40),
      sonEsitleme: DateTime.utc(2026, 10, 31, 8),
    );

void main() {
  late TestOrtami ortam;

  setUp(() => ortam = TestOrtami());
  tearDown(() async => ortam.kapat());

  test('the JSON the server sends is read, and what is kept reads back the same', () {
    final sunucu = jsonDecode('''
      {"gun":"2026-10-31","google":"bagliDegil","plan":"yok",
       "saatli":[{"tur":"etkinlik","kimlik":"7","baslik":"Diş","tumGun":false,"baslangic":"2026-10-31T10:00:00+03:00","saat":"10:00",
                  "bitis":"2026-10-31T11:00:00+03:00","bitisSaati":"11:00","sureDk":60,"yer":null,"durum":null,"bolum":null,"tahminDk":null}],
       "saatsiz":[{"tur":"etkinlik","kimlik":"8","baslik":"Tatil","tumGun":true,"baslangic":null,"saat":null,"bitis":null,"bitisSaati":null,
                   "sureDk":null,"yer":null,"durum":null,"bolum":null,"tahminDk":null}],
       "kapasite":null,"sonEsitleme":null}
    ''') as Map<String, dynamic>;
    final c = ZamanCizelgesi.fromJson(sunucu);
    expect(c.google, GoogleDurumu.bagliDegil);
    expect(c.saatli.single.baslangic, DateTime.utc(2026, 10, 31, 7));
    expect(c.saatli.single.saatAraligi, '10:00 - 11:00');
    expect(c.saatsiz.single.tumGun, isTrue);
    expect(c.kapasite, isNull);
    expect(ZamanCizelgesi.fromJson(c.toJson()).toJson(), c.toJson());
  });

  test('today is asked for by the 05:00 rule and kept', () async {
    ortam.api.zamanCizelgesiYaniti = ornek();
    final okuma = await ortam.zamanCizelgesi.oku(ortam.zamanCizelgesi.bugun);
    expect(ortam.api.zamanCizelgesiGunleri, ['2026-10-31']);
    expect(okuma.guncel, isTrue);
    expect(okuma.cizelge.saatli.map((o) => o.baslik), ['Ekip toplantısı', 'İlaç'], reason: 'the server order is kept');
    expect((await ortam.zamanCizelgesi.yerel(ortam.zamanCizelgesi.bugun))!.kapasite!.asimDk, 40);
  });

  test('offline, the last kept timeline of that day is returned and marked as not fresh', () async {
    ortam.api.zamanCizelgesiYaniti = ornek();
    await ortam.zamanCizelgesi.oku(ortam.zamanCizelgesi.bugun);

    ortam.api.cevrimdisi = true;
    final okuma = await ortam.zamanCizelgesi.oku(ortam.zamanCizelgesi.bugun);
    expect(okuma.guncel, isFalse);
    expect(okuma.cizelge.saatsiz.single.baslik, 'Rapor');
  });

  test('offline with nothing kept is an error; a refusal (403) is an error even with a copy', () async {
    ortam.api.cevrimdisi = true;
    await expectLater(ortam.zamanCizelgesi.oku(ortam.zamanCizelgesi.bugun), throwsA(anything));

    ortam.api.cevrimdisi = false;
    ortam.api.zamanCizelgesiYaniti = ornek();
    await ortam.zamanCizelgesi.oku(ortam.zamanCizelgesi.bugun);
    ortam.api.zamanCizelgesiHatasi = 403;
    await expectLater(ortam.zamanCizelgesi.oku(ortam.zamanCizelgesi.bugun), throwsA(anything));
  });

  test('only the newest 14 days are kept', () async {
    for (var i = 1; i <= 16; i++) {
      final gun = '2026-10-${i.toString().padLeft(2, '0')}';
      ortam.api.zamanCizelgesiYaniti = ornek(gun: gun);
      await ortam.zamanCizelgesi.oku(DateTime.utc(2026, 10, i));
    }
    final satirlar = await ortam.db.select(ortam.db.zamanCizelgesiOnbellek).get();
    expect(satirlar, hasLength(14));
    expect(await ortam.zamanCizelgesi.yerel(DateTime.utc(2026, 10, 1)), isNull);
    expect(await ortam.zamanCizelgesi.yerel(DateTime.utc(2026, 10, 16)), isNotNull);
  });

  test('signing out drops the kept timelines', () async {
    ortam.api.zamanCizelgesiYaniti = ornek();
    await ortam.zamanCizelgesi.oku(ortam.zamanCizelgesi.bugun);
    await ortam.db.hepsiniTemizle();
    expect(await ortam.zamanCizelgesi.yerel(ortam.zamanCizelgesi.bugun), isNull);
  });
}
