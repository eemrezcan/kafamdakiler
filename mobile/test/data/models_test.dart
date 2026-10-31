import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/aliskanlik.dart';
import 'package:kafamdakiler/data/models/enums.dart';
import 'package:kafamdakiler/data/models/giris.dart';
import 'package:kafamdakiler/data/models/gun.dart';
import 'package:kafamdakiler/data/models/oge.dart';
import 'package:kafamdakiler/data/models/oturum.dart';

/// Parses a contract sample, writes it back and parses again: the second
/// write must equal the first (stable), and key fields must survive.
Map<String, dynamic> _json(String metin) => jsonDecode(metin) as Map<String, dynamic>;

void main() {
  test('AliskanlikDto sample', () {
    final json = _json('''
{ "id": "0192e0a0-0000-7000-8000-000000000001", "ad": "Kitap okuma", "tur": "raf", "ikon": "book-open", "renk": "violet",
  "olcu": "sayili", "hedefYonu": "enAz", "gunlukHedef": 30, "birim": "sayfa",
  "ogeEtiketi": "Kitap", "altBaslikEtiketi": "Yazar",
  "siklik": "belirliGunler", "haftalikSayi": null, "gunler": ["pzt", "cum"],
  "sira": 0, "arsivlendi": false, "olusturulma": "2026-10-31T18:00:00Z",
  "bugun": { "tarih": "2026-10-31", "miktar": 23, "dakika": 40, "deger": 0.77, "planli": true },
  "guc": 0.64, "seri": 5, "enUzunSeri": 12,
  "devamEdenler": [ { "id": "0192e0a0-0000-7000-8000-000000000002", "ad": "Kürk Mantolu Madonna", "altBaslik": "Sabahattin Ali",
                      "fotografUrl": "/api/dosyalar/abc", "guncelKonum": 35, "toplam": 160, "ilerleme": 0.22 } ] }
''');
    final a = Aliskanlik.fromJson(json);
    expect(a.tur, AliskanlikTuru.raf);
    expect(a.olcu, Olcu.sayili);
    expect(a.hedefYonu, HedefYonu.enAz);
    expect(a.siklik, Siklik.belirliGunler);
    expect(a.gunler, [HaftaGunu.pzt, HaftaGunu.cum]);
    expect(a.gunlukHedef, 30);
    expect(a.haftalikSayi, isNull);
    expect(a.bugun!.tarih, DateTime.utc(2026, 10, 31));
    expect(a.bugun!.dakika, 40);
    expect(a.devamEdenler.single.ad, 'Kürk Mantolu Madonna');
    expect(a.devamEdenler.single.ilerleme, 0.22);

    final yazilan = a.toJson();
    expect(yazilan['tur'], 'raf');
    expect(yazilan['hedefYonu'], 'enAz');
    expect(yazilan['siklik'], 'belirliGunler');
    expect(yazilan['gunler'], ['pzt', 'cum']);
    expect((yazilan['bugun'] as Map)['tarih'], '2026-10-31');
    expect(jsonDecode(jsonEncode(Aliskanlik.fromJson(jsonDecode(jsonEncode(yazilan))).toJson())), jsonDecode(jsonEncode(yazilan)));
  });

  test('AliskanlikDto without optional parts', () {
    final a = Aliskanlik.fromJson(_json('''
{ "id": "x", "ad": "Su iç", "tur": "sayac", "ikon": "droplet", "renk": "pink", "olcu": "sayili", "hedefYonu": "enAz",
  "gunlukHedef": 8, "birim": "bardak", "siklik": "herGun", "sira": 1, "arsivlendi": false,
  "olusturulma": "2026-10-31T18:00:00Z" }'''));
    expect(a.bugun, isNull);
    expect(a.devamEdenler, isEmpty);
    expect(a.gunler, isNull);
  });

  test('AliskanlikYaz omits nulls and writes enum strings', () {
    const yaz = AliskanlikYaz(
      ad: 'Su iç',
      tur: AliskanlikTuru.sayac,
      ikon: 'droplet',
      renk: 'violet',
      olcu: Olcu.sayili,
      hedefYonu: HedefYonu.enCok,
      gunlukHedef: 8,
      birim: 'bardak',
      siklik: Siklik.haftadaN,
      haftalikSayi: 3,
    );
    final json = yaz.toJson();
    expect(json.containsKey('id'), isFalse);
    expect(json.containsKey('gunler'), isFalse);
    expect(json['hedefYonu'], 'enCok');
    expect(json['siklik'], 'haftadaN');
    expect(AliskanlikYaz.fromJson(json).toJson(), json);
  });

  test('GunDto sample', () {
    final json = _json('{ "tarih": "2026-10-31", "miktar": 6, "dakika": null, "deger": 0.75, "planli": true, "guc": 0.58 }');
    final g = Gun.fromJson(json);
    expect(g.tarih, DateTime.utc(2026, 10, 31));
    expect(g.dakika, isNull);
    expect(g.toJson()['tarih'], '2026-10-31');
    expect(Gun.fromJson(g.toJson()).toJson(), g.toJson());
  });

  test('GunYaz body', () {
    expect(const GunYaz(miktar: 6, dakika: 12).toJson(), {'miktar': 6.0, 'dakika': 12});
    expect(const GunYaz(miktar: 1).toJson(), {'miktar': 1.0});
  });

  test('OgeDto sample', () {
    final json = _json('''
{ "id": "o1", "aliskanlikId": "a1", "ad": "Kürk Mantolu Madonna", "altBaslik": "Sabahattin Ali",
  "toplam": 160, "baslangicKonumu": 12, "guncelKonum": 35, "ilerleme": 0.22,
  "fotografId": "f1", "fotografUrl": "/api/dosyalar/f1", "durum": "devam",
  "baslamaTarihi": "2026-10-31", "bitisTarihi": null, "puan": null, "not": null,
  "hiz": 23.0, "tahminiBitis": "2026-11-06", "toplamDakika": 40, "olusturulma": "2026-10-31T18:00:00Z" }''');
    final o = Oge.fromJson(json);
    expect(o.durum, OgeDurumu.devam);
    expect(o.baslamaTarihi, DateTime.utc(2026, 10, 31));
    expect(o.bitisTarihi, isNull);
    expect(o.tahminiBitis, DateTime.utc(2026, 11, 6));
    expect(o.guncelKonum, 35);
    final yazilan = o.toJson();
    expect(yazilan['durum'], 'devam');
    expect(yazilan['baslamaTarihi'], '2026-10-31');
    expect(yazilan['bitisTarihi'], isNull);
    expect(Oge.fromJson(yazilan).toJson(), yazilan);
  });

  test('OgeYaz body', () {
    const yaz = OgeYaz(ad: 'Kürk Mantolu Madonna', toplam: 160, baslangicKonumu: 12, durum: OgeDurumu.siradaki);
    final json = yaz.toJson();
    expect(json['durum'], 'siradaki');
    expect(json.containsKey('puan'), isFalse);
    expect(OgeYaz.fromJson(json).toJson(), json);
  });

  test('OturumDto sample', () {
    final json = _json('''
{ "id": "s1", "ogeId": "o1", "tarih": "2026-10-31", "baslangicKonum": 12, "bitisKonum": 35, "miktar": 23,
  "dakika": 40, "olusturulma": "2026-10-31T18:10:00Z", "son": true }''');
    final s = Oturum.fromJson(json);
    expect(s.miktar, 23);
    expect(s.son, isTrue);
    expect(s.tarih, DateTime.utc(2026, 10, 31));
    expect(Oturum.fromJson(s.toJson()).toJson(), s.toJson());
  });

  test('OturumEkle writes the start instant as UTC ISO 8601', () {
    final ekle = OturumEkle.fromJson(_json(
      '{ "id": "s1", "bitisKonum": 35, "dakika": 40, "baslangicKonum": 12, "baslangicAni": "2026-10-31T21:10:00+03:00" }',
    ));
    expect(ekle.baslangicAni, DateTime.utc(2026, 10, 31, 18, 10));
    final json = ekle.toJson();
    expect(json['baslangicAni'], '2026-10-31T18:10:00.000Z');
    expect(OturumEkle.fromJson(json).toJson(), json);
    expect(const OturumEkle(bitisKonum: 35).toJson(), {'bitisKonum': 35.0});
  });

  test('login response', () {
    final y = GirisYaniti.fromJson(_json(
      '{ "tokenType": "Bearer", "accessToken": "a", "expiresIn": 3600, "refreshToken": "r" }',
    ));
    expect(y.expiresIn, 3600);
    expect(y.toJson()['refreshToken'], 'r');
    expect(const GirisIstegi(email: 'e@x.com', password: 'p').toJson(), {'email': 'e@x.com', 'password': 'p'});
  });
}
