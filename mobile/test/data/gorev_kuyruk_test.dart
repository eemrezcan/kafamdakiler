import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/repositories/beyin_repository.dart';
import 'package:kafamdakiler/data/repositories/esitleyici.dart';
import 'package:kafamdakiler/data/repositories/gun_plani_repository.dart';
import 'package:kafamdakiler/data/services/api_service.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';

import '../test_destek.dart';
import 'fake_adapter.dart';

// The writes on the brain's tasks (K2.3a): add, finish and split over days. Every write goes to the queue first, the entry id is
// the `Idempotency-Key` of its send, a refusal is kept on the entry with its reason, and an unclear answer (202) or a half-done
// split (207) is never sent again but told (`Esitleyici.uyarilar`, shown in the profile sheet's queue).

void main() {
  group('with the in-memory fake API', () {
    late TestOrtami ortam;

    setUp(() => ortam = TestOrtami());
    tearDown(() async => ortam.kapat());

    test('added, finished and split offline: queued in order and sent later, each with its entry id as the Idempotency-Key', () async {
      ortam.api.cevrimdisi = true;

      await ortam.gunPlani.gorevEkle(baslik: '  Yeni görev ', proje: 'kitap-kulubu', bitis: DateTime.utc(2026, 12, 1));
      await ortam.gunPlani.gorevBitir('uye-girisi');
      await ortam.gunPlani.gunlereBol('uye-girisi', gunSayisi: 3, baslangic: sabitBugun);
      final kuyruk = await ortam.esitleyici.bekleyenler();
      expect(kuyruk.map((b) => b.tur), [BekleyenTur.beyinGorevEkle, BekleyenTur.beyinGorevBitir, BekleyenTur.beyinGunlereBol]);

      ortam.api.cevrimdisi = false;
      expect(await ortam.esitleyici.gonder(), 3);

      expect(ortam.api.beyinYazimlari.map((y) => y.yol), [
        '/api/beyin/gorevler',
        '/api/beyin/gorevler/uye-girisi/bitir',
        '/api/beyin/gorevler/uye-girisi/gunlere-bol',
      ]);
      expect(ortam.api.beyinYazimlari[0].govde, {'baslik': 'Yeni görev', 'proje': 'kitap-kulubu', 'bitis': '2026-12-01'});
      expect(ortam.api.beyinYazimlari[2].govde, {'gunSayisi': 3, 'baslangic': '2026-10-31'});
      expect(ortam.api.beyinYazimlari.map((y) => y.anahtar), kuyruk.map((b) => b.id));
    });

    test('a refusal (404, 409) is kept on the entry with the server\'s sentence and does not block the next one', () async {
      await ortam.gunPlani.gorevBitir('yok-boyle-gorev');
      await ortam.gunPlani.gorevEkle(baslik: 'İkinci', proje: 'kitap-kulubu');
      ortam.api.beyinYazmaKodlari = [404, 200];
      ortam.api.beyinYazmaProblemi = {'title': 'Bulunamadı', 'detail': 'İstenen görev bulunamadı. Hiçbir şey yazılmadı.'};

      expect(await ortam.esitleyici.gonder(), 1);

      expect(await ortam.esitleyici.bekleyenler(), isEmpty);
      final reddedilen = (await ortam.esitleyici.reddedilenler()).single;
      expect(reddedilen.hedefId, 'yok-boyle-gorev');
      expect(reddedilen.hata, 'İstenen görev bulunamadı. Hiçbir şey yazılmadı.');
      expect(ortam.esitleyici.gonderimSayisi, 1);
    });

    test('202: sent once, never again; the entry is kept as a note that the write may have happened', () async {
      await ortam.gunPlani.gorevEkle(baslik: 'Belirsiz görev', proje: 'kitap-kulubu');
      ortam.api.beyinYazmaKodlari = [202];
      ortam.api.beyinYazmaGovdesi = {'belirsiz': true, 'yazilmisOlabilir': true, 'ayrinti': 'Beyin zamanında cevap vermedi; yazılmış olabilir.'};

      expect(await ortam.esitleyici.gonder(), 1);
      expect(await ortam.esitleyici.gonder(), 0);

      expect(ortam.api.beyinYazimlari, hasLength(1));
      final uyari = (await ortam.esitleyici.uyarilar()).single;
      expect(uyari.uyari, contains('yazılmış olabilir'));
      expect(uyari.hedefId, isNotEmpty);
    });

    test('207: the days written and the day that stopped the split are in the note', () async {
      await ortam.gunPlani.gunlereBol('uye-girisi', gunSayisi: 4, baslangic: sabitBugun);
      ortam.api.beyinYazmaKodlari = [207];
      ortam.api.beyinYazmaGovdesi = {
        'gorev': 'uye-girisi',
        'tamamlandi': false,
        'yazilanlar': [
          {'tarih': '2026-10-31', 'madde': {'id': 'aaaaa1'}},
        ],
        'hata': {'tarih': '2026-11-01', 'durum': 409, 'baslik': 'Gün kapandı', 'ayrinti': 'Kapanmış güne yazılmaz.', 'yazilmisOlabilir': false},
      };

      await ortam.esitleyici.gonder();

      final metin = (await ortam.esitleyici.uyarilar()).single.uyari!;
      expect(metin, contains('2026-10-31'));
      expect(metin, contains('2026-11-01'));
      expect(metin, contains('Kapanmış güne yazılmaz.'));
      expect(metin, contains('yarıda kaldı'));
    });

    test('a 5xx keeps the entry queued, and a note can be dismissed', () async {
      await ortam.gunPlani.gorevBitir('uye-girisi');
      ortam.api.beyinYazmaKodlari = [503];

      expect(await ortam.esitleyici.gonder(), 0);
      expect(await ortam.esitleyici.bekleyenler(), hasLength(1));
      expect(await ortam.esitleyici.uyarilar(), isEmpty);

      ortam.api.beyinYazmaKodlari = [202];
      ortam.api.beyinYazmaGovdesi = {'belirsiz': true, 'ayrinti': 'Yazılmış olabilir.'};
      await ortam.esitleyici.gonder();
      final uyari = (await ortam.esitleyici.uyarilar()).single;
      await ortam.esitleyici.sil(uyari.id);
      expect(await ortam.esitleyici.uyarilar(), isEmpty);
    });

    test('signing out drops the queued task writes', () async {
      await ortam.gunPlani.gorevBitir('uye-girisi');

      await ortam.db.hepsiniTemizle();

      expect(await ortam.esitleyici.bekleyenler(reddedilenler: true), isEmpty);
    });

    test('the projects the phone knows come from its list', () async {
      expect(await ortam.gunPlani.projeler(), isEmpty);
    });
  });

  group('with a fake HTTP server', () {
    late AppDatabase db;
    late FakeAdapter adapter;
    late Esitleyici esitleyici;
    late GunPlaniRepository repo;
    var an = DateTime.utc(2026, 10, 31, 9);

    void kur(ResponseBody Function(RequestOptions) yanitla) {
      adapter = FakeAdapter(yanitla);
      final api = ApiService(Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter);
      esitleyici = Esitleyici(api: api, db: db, simdi: () => an = an.add(const Duration(seconds: 1)));
      repo = GunPlaniRepository(beyin: BeyinRepository(api: api, db: db), esitleyici: esitleyici, simdi: () => sabitAn);
    }

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() async => db.close());

    test('every kind goes to its path with the Idempotency-Key header and the body of the API', () async {
      kur((istek) => jsonYanit(200, {'kimlik': 'x'}));
      await repo.gorevEkle(baslik: 'G', proje: 'p');
      await repo.gorevBitir('g 1');
      await repo.gunlereBol('g1', gunSayisi: 2);
      final idler = [for (final b in await esitleyici.bekleyenler()) b.id];

      expect(await esitleyici.gonder(), 3);

      expect(adapter.istekler.map((i) => '${i.method} ${i.path}'), [
        'POST /api/beyin/gorevler',
        'POST /api/beyin/gorevler/g%201/bitir',
        'POST /api/beyin/gorevler/g1/gunlere-bol',
      ]);
      expect(adapter.istekler.map((i) => i.headers['Idempotency-Key']), idler);
      expect((adapter.istekler[1].data as Map), isEmpty, reason: 'no proof travels from the phone: the server adds the app\'s own');
      expect((adapter.istekler[2].data as Map), {'gunSayisi': 2});
    });

    test('a failed send is repeated with the same key; "being processed" (409) waits instead of being refused', () async {
      var kac = 0;
      kur((istek) {
        kac++;
        if (kac == 1) return jsonYanit(503, {'title': 'Beyin bağlı değil'});
        if (kac == 2) return jsonYanit(409, {'title': 'İstek işleniyor', 'detail': 'Aynı anahtarla gelen ilk istek hâlâ sürüyor; biraz sonra tekrar dene.'});
        return jsonYanit(200, {'kimlik': 'x'});
      });
      await repo.gorevEkle(baslik: 'Yeni', proje: 'p');
      final id = (await esitleyici.bekleyenler()).single.id;

      expect(await esitleyici.gonder(), 0, reason: '503: stay queued');
      expect(await esitleyici.gonder(), 0, reason: '409 "İstek işleniyor": the first send is still running, try again later');
      expect(await esitleyici.reddedilenler(), isEmpty);
      expect(await esitleyici.gonder(), 1);

      expect(adapter.istekler, hasLength(3));
      expect(adapter.istekler.map((i) => i.headers['Idempotency-Key']), [id, id, id], reason: 'the same key every time');
    });

    test('202 and 207 are read from the status; a plain 200 has no note', () async {
      final yanitlar = [
        (200, {'kimlik': 'x'}),
        (202, {'belirsiz': true, 'ayrinti': 'Yazılmış olabilir.'}),
        (207, {'yazilanlar': <Object>[], 'hata': {'tarih': '2026-11-01', 'ayrinti': 'Kapandı', 'yazilmisOlabilir': true}}),
      ];
      var i = 0;
      kur((istek) {
        final (kod, govde) = yanitlar[i++];
        return jsonYanit(kod, govde);
      });
      await repo.gorevEkle(baslik: 'Bir', proje: 'p');
      await repo.gorevEkle(baslik: 'İki', proje: 'p');
      await repo.gunlereBol('g1', gunSayisi: 2);

      expect(await esitleyici.gonder(), 3);

      final uyarilar = await esitleyici.uyarilar();
      expect(uyarilar, hasLength(2));
      expect(uyarilar[0].uyari, 'Yazılmış olabilir.');
      expect(uyarilar[1].uyari, contains('yarıda kaldı'));
      expect(uyarilar[1].uyari, contains('yazılmış olabilir, planı kontrol et'));
    });
  });
}
