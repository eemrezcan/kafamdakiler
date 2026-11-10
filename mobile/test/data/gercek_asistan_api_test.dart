import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/asistan.dart';
import 'package:kafamdakiler/data/models/brifing.dart';
import 'package:kafamdakiler/routing/router.dart';
import 'package:kafamdakiler/ui/asistan/akis_ogeleri.dart';

/// The models read the answers of the real A3 API (the assistant, K-0024), kept as files in `test/fixtures/api/asistan/`.
/// `akis_*`, `girdi_*_claude_yok`, `girdi_widget`, `girdi_tekrar`, `sayi*` and the error answers were taken from a backend running
/// on this machine, with Claude not connected (an input falls to "saved as a note"), with the trace ids taken out. The ones with
/// a `turetilmis` key (`girdi_siniflandirilmis`, `girdi_soru`, `cevap_sonuc`, `girdi_onayda`) could not be produced without
/// Claude: they were made from the examples in the server's tests (`AsistanGirdiApiTests`), and `girdi_onayda` from the
/// contract (E7; the server does not send `onayda` yet).
void main() {
  ({int durum, dynamic govde}) oku(String ad) {
    final j = jsonDecode(File('test/fixtures/api/asistan/$ad.json').readAsStringSync()) as Map<String, dynamic>;
    return (durum: j['durum'] as int, govde: j['govde']);
  }

  Map<String, dynamic> harita(String ad) => oku(ad).govde as Map<String, dynamic>;

  group('the input (POST /api/asistan/girdi) with Claude not connected', () {
    test('a typed text: one result, a note that can be taken back, with the server\'s reason', () {
      final y = AsistanYaniti.fromJson(harita('girdi_yazi_claude_yok'));

      expect(y.girdiId, '019e3000-0000-7000-8000-0000000000a1');
      expect(y.mesajId, isNotEmpty);
      expect(y.soru, isNull);
      final s = y.sonuclar.single;
      expect(s.tur, sonucTuruNot);
      expect(s.baslik, startsWith('Yarın 9\'da Ali\'yi ara'));
      expect(s.ozet, 'Yakalamaya eklendi');
      expect(s.durum, SonucDurumu.uygulandi);
      expect(s.uygulandi, isTrue);
      expect(s.sorunlu, isFalse);
      expect(s.eylemId, isNull);
      expect(s.hedefKimlik, '01a1c7a0-7f33-72f6-b8db-13dc04afa7e7');
      expect(s.hedefRota, '/asistan');
      expect(s.geriAlinabilir, isTrue);
      expect(s.mesaj, 'Asistan şu an bağlı değil. Mesajın not olarak kaydedildi.');
    });

    test('voice, share and widget inputs answer the same shape', () {
      for (final ad in ['girdi_ses_claude_yok', 'girdi_paylas_claude_yok', 'girdi_widget']) {
        final s = AsistanYaniti.fromJson(harita(ad)).sonuclar.single;
        expect((s.tur, s.durum, s.geriAlinabilir, s.hedefRota), (sonucTuruNot, SonucDurumu.uygulandi, true, '/asistan'), reason: ad);
      }
    });

    test('the same id again is the same answer', () {
      expect(harita('girdi_tekrar'), harita('girdi_yazi_claude_yok'));
    });

    test('what the phone sends is what the server read: the id, the text, the source and the day', () {
      final g = AsistanGirdisi(id: 'x', metin: 'merhaba', kaynak: AsistanKaynagi.ses, bugun: '2026-11-10');
      expect(g.toJson(), {'id': 'x', 'metin': 'merhaba', 'kaynak': 'ses', 'bugun': '2026-11-10'});
    });

    test('the refused inputs are 400 with the field named, which the screen can read', () {
      final bos = oku('girdi_bos_hata');
      expect(bos.durum, 400);
      expect((bos.govde['errors'] as Map)['metin'], isNotEmpty);
      expect(oku('girdi_idsiz_hata').durum, 400);
      expect(oku('cevap_bos_hata').durum, 400);
      expect(oku('cevap_soru_yok').durum, 404);
    });
  });

  group('classified results (made from the server\'s tests)', () {
    test('six kinds at once: kind, summary, flags, action id and where a tap goes', () {
      final y = AsistanYaniti.fromJson(harita('girdi_siniflandirilmis'));

      expect(y.sonuclar.map((s) => s.tur), ['hatirlatici-kur', 'plan-ekle', 'gorev-ekle', 'takvim-ekle', 'not', 'is']);
      expect(y.sonuclar.map((s) => s.ozet), [
        'yarın 09:00 · 🔔',
        'bugün · plana eklendi · ~30 dk',
        'görev · kitap-kulubu · 20 Kas',
        'yarın 14:00 · 📅',
        'Yakalamaya eklendi',
        'İş kartı (kod)',
      ]);
      expect(y.sonuclar.map((s) => s.geriAlinabilir), [true, false, true, true, true, false]);
      expect(y.sonuclar.map((s) => s.eylemId != null), [true, true, true, true, false, false]);
      expect(y.sonuclar.every((s) => s.uygulandi), isTrue);
      expect(y.sonuclar[1].hedefKimlik, 'm:a3f09c');
      expect(y.sonuclar[2].hedefKimlik, 'g:yeni');
      expect(y.sonuclar[5].hedefRota, '/isler/takvim-sayfasi');
      expect(y.sonuclar[0].mesaj, isNull);
    });

    test('a question: nothing applied, one question with its answers', () {
      final y = AsistanYaniti.fromJson(harita('girdi_soru'));

      expect(y.sonuclar, isEmpty);
      expect(y.soru!.metin, 'Bu bir hatırlatıcı mı, plan mı?');
      expect(y.soru!.secenekler, ['Hatırlatıcı', 'Plan', 'Not']);
      expect(y.soru!.id, isNotEmpty);
    });

    test('the answer to the question: the result and no second question', () {
      final y = AsistanYaniti.fromJson(harita('cevap_sonuc'));

      expect(y.soru, isNull);
      expect(y.sonuclar.single.tur, 'hatirlatici-kur');
      expect(y.sonuclar.single.uygulandi, isTrue);
    });

    test('a result that went to approval (E7): not a failure, with its action id', () {
      final s = AsistanYaniti.fromJson(harita('girdi_onayda')).sonuclar.single;

      expect(s.durum, SonucDurumu.onayda);
      expect(s.onayda, isTrue);
      expect(s.uygulandi, isFalse);
      expect(s.sorunlu, isFalse);
      expect(s.eylemId, isNotNull);
      expect(s.geriAlinabilir, isFalse);
      expect(SonucKarti.duzeltRotasi(s), isNull, reason: 'nothing was made yet');
    });
  });

  group('the feed (GET /api/asistan/akis)', () {
    test('every item of a mixed page is read: results, the person\'s messages, notes and the briefing', () {
      final liste = [for (final o in oku('akis_notlarla').govde as List) AkisOgesi.fromJson(o as Map<String, dynamic>)];

      expect(liste, isNotEmpty);
      final turler = liste.map((o) => o.tur).toSet();
      expect(turler, containsAll([AkisTuru.sonuc, AkisTuru.kullanici, AkisTuru.brifing, AkisTuru.not]));
      for (var i = 1; i < liste.length; i++) {
        expect(liste[i - 1].zaman.isBefore(liste[i].zaman), isFalse, reason: 'newest first');
      }

      final sonuc = liste.firstWhere((o) => o.tur == AkisTuru.sonuc);
      expect(sonuc.id, startsWith('sonuc:'));
      expect(sonuc.sonuclar.single.tur, sonucTuruNot);
      expect(sonuc.sonuclar.single.geriAlinabilir, isTrue);
      expect(sonuc.metin, isNull);

      final kullanici = liste.firstWhere((o) => o.tur == AkisTuru.kullanici);
      expect(kullanici.id, startsWith('kullanici:'));
      expect(kullanici.metin, isNotEmpty);
      expect(kullanici.sonuclar, isEmpty);
      expect(kullanici.bekleyenMi, isFalse);

      final not = liste.firstWhere((o) => o.tur == AkisTuru.not);
      expect(not.id, startsWith('not:'));
      expect(not.yakalama!.metin, not.metin);
      expect(not.yakalama!.id, not.id.substring('not:'.length));
    });

    test('the briefing item: day, method, cards and the left refreshes', () {
      final o = (oku('akis_bos').govde as List).map((j) => AkisOgesi.fromJson(j as Map<String, dynamic>)).firstWhere((o) => o.tur == AkisTuru.brifing);

      expect(o.id, startsWith('brifing:'));
      final Brifing b = o.brifing!;
      expect(b.kartlar, isNotEmpty);
      expect(b.kartlar.first.baslik, isNotEmpty);
      expect(b.kalanYenileme, 3);
    });

    test('an empty filter answers an empty list; the badge count is `bekleyen`', () {
      expect(oku('akis_bekleyen').govde, isEmpty);
      expect(oku('akis_isler').govde, isEmpty);
      expect(harita('sayi')['bekleyen'], 0);
      expect(harita('sayi_bos')['bekleyen'], 0);
    });

    test('an unknown filter and a bad limit are 400, which is shown as a failure, not as an empty feed', () {
      expect(oku('akis_suzgec_hata').durum, 400);
      expect(oku('akis_limit_hata').durum, 400);
    });
  });

  group('where an address goes (E8)', () {
    test('/gun/{tarih} names a real day or none', () {
      expect(gunMetnindenTarih('2026-11-11'), DateTime.utc(2026, 11, 11));
      expect(gunMetnindenTarih('2026-02-30'), isNull);
      expect(gunMetnindenTarih('11-11-2026'), isNull);
      expect(gunMetnindenTarih('x'), isNull);
      expect(gunMetnindenTarih(null), isNull);
    });
  });
}
