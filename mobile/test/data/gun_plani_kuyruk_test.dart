import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/beyin.dart';
import 'package:kafamdakiler/data/repositories/bekleyen_uygula.dart';
import 'package:kafamdakiler/data/repositories/esitleyici.dart';
import 'package:kafamdakiler/data/repositories/gun_plani_repository.dart';
import 'package:kafamdakiler/data/repositories/beyin_repository.dart';
import 'package:kafamdakiler/data/services/api_service.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';

import '../test_destek.dart';
import 'fake_adapter.dart';

// The day plan and task writes (K2.3a) on the phone: every write goes to the queue first, the plan shows it at once (also
// offline), the entry id is the Idempotency-Key of its send, a refusal takes the write back off the screen and says why, and an
// unclear answer (202) or a half-done split (207) is never sent again but told.

BeyinGunMaddesi _madde(String id, String baslik, {String durum = 'acik', int? tahminDk, String? gorev}) =>
    BeyinGunMaddesi(id: id, baslik: baslik, durum: durum, tahminDk: tahminDk, gorev: gorev);

BeyinGun _plan(
  DateTime tarih,
  List<BeyinGunMaddesi> maddeler, {
  List<GecikenGorev> geciken = const [],
  bool kapandi = false,
  GunKapasiteUyarisi? uyari,
}) =>
    BeyinGun(
      tarih: tarih,
      planVar: true,
      kapandi: kapandi,
      bolumler: [BeyinGunBolumu(ad: 'Yapılacaklar', maddeler: maddeler)],
      geciken: geciken,
      toplam: BeyinGunToplami(madde: maddeler.length, yapildi: maddeler.where((m) => m.yapildi).length),
      kapasiteUyarisi: uyari,
    );

final _dun = DateTime.utc(2026, 10, 30);

