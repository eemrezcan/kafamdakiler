import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/bildirim_ogesi.dart';
import 'package:kafamdakiler/data/models/enums.dart';
import 'package:kafamdakiler/data/models/gun_gorunum.dart';
import 'package:kafamdakiler/data/models/hatirlatici.dart';
import 'package:kafamdakiler/data/models/is_karti.dart';
import 'package:kafamdakiler/data/models/sunucu_bildirimi.dart';
import 'package:kafamdakiler/ui/asistan/is_hata.dart';
import 'package:kafamdakiler/ui/core/hata_metni.dart';

/// The models read the answers of the real API (A1 and A2 of K-0024), kept as files in `test/fixtures/api/`. They were taken from
/// a backend running on this machine (`gun.http`, `ayarlar.http`, `bildirimler.http`, `hatirlaticilar.http`, the work cards),
/// with the trace ids and e-mail addresses taken out. When the server changes a shape, a new capture goes here first.
void main() {
  /// A fixture: the status and the body of the answer.
  ({int durum, dynamic govde}) oku(String ad) {
    final j = jsonDecode(File('test/fixtures/api/$ad.json').readAsStringSync()) as Map<String, dynamic>;
    return (durum: j['durum'] as int, govde: j['govde']);
  }

  Map<String, dynamic> harita(String ad) => oku(ad).govde as Map<String, dynamic>;
  List<dynamic> liste(String ad) => oku(ad).govde as List<dynamic>;

  group('the day view (GET /api/gun/{tarih})', () {
    test('the whole day: the date, the load, the rows and where the data came from', () {
      final gun = GunGorunum.fromJson(harita('gun_bugun_sonra'));

      expect(gun.tarih, DateTime.utc(2026, 11, 10));
      expect(gun.bugun, isTrue);
      expect(gun.kapandi, isFalse);
      expect(gun.ozet, 'Bugün 5 açık iş var, tahmini 30 dk.');
      expect(gun.yuk.kapasiteDk, 360);
      expect(gun.yuk.acikTahminDk, 30);
      expect(gun.yuk.bosDk, 330);
      expect(gun.yuk.tahminsizSayi, 4);
      expect(gun.kaynaklar.plan, 'tamam');
      expect(gun.kaynaklar.google, 'kapali');
      expect(gun.kaynaklar.sonEsitleme, isNull);
      expect(gun.dundenKalanlar, isEmpty);
      expect(gun.ogeler.length, greaterThan(3));
    });

    test('a task row: typed id, its due day as the row\'s day, the days it is late, no reminder', () {
      final gun = GunGorunum.fromJson(harita('gun_bugun_sonra'));
      final gorev = gun.ogeler.firstWhere((o) => o.kimlik == 'g:dis-randevusu-al');

      expect(gorev.tur, YapilacakTuru.gorev);
      expect(gorev.gorevKimligi, 'dis-randevusu-al');
      expect(gorev.maddeId, isNull);
      expect(gorev.gecikmeGun, 5);
      expect(gorev.tarih, DateTime.utc(2026, 11, 5));
      expect(gorev.durum, 'acik');
      expect(gorev.hatirlatici, isNull);
      expect(gorev.yuke, isTrue);
    });

    test('a plan item with a weekly reminder on two days', () {
      final gun = GunGorunum.fromJson(harita('gun_bugun_sonra'));
      final plan = gun.ogeler.firstWhere((o) => o.kimlik == 'm:be3fb6');

      expect(plan.tur, YapilacakTuru.plan);
      expect(plan.maddeId, 'be3fb6');
      expect(plan.saat, '14:00');
      expect(plan.tahminDk, 30);
      expect(plan.bolum, 'Yapılacaklar');
      expect(plan.hatirlatici!.tekrar, Tekrar.haftalik);
      expect(plan.hatirlatici!.gunler, [HaftaGunu.sal, HaftaGunu.per]);
      expect(plan.hatirlatici!.israrli, isTrue);
      expect(plan.hatirlatici!.onceGun, 1);
      expect(plan.hatirlatici!.saat, '14:00');
      expect(plan.hatirlatici!.id, isNotEmpty);
    });

    test('another day is the same shape; the carried rows are on it with their estimate', () {
      final gun = GunGorunum.fromJson(harita('gun_yarin'));

      expect(gun.tarih, DateTime.utc(2026, 11, 11));
      expect(gun.bugun, isFalse);
      expect(gun.ogeler.map((o) => o.baslik), containsAll(['M3 deneme işi', 'Portfolyoya iki proje ekle']));
      expect(gun.ogeler.firstWhere((o) => o.baslik == 'M3 deneme işi').tahminDk, 30);
      expect(gun.yuk.acikTahminDk, 30);
    });

    test('every row of the day goes through toJson and back as the phone\'s cache does it', () {
      final gun = GunGorunum.fromJson(harita('gun_bugun_sonra'));
      final yeniden = GunGorunum.fromJson(jsonDecode(jsonEncode(gun.toJson())) as Map<String, dynamic>);

      expect(yeniden.ogeler.map((o) => o.kimlik), gun.ogeler.map((o) => o.kimlik));
      expect(yeniden.ogeler.firstWhere((o) => o.kimlik == 'm:be3fb6').hatirlatici!.gunler, [HaftaGunu.sal, HaftaGunu.per]);
      expect(yeniden.ogeler.first.tarih, gun.ogeler.first.tarih);
    });
  });

  group('writes on a row', () {
    test('a new item (POST /api/gun/{tarih}/ogeler) answers the row as it is now, with its reminder', () {
      final o = Yapilacak.fromJson(harita('gun_ogeler_yeni'));

      expect(o.kimlik, 'm:be3fb6');
      expect(o.tur, YapilacakTuru.plan);
      expect(o.tahminDk, 30);
      expect(o.saat, '14:00');
      expect(o.tarih, DateTime.utc(2026, 11, 10));
      expect(o.hatirlatici!.gunler, [HaftaGunu.sal, HaftaGunu.per]);
      expect(oku('gun_ogeler_yeni').durum, 200);
    });

    test('"yaptım" answers the row and what closed with it; taking it back opens the row again', () {
      final y = YaptimYaniti.fromJson(harita('gun_yaptim'));
      expect(oku('gun_yaptim').durum, 200);
      expect(y.oge.kimlik, 'm:be3fb6');
      expect(y.oge.yapildi, isTrue);
      expect(y.zincir, isA<List<String>>());
      expect(y.oge.hatirlatici!.tekrar, Tekrar.haftalik);

      final geri = YaptimYaniti.fromJson(harita('gun_yaptim_geri'));
      expect(geri.oge.yapildi, isFalse);
      expect(geri.oge.durum, 'acik');
    });

    test('the carry-over answers the row on its new day; the answer has the row under "oge"', () {
      final plan = harita('gun_devret_plan');
      expect(plan.containsKey('oge'), isTrue);
      final o = Yapilacak.fromJson(plan['oge'] as Map<String, dynamic>);
      expect(o.tarih, DateTime.utc(2026, 11, 11));
      expect(o.tahminDk, 30);
      expect(o.hatirlatici, isNull, reason: 'the reminder stays with the day it was set for');

      final gorev = Yapilacak.fromJson(harita('gun_devret_gorev')['oge'] as Map<String, dynamic>);
      expect(gorev.gorevKimligi, 'portfolyoya-iki-proje-ekle');
      expect(gorev.maddeId, isNotNull, reason: 'a task carried to tomorrow is a plan item tied to the task');
    });

    test('the reminder of a row: set up answers the reminder (201), a second set up is a conflict, a change is the reminder', () {
      expect(oku('gun_hatirlatici_post').durum, 201);
      final h = Hatirlatici.fromJson(harita('gun_hatirlatici_post'));
      expect(h.tekrar, Tekrar.haftalik);
      expect(h.gunler, [HaftaGunu.pzt, HaftaGunu.cum]);
      expect(h.acil, isTrue);
      expect(h.onceGun, 1);
      expect(h.saat, const Saat(17, 0));

      expect(oku('gun_hatirlatici_post_cakisma').durum, 409);
      final put = Hatirlatici.fromJson(harita('gun_hatirlatici_put'));
      expect(put.tekrar, Tekrar.gunluk);
      expect(put.acil, isTrue);
    });

    test('the refusals: a finished task cannot be reopened (a problem with a "kod"), an event has no "yaptım", an event cannot be carried', () {
      final g = harita('gun_yaptim_gorev_geri_hata');
      expect(oku('gun_yaptim_gorev_geri_hata').durum, 409);
      expect(g['kod'], 'gorev-geri-alinamaz');
      expect(g['type'], 'gorev-geri-alinamaz');

      expect(oku('gun_yaptim_etkinlik_hata').durum, 400);
      expect((harita('gun_yaptim_etkinlik_hata')['errors'] as Map)['kimlik'], isNotEmpty);
      expect(oku('gun_devret_etkinlik_hata').durum, 400);
    });
  });

  group('the calendar (GET /api/takvim)', () {
    test('the days with their counts and the upcoming rows, each with its day', () {
      final t = TakvimAraligi.fromJson(harita('takvim_sonra'));

      expect(t.gunler, hasLength(7));
      expect(t.gun(DateTime.utc(2026, 11, 10))!.sayilar.plan, 2);
      expect(t.gun(DateTime.utc(2026, 11, 10))!.sayilar.gorev, 1);
      expect(t.gun(DateTime.utc(2026, 11, 10))!.sayilar.toplam, 3);
      expect(t.gun(DateTime.utc(2026, 11, 10))!.yukAsimi, isFalse);
      expect(t.yaklasan, isNotEmpty);
      final r = t.yaklasan.first;
      expect(r.tur, YapilacakTuru.hatirlatici);
      expect(r.kimlik, startsWith('h:'));
      expect(r.tarih, DateTime.utc(2026, 11, 16));
      expect(r.saat, '17:00');
      expect(r.hatirlatici!.gunler, [HaftaGunu.pzt, HaftaGunu.cum]);
    });

    test('a range of more than 42 days is a 400 with the reason under the field "bitis"', () {
      expect(oku('takvim_hata_42').durum, 400);
      expect(((harita('takvim_hata_42')['errors'] as Map)['bitis'] as List).single, 'Aralık en çok 42 gün olabilir.');
    });
  });

  group('the day capacity (GET /api/ayarlar/gun)', () {
    test('both figures', () {
      final a = GunAyari.fromJson(harita('ayarlar_gun'));
      expect(a.haftaIciDk, 360);
      expect(a.haftaSonuDk, 360);
      expect(GunAyari.fromJson(a.toJson()).haftaIciDk, 360);
    });

    test('a figure out of range is a 400 with the reason under its field', () {
      expect(oku('ayarlar_hata').durum, 400);
      expect((harita('ayarlar_hata')['errors'] as Map).keys, ['haftaIciDk']);
    });
  });

  group('the notification centre (GET /api/bildirimler)', () {
    test('the unread count', () {
      expect(harita('bildirimler_sayi_dolu')['okunmamis'], 2);
    });

    test('a row: its time is the server\'s "olusmaAni", the route may hold {id}, "okundu" is there', () {
      final l = [for (final j in liste('bildirimler_liste_dolu')) BildirimOgesi.fromJson(j as Map<String, dynamic>)];

      expect(l, hasLength(3));
      expect(l[0].baslik, 'M3 deneme hatırlatıcı');
      expect(l[0].zaman, isNotNull, reason: 'olusmaAni was read');
      expect(l[0].zaman, DateTime.parse((liste('bildirimler_liste_dolu')[0] as Map)['olusmaAni'] as String).toUtc());
      expect(l[0].okundu, isFalse);
      expect(l[0].hatirlaticiMi, isTrue);
      expect(l[0].hedefKimligi, '01a1c77b-a2c3-7985-968e-19e916ccd978');
      expect(l[1].rota, '/asistan/{id}');
      expect(l[1].kaynakTuru, 'is');
      expect(l[2].okundu, isTrue);
      expect(l[2].rota, isNull);
      expect(l[0].zaman!.isAfter(l[1].zaman!) && l[1].zaman!.isAfter(l[2].zaman!), isTrue, reason: 'newest first');
    });

    test('the next page is the rows older than the oldest time of the page before', () {
      final l = [for (final j in liste('bildirimler_sonraki_sayfa')) BildirimOgesi.fromJson(j as Map<String, dynamic>)];
      expect(l.single.baslik, 'M3 deneme okunmuş');
    });

    test('one notification opened (GET /api/bildirimler/{id}) reads as the notification the push carries', () {
      final b = SunucuBildirimi.fromJson(harita('bildirim_tek'));
      expect(b.kaynakTuru, 'hatirlatici');
      expect(b.hatirlaticiZamaniMi, isTrue);
      expect(b.rota, '/takvim');
      expect(b.secenekler, isEmpty);
    });

    test('a limit out of range is a 400 with the reason under "limit"', () {
      expect(oku('bildirimler_hata_limit').durum, 400);
      expect((harita('bildirimler_hata_limit')['errors'] as Map).keys, ['limit']);
    });
  });

  group('reminders (GET /api/hatirlaticilar)', () {
    test('a reminder tied to a plan item keeps its weekdays; the fields the phone does not read are left alone', () {
      final h = Hatirlatici.fromJson(liste('hatirlaticilar_liste_bagli').first as Map<String, dynamic>);

      expect(h.tekrar, Tekrar.haftalik);
      expect(h.gunler, [HaftaGunu.pzt, HaftaGunu.cum]);
      expect(h.gun, DateTime.utc(2026, 11, 10));
      expect(h.saat, const Saat(17, 0));
      expect(h.onceGun, 1);
      expect(h.israrAraligiDakika, 15);
      expect(h.israrEnCok, 3);
      expect(h.sonrakiAn, DateTime.utc(2026, 11, 16, 14));
      expect(h.erteleAn, isNull);
      expect(h.durum, HatirlaticiDurumu.acik);
      expect(h.tur, HatirlaticiTuru.gorev);
    });

    test('the next moment the phone works out agrees with the server\'s for the same rule', () {
      final h = Hatirlatici.fromJson(liste('hatirlaticilar_liste_bagli').first as Map<String, dynamic>);
      final yaz = HatirlaticiYaz(id: h.id, baslik: h.baslik, gun: h.gun, saat: h.saat, tekrar: h.tekrar, gunler: h.gunler, onceGun: h.onceGun, acil: h.acil);
      // The server worked out Monday 16 Nov 17:00 Istanbul after Friday 13 Nov's 17:00 was marked done (the fixture was taken
      // right after that), and the phone's own rule gives the same Monday from a moment after that Friday.
      expect(h.sonrakiAn, DateTime.utc(2026, 11, 16, 14));
      expect(yaz.gunler, [HaftaGunu.pzt, HaftaGunu.cum]);
    });
  });

  group('work cards (GET /api/isler)', () {
    test('a card of the list and the card with its history', () {
      final kart = IsKarti.fromJson(liste('isler_liste_dolu').first as Map<String, dynamic>);
      expect(kart.kimlik, 'm3-deneme-karti');
      expect(kart.asama, 'talep');
      expect(kart.sahip, 'vps');
      expect(kart.tip, 'genel');
      expect(kart.gecisler, ['plan', 'iptal']);
      expect(kart.olusma, '2026-11-11T01:03');
      expect(kart.acik, isTrue);

      final ayrinti = IsAyrinti.fromJson(harita('isler_detay'));
      expect(ayrinti.kart.kimlik, 'm3-deneme-karti');
      expect(ayrinti.talep, 'Uyum denemesi için açıldı.');
      expect(ayrinti.sorular, isEmpty);
      expect(ayrinti.gecmis.single.olay, startsWith('oluşturuldu'));
    });

    test('a revision without a note is a 400 whose reason is under the key "not-gerekli"', () {
      expect(oku('isler_asama_plan_bos_not').durum, 400);
      final hatalar = harita('isler_asama_plan_bos_not')['errors'] as Map<String, dynamic>;
      expect(hatalar.keys, ['not-gerekli']);
      expect((hatalar['not-gerekli'] as List).single, 'Revizyon için kısa bir not yaz.');
    });

    test('an answer to a question that is not there is a 404 problem with a sentence', () {
      expect(oku('isler_cevap_soru_yok').durum, 404);
      expect(harita('isler_cevap_soru_yok')['detail'], contains('soru yok'));
    });
  });

  group('how the screens word the real refusals', () {
    DioException hata(String ad) {
      final f = oku(ad);
      final istek = RequestOptions(path: 'x');
      return DioException.badResponse(statusCode: f.durum, requestOptions: istek, response: Response(requestOptions: istek, statusCode: f.durum, data: f.govde));
    }

    test('a revision without a note: the sentence of the rule, as the work card page shows it', () {
      expect(isHataMetni(hata('isler_asama_plan_bos_not')), 'Revizyon için kısa bir not yaz.');
    });

    test('a refusal with a "detail" is shown by it; a field refusal by its sentences', () {
      expect(isHataMetni(hata('isler_cevap_soru_yok')), 'Kartta bu numaralı bir soru yok. Hiçbir şey yazılmadı.');
      expect(isHataMetni(hata('takvim_hata_42')), 'Aralık en çok 42 gün olabilir.');
    });

    test('the other screens\' generic text puts the field sentences first too', () {
      expect(hataMetni(hata('ayarlar_hata')), 'Hafta içi kapasitesi 1 ile 1440 dakika arasında olmalı.');
      expect(hataMetni(hata('bildirimler_hata_limit')), 'Satır sayısı 1 ile 100 arasında olmalı.');
    });
  });
}