void main() {
  group('with the in-memory fake API', () {
    late TestOrtami ortam;

    setUp(() => ortam = TestOrtami());
    tearDown(() async => ortam.kapat());

    Future<BeyinGun> bugunPlani() async => (await ortam.gunPlani.oku(sabitBugun)).gun;

    Future<void> planiHazirla(List<BeyinGunMaddesi> maddeler, {List<GecikenGorev> geciken = const [], GunKapasiteUyarisi? uyari}) async {
      ortam.api.gunPlanlari = {'2026-10-31': _plan(sabitBugun, maddeler, geciken: geciken, uyari: uyari)};
      await bugunPlani(); // reads the day: the phone keeps it
    }

    test('added offline: shown at once as a phone-only line, sent later with the entry id as the Idempotency-Key', () async {
      await planiHazirla([_madde('a3f09c', 'Takvim')]);
      ortam.api.cevrimdisi = true;

      await ortam.gunPlani.maddeEkle(sabitBugun, 'Fatura kontrol ~45dk', bolum: 'Okul');

      final gun = (await ortam.gunPlani.yerel(sabitBugun))!;
      final yeni = gun.maddeler.singleWhere((m) => m.yerel);
      expect(yeni.baslik, 'Fatura kontrol', reason: 'the estimate tag is taken out of the text, as the brain does');
      expect(yeni.tahminDk, 45);
      expect(gun.bolumler.map((b) => b.ad), ['Yapılacaklar', 'Okul']);
      expect(gun.toplam!.madde, 2);

      expect(await ortam.esitleyici.gonder(), 0);
      expect(ortam.api.beyinYazimlari, isEmpty);

      ortam.api.cevrimdisi = false;
      expect(await ortam.esitleyici.gonder(), 1);
      final gonderilen = ortam.api.beyinYazimlari.single;
      expect(gonderilen.yol, '/api/beyin/gunler/2026-10-31/maddeler');
      expect(gonderilen.govde, {'metin': 'Fatura kontrol ~45dk', 'bolum': 'Okul'});
      expect(gonderilen.anahtar, isNotEmpty);
    });

    test('the Idempotency-Key is the queue entry id: unique per write, the same on a repeated send', () async {
      await planiHazirla([_madde('a3f09c', 'Takvim'), _madde('b4e1d2', 'Kitap')]);
      await ortam.gunPlani.isaretle(sabitBugun, _madde('a3f09c', 'Takvim'));
      await ortam.gunPlani.isaretle(sabitBugun, _madde('b4e1d2', 'Kitap'));
      final idler = [for (final b in await ortam.esitleyici.bekleyenler()) b.id];

      await ortam.esitleyici.gonder();

      expect(ortam.api.beyinYazimlari.map((y) => y.anahtar), idler);
      expect(idler.toSet(), hasLength(2));
    });

    test('tick and undo are laid over the cached plan in queue order; a tick on a linked item takes the task off the overdue list', () async {
      await planiHazirla(
        [_madde('a3f09c', 'Takvim', tahminDk: 30), _madde('b4e1d2', 'Üye girişi', gorev: 'uye-girisi'), _madde('c5d2e3', 'Kitap')],
        geciken: const [GecikenGorev(kimlik: 'uye-girisi', baslik: 'Üye girişi'), GecikenGorev(kimlik: 'diger', baslik: 'Başka')],
      );
      ortam.api.cevrimdisi = true;

      await ortam.gunPlani.isaretle(sabitBugun, _madde('a3f09c', 'Takvim'));
      await ortam.gunPlani.isaretle(sabitBugun, _madde('b4e1d2', 'Üye girişi', gorev: 'uye-girisi'));
      await ortam.gunPlani.isaretle(sabitBugun, _madde('c5d2e3', 'Kitap'));
      await ortam.gunPlani.isaretle(sabitBugun, _madde('c5d2e3', 'Kitap', durum: 'yapildi')); // undo

      final gun = (await ortam.gunPlani.yerel(sabitBugun))!;
      final durumlar = {for (final m in gun.maddeler) m.id: m.durum};
      expect(durumlar, {'a3f09c': 'yapildi', 'b4e1d2': 'yapildi', 'c5d2e3': 'acik'});
      expect(gun.geciken.map((g) => g.kimlik), ['diger']);
      expect(gun.toplam!.yapildi, 2);
      expect(gun.toplam!.acik, 1);
    });

    test('a carry-over marks the item on its day and shows it on the next day, once', () async {
      ortam.api.gunPlanlari = {
        '2026-10-31': _plan(sabitBugun, [_madde('a3f09c', 'Takvim', tahminDk: 90)]),
        '2026-11-01': _plan(sabitBugun.add(const Duration(days: 1)), [_madde('d6e3f4', 'Yarının işi')]),
      };
      await ortam.gunPlani.oku(sabitBugun);
      await ortam.gunPlani.oku(sabitBugun.add(const Duration(days: 1)));
      ortam.api.cevrimdisi = true;

      await ortam.gunPlani.devret(sabitBugun, _madde('a3f09c', 'Takvim', tahminDk: 90), bolum: 'Yapılacaklar');

      final bugun = (await ortam.gunPlani.yerel(sabitBugun))!;
      expect(bugun.maddeler.single.durum, 'devredildi');
      final yarin = (await ortam.gunPlani.yerel(sabitBugun.add(const Duration(days: 1))))!;
      expect(yarin.maddeler.map((m) => m.baslik), ['Yarının işi', 'Takvim']);
      expect(yarin.maddeler.last.tahminDk, 90);
      expect(yarin.maddeler.last.yerel, isTrue);

      // The same carry-over queued twice does not show the item twice (the brain skips a repeat too).
      await ortam.gunPlani.devret(sabitBugun, _madde('a3f09c', 'Takvim', tahminDk: 90), bolum: 'Yapılacaklar');
      final yineYarin = (await ortam.gunPlani.yerel(sabitBugun.add(const Duration(days: 1))))!;
      expect(yineYarin.maddeler.where((m) => m.baslik == 'Takvim'), hasLength(1));
    });

    test('a finished task leaves the overdue list and finishes the plan lines linked to it', () async {
      await planiHazirla(
        [_madde('a3f09c', 'Bağlı', gorev: 'g1')],
        geciken: const [GecikenGorev(kimlik: 'g1', baslik: 'Görev'), GecikenGorev(kimlik: 'g2', baslik: 'Diğer')],
      );
      ortam.api.cevrimdisi = true;

      await ortam.gunPlani.gorevBitir('g1');

      final gun = (await ortam.gunPlani.yerel(sabitBugun))!;
      expect(gun.geciken.map((g) => g.kimlik), ['g2']);
      expect(gun.maddeler.single.durum, 'yapildi');
    });

    test('a note, a new task and a split show nothing on the plan but are queued and sent', () async {
      await planiHazirla([_madde('a3f09c', 'Takvim')]);
      final onceki = (await ortam.gunPlani.yerel(sabitBugun))!;

      await ortam.gunPlani.notEkle(sabitBugun, _madde('a3f09c', 'Takvim'), '-ilk not');
      await ortam.gunPlani.gorevEkle(baslik: 'Yeni görev', proje: 'kitap-kulubu', bitis: DateTime.utc(2026, 12, 1));
      await ortam.gunPlani.gunlereBol('uye-girisi', gunSayisi: 3, baslangic: sabitBugun);

      final sonraki = (await ortam.gunPlani.yerel(sabitBugun))!;
      expect(sonraki.toJson(), onceki.toJson());
      expect(await ortam.esitleyici.gonder(), 3);
      expect(ortam.api.beyinYazimlari.map((y) => y.yol), [
        '/api/beyin/gunler/2026-10-31/not',
        '/api/beyin/gorevler',
        '/api/beyin/gorevler/uye-girisi/gunlere-bol',
      ]);
      expect(ortam.api.beyinYazimlari[0].govde, {'madde': 'a3f09c', 'metin': '-ilk not'});
      expect(ortam.api.beyinYazimlari[1].govde, {'baslik': 'Yeni görev', 'proje': 'kitap-kulubu', 'bitis': '2026-12-01'});
      expect(ortam.api.beyinYazimlari[2].govde, {'gunSayisi': 3, 'baslangic': '2026-10-31'});
    });

    test('offline the cached day is shown and says so; a day never read cannot be shown', () async {
      await planiHazirla([_madde('a3f09c', 'Takvim')]);
      ortam.api.cevrimdisi = true;

      final sonuc = await ortam.gunPlani.oku(sabitBugun);
      expect(sonuc.cevrimdisi, isTrue);
      expect(sonuc.gun.maddeler.single.baslik, 'Takvim');
      await expectLater(ortam.gunPlani.oku(sabitBugun.add(const Duration(days: 3))), throwsA(isA<DioException>()));
    });

    test('a server answer such as 503 is thrown, not hidden behind the cache', () async {
      await planiHazirla([_madde('a3f09c', 'Takvim')]);
      ortam.api.beyinHatasi = 503;

      await expectLater(ortam.gunPlani.oku(sabitBugun), throwsA(isA<DioException>()));
    });

    test('the warning "does not fit" comes from the server and is kept or dropped as the open estimates change', () async {
      const uyari = GunKapasiteUyarisi(acikTahminDk: 400, kapasiteDk: 360, asimDk: 40);
      await planiHazirla([_madde('a3f09c', 'Büyük', tahminDk: 250), _madde('b4e1d2', 'Orta', tahminDk: 150)], uyari: uyari);
      ortam.api.cevrimdisi = true;
      expect((await ortam.gunPlani.yerel(sabitBugun))!.kapasiteUyarisi!.asimDk, 40);

      await ortam.gunPlani.isaretle(sabitBugun, _madde('b4e1d2', 'Orta', tahminDk: 150));
      expect((await ortam.gunPlani.yerel(sabitBugun))!.kapasiteUyarisi, isNull, reason: '250 min left, it fits now');

      await ortam.gunPlani.isaretle(sabitBugun, _madde('b4e1d2', 'Orta', durum: 'yapildi', tahminDk: 150)); // undo
      await ortam.gunPlani.maddeEkle(sabitBugun, 'Bir şey ~1s');
      final gun = (await ortam.gunPlani.yerel(sabitBugun))!;
      expect(gun.kapasiteUyarisi!.acikTahminDk, 460);
      expect(gun.kapasiteUyarisi!.asimDk, 100);
    });

    test('a day the server sent without a warning gets none from the phone', () async {
      await planiHazirla([_madde('a3f09c', 'Takvim', tahminDk: 30)]);
      ortam.api.cevrimdisi = true;

      await ortam.gunPlani.maddeEkle(sabitBugun, 'Dev iş ~9s');

      expect((await ortam.gunPlani.yerel(sabitBugun))!.kapasiteUyarisi, isNull, reason: 'the capacity is a server setting the phone does not know');
    });

    test('a phone-only line cannot be ticked, carried or noted until it has an id', () async {
      await planiHazirla([_madde('a3f09c', 'Takvim')]);
      ortam.api.cevrimdisi = true;
      await ortam.gunPlani.maddeEkle(sabitBugun, 'Yeni');
      final yerel = (await ortam.gunPlani.yerel(sabitBugun))!.maddeler.singleWhere((m) => m.yerel);

      expect(yerel.id, startsWith('yerel:'));
      expect(yerel.acik, isTrue);
      // The view model refuses these (see the widget test): the API takes only the brain's permanent id.
      expect(yerel.kalici, isFalse);
      expect(_madde('a3f09c', 'x').kalici, isTrue);
      expect(_madde('g:uye-girisi', 'x').kalici, isTrue);
      for (final kotu in ['123456', 'a1', 'A3F09C', 'a3f09c1', 'teklif', '']) {
        expect(_madde(kotu, 'x').kalici, isFalse, reason: kotu);
      }
    });

    group('refused and unclear answers', () {
      test('a 409 (closed day) takes the write off the screen and says why; dismissing removes the message', () async {
        await planiHazirla([_madde('a3f09c', 'Takvim')]);
        await ortam.gunPlani.isaretle(sabitBugun, _madde('a3f09c', 'Takvim'));
        expect((await ortam.gunPlani.yerel(sabitBugun))!.maddeler.single.durum, 'yapildi');
        ortam.api.beyinYazmaKodlari = [409];
        ortam.api.beyinYazmaProblemi = {'title': 'Gün kapandı', 'detail': 'Kapanmış güne yazılmaz.'};

        await ortam.esitleyici.gonder();

        expect((await ortam.gunPlani.yerel(sabitBugun))!.maddeler.single.durum, 'acik', reason: 'back to what the brain has');
        final bildirimler = await ortam.gunPlani.bildirimler();
        expect(bildirimler.single.reddedildi, isTrue);
        expect(bildirimler.single.metin, contains('geri alındı'));
        expect(bildirimler.single.metin, contains('Kapanmış güne yazılmaz.'));
        expect(bildirimler.single.metin, isNot(contains('{')), reason: 'the reason, not the raw body');

        await ortam.gunPlani.bildirimiKapat(bildirimler.single.id);
        expect(await ortam.gunPlani.bildirimler(), isEmpty);
      });

      test('a refused write does not block the next entry', () async {
        await planiHazirla([_madde('a3f09c', 'Takvim'), _madde('b4e1d2', 'Kitap')]);
        await ortam.gunPlani.isaretle(sabitBugun, _madde('a3f09c', 'Takvim'));
        await ortam.gunPlani.isaretle(sabitBugun, _madde('b4e1d2', 'Kitap'));
        ortam.api.beyinYazmaKodlari = [404, 200];

        expect(await ortam.esitleyici.gonder(), 1);

        // Both went out: the second was sent in spite of the first being refused. The refused one is kept with its reason.
        expect(ortam.api.beyinYazimlari.map((y) => y.govde['madde']), ['a3f09c', 'b4e1d2']);
        expect(await ortam.esitleyici.bekleyenler(), isEmpty);
        expect((await ortam.esitleyici.reddedilenler()).map((r) => r.hedefId), ['a3f09c']);
        // The sent tick is in the brain now; the screen learns it from the next read (the sender moves the counter for that).
        expect(ortam.esitleyici.gonderimSayisi, 1);
      });

      test('202: sent once, never again; the user is told it may have been written', () async {
        await planiHazirla([_madde('a3f09c', 'Takvim')]);
        await ortam.gunPlani.maddeEkle(sabitBugun, 'Belirsiz iş');
        ortam.api.beyinYazmaKodlari = [202];
        ortam.api.beyinYazmaGovdesi = {'belirsiz': true, 'yazilmisOlabilir': true, 'baslik': 'Sonuç belli değil', 'ayrinti': 'Beyin zamanında cevap vermedi; yazılmış olabilir.'};

        expect(await ortam.esitleyici.gonder(), 1);
        expect(await ortam.esitleyici.gonder(), 0);

        expect(ortam.api.beyinYazimlari, hasLength(1));
        expect(await ortam.esitleyici.bekleyenler(), isEmpty);
        final bildirim = (await ortam.gunPlani.bildirimler()).single;
        expect(bildirim.reddedildi, isFalse);
        expect(bildirim.metin, contains('yazılmış olabilir'));
        expect(bildirim.metin, contains('Belirsiz iş'));
        // The line is no longer a phone-only line on the plan: the entry is sent, the next read of the day decides.
        expect((await ortam.gunPlani.yerel(sabitBugun))!.maddeler.where((m) => m.yerel), isEmpty);
      });

      test('207: the days written and the day that stopped the split are in the message', () async {
        await planiHazirla([_madde('a3f09c', 'Takvim')]);
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

        final metin = (await ortam.gunPlani.bildirimler()).single.metin;
        expect(metin, contains('2026-10-31'));
        expect(metin, contains('2026-11-01'));
        expect(metin, contains('Kapanmış güne yazılmaz.'));
        expect(metin, contains('yarıda kaldı'));
      });

      test('a 5xx or a lost connection keeps the entry queued and the write on the screen', () async {
        await planiHazirla([_madde('a3f09c', 'Takvim')]);
        await ortam.gunPlani.isaretle(sabitBugun, _madde('a3f09c', 'Takvim'));
        ortam.api.beyinYazmaKodlari = [503];

        expect(await ortam.esitleyici.gonder(), 0);

        expect(await ortam.esitleyici.bekleyenler(), hasLength(1));
        expect((await ortam.gunPlani.yerel(sabitBugun))!.maddeler.single.durum, 'yapildi');
        expect(await ortam.gunPlani.bildirimler(), isEmpty, reason: 'not refused for good, only waiting');
      });
    });

    group('the morning card', () {
      Future<void> dunuHazirla({bool kapandi = false}) async {
        ortam.api.gunPlanlari = {
          '2026-10-30': _plan(
            _dun,
            [
              _madde('a3f09c', 'Dünden kalan'),
              _madde('b4e1d2', 'Yapılmış', durum: 'yapildi'),
              _madde('c5d2e3', 'Devredilmiş', durum: 'devredildi'),
            ],
            kapandi: kapandi,
          ),
        };
      }

      test('lists what yesterday left open, with its section', () async {
        await dunuHazirla();

        final sabah = await ortam.gunPlani.sabah();

        expect(sabah.map((s) => s.madde.baslik), ['Dünden kalan']);
        expect(sabah.single.bolum, 'Yapılacaklar');
        expect(ortam.api.cagrilar.where((c) => c == 'beyinGun'), hasLength(1));
      });

      test('a day the brain closed offers nothing', () async {
        await dunuHazirla(kapandi: true);

        expect(await ortam.gunPlani.sabah(), isEmpty);
      });

      test('"Taşı" queues a carry-over dated yesterday and the item leaves the card at once', () async {
        await dunuHazirla();
        final sabah = (await ortam.gunPlani.sabah()).single;
        ortam.api.cevrimdisi = true;

        await ortam.gunPlani.sabahTasi(sabah);

        expect(await ortam.gunPlani.sabah(oku: false), isEmpty);
        ortam.api.cevrimdisi = false;
        await ortam.esitleyici.gonder();
        final yazim = ortam.api.beyinYazimlari.single;
        expect(yazim.yol, '/api/beyin/gunler/2026-10-30/devret');
        expect(yazim.govde, {'madde': 'a3f09c'});
      });

      test('"Bırak" writes nothing to the brain and the item stays off the card', () async {
        await dunuHazirla();
        final sabah = (await ortam.gunPlani.sabah()).single;

        await ortam.gunPlani.sabahBirak(sabah);

        expect(await ortam.gunPlani.sabah(), isEmpty);
        expect(await ortam.esitleyici.bekleyenler(reddedilenler: true), isEmpty);
        expect(ortam.api.beyinYazimlari, isEmpty);
      });

      test('an item added on the phone to yesterday and not sent yet is not offered', () async {
        await dunuHazirla();
        await ortam.gunPlani.oku(_dun);
        ortam.api.cevrimdisi = true;
        await ortam.gunPlani.maddeEkle(_dun, 'Geç kalan ekleme');

        final sabah = await ortam.gunPlani.sabah();

        expect(sabah.map((s) => s.madde.baslik), ['Dünden kalan']);
      });

      test('offline it works from the cached yesterday', () async {
        await dunuHazirla();
        await ortam.gunPlani.sabah();
        ortam.api.cevrimdisi = true;

        expect((await ortam.gunPlani.sabah()).map((s) => s.madde.baslik), ['Dünden kalan']);
      });
    });

    test('signing out drops the cached days, the let-go list and the queued plan writes', () async {
      await planiHazirla([_madde('a3f09c', 'Takvim')]);
      await ortam.gunPlani.isaretle(sabitBugun, _madde('a3f09c', 'Takvim'));

      await ortam.db.hepsiniTemizle();

      expect(await ortam.gunPlani.yerel(sabitBugun), isNull);
      expect(await ortam.esitleyici.bekleyenler(reddedilenler: true), isEmpty);
    });
  });

  group('the estimate tag', () {
    test('is read and taken out of the text, like the brain does', () {
      expect(tahminAyir('Teklif ~1s30dk hazırla'), ('Teklif hazırla', 90));
      expect(tahminAyir('Kitap ~30dk'), ('Kitap', 30));
      expect(tahminAyir('Spor ~1,5s'), ('Spor', 90));
      expect(tahminAyir('Etiketsiz iş'), ('Etiketsiz iş', null));
      expect(tahminAyir('  Boşluklu  '), ('Boşluklu', null));
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
      repo = GunPlaniRepository(beyin: BeyinRepository(api: api, db: db), db: db, esitleyici: esitleyici, simdi: () => sabitAn);
    }

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() async => db.close());

    test('every kind goes to its path with the Idempotency-Key header and the body of the API', () async {
      kur((istek) => jsonYanit(200, {'tarih': '2026-10-31'}));
      await repo.maddeEkle(sabitBugun, 'Yeni iş');
      await repo.isaretle(sabitBugun, _madde('a3f09c', 'A'));
      await repo.isaretle(sabitBugun, _madde('b4e1d2', 'B', durum: 'yapildi'));
      await repo.devret(sabitBugun, _madde('a3f09c', 'A'));
      await repo.notEkle(sabitBugun, _madde('a3f09c', 'A'), 'not');
      await repo.gorevEkle(baslik: 'G', proje: 'p');
      await repo.gorevBitir('g 1');
      await repo.gunlereBol('g1', gunSayisi: 2);
      final idler = [for (final b in await esitleyici.bekleyenler()) b.id];

      expect(await esitleyici.gonder(), 8);

      expect(adapter.istekler.map((i) => '${i.method} ${i.path}'), [
        'POST /api/beyin/gunler/2026-10-31/maddeler',
        'POST /api/beyin/gunler/2026-10-31/isaretle',
        'POST /api/beyin/gunler/2026-10-31/isaretle',
        'POST /api/beyin/gunler/2026-10-31/devret',
        'POST /api/beyin/gunler/2026-10-31/not',
        'POST /api/beyin/gorevler',
        'POST /api/beyin/gorevler/g%201/bitir',
        'POST /api/beyin/gorevler/g1/gunlere-bol',
      ]);
      expect(adapter.istekler.map((i) => i.headers['Idempotency-Key']), idler);
      expect((adapter.istekler[1].data as Map), {'madde': 'a3f09c', 'geri': false});
      expect((adapter.istekler[2].data as Map), {'madde': 'b4e1d2', 'geri': true});
      expect((adapter.istekler[6].data as Map), isEmpty, reason: 'no proof travels from the phone: the server adds the app\'s own');
      expect((adapter.istekler[7].data as Map), {'gunSayisi': 2});
    });

    test('a failed send is repeated with the same key; "being processed" (409) waits instead of being refused', () async {
      var kac = 0;
      kur((istek) {
        kac++;
        if (kac == 1) return jsonYanit(503, {'title': 'Beyin bağlı değil'});
        if (kac == 2) return jsonYanit(409, {'title': 'İstek işleniyor', 'detail': 'Aynı anahtarla gelen ilk istek hâlâ sürüyor; biraz sonra tekrar dene.'});
        return jsonYanit(200, {'tarih': '2026-10-31'});
      });
      await repo.maddeEkle(sabitBugun, 'Yeni iş');
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
        (200, {'tarih': '2026-10-31'}),
        (202, {'belirsiz': true, 'ayrinti': 'Yazılmış olabilir.'}),
        (207, {'yazilanlar': <Object>[], 'hata': {'tarih': '2026-11-01', 'ayrinti': 'Kapandı', 'yazilmisOlabilir': true}}),
      ];
      var i = 0;
      kur((istek) {
        final (kod, govde) = yanitlar[i++];
        return jsonYanit(kod, govde);
      });
      await repo.maddeEkle(sabitBugun, 'Bir');
      await repo.maddeEkle(sabitBugun, 'İki');
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
