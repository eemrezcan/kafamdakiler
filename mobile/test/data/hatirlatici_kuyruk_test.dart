import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/hatirlatici.dart';
import 'package:kafamdakiler/data/repositories/esitleyici.dart';
import 'package:kafamdakiler/data/repositories/hatirlatici_repository.dart';
import 'package:kafamdakiler/data/services/api_service.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';

import '../test_destek.dart';
import 'fake_adapter.dart';

// The offline write queue of reminders (the Yakala pattern): every write goes to the phone first, the list shows it
// at once, and the entries go to the server in order when the connection is back.

Map<String, dynamic> _sunucuHatirlatici(String id, {String baslik = 'sunucudaki', String durum = 'acik'}) => {
      'id': id,
      'baslik': baslik,
      'tur': 'gorev',
      'gun': '2026-11-10',
      'tekrar': 'yok',
      'onceGun': 0,
      'durum': durum,
      'sonrakiAn': '2026-11-10T06:00:00Z',
      'etkinAn': '2026-11-10T06:00:00Z',
      'kalanGun': 10,
      'createdAt': '2026-11-01T10:00:00Z',
    };

HatirlaticiYaz _yaz(String baslik, {Tekrar tekrar = Tekrar.yok}) =>
    HatirlaticiYaz(baslik: baslik, gun: DateTime.utc(2026, 11, 10), tekrar: tekrar);

void main() {
  group('with the in-memory fake API', () {
    late TestOrtami ortam;

    setUp(() => ortam = TestOrtami());
    tearDown(() async => ortam.kapat());

    test('added offline: shown at once with its computed moment, sent when the connection is back', () async {
      ortam.api.cevrimdisi = true;
      final id = await ortam.hatirlaticilar.ekle(_yaz('Faturayı öde'));

      final liste = (await ortam.hatirlaticilar.listele()).liste;
      expect(liste.single.id, id);
      expect(liste.single.baslik, 'Faturayı öde');
      expect(liste.single.sonrakiAn, DateTime.utc(2026, 11, 10, 6), reason: '09:00 Istanbul, computed on the phone');
      expect(id[14], '7', reason: 'Guid v7');

      expect(await ortam.esitleyici.gonder(), 0);
      expect(await ortam.esitleyici.bekleyenler(), hasLength(1));

      ortam.api.cevrimdisi = false;
      expect(await ortam.esitleyici.gonder(), 1);
      expect(ortam.api.cagrilar, contains('hatirlaticiOlustur'));
      expect(await ortam.esitleyici.bekleyenler(), isEmpty);
    });

    test('edit, Yaptım and Ertele work offline and are laid over the server copy in queue order', () async {
      ortam.api
        ..hatirlaticilar = [
          ornekHatirlatici(id: 'g', baslik: 'Günlük', tekrar: Tekrar.gunluk, gun: DateTime.utc(2026, 10, 1), sonrakiAn: DateTime.utc(2026, 11, 1, 6)),
          ornekHatirlatici(id: 'b', baslik: 'Bir kez'),
          ornekHatirlatici(id: 'e', baslik: 'Eski adı'),
        ]
        ..cevrimdisi = false;
      await ortam.hatirlaticilar.listele(); // fills the cache
      ortam.api.cevrimdisi = true;

      await ortam.hatirlaticilar.yaptim('g');
      await ortam.hatirlaticilar.yaptim('b');
      await ortam.hatirlaticilar.ertele('e', ErteleSuresi.birSaat);
      await ortam.hatirlaticilar.guncelle('e', _yaz('Yeni adı'));

      final liste = {for (final h in (await ortam.hatirlaticilar.listele()).liste) h.id: h};
      expect(liste['g']!.sonrakiAn.isAfter(DateTime.utc(2026, 11, 1, 6)), isTrue, reason: 'moved to the next turn');
      expect(liste['g']!.durum, HatirlaticiDurumu.acik);
      expect(liste['b']!.durum, HatirlaticiDurumu.tamam);
      expect(liste['e']!.baslik, 'Yeni adı');
      expect(liste['e']!.erteleAn, isNull, reason: 'editing the rule cleared the snooze that came before it');
    });

    test('a snooze alone sets erteleAn and keeps the rule', () async {
      ortam.api.hatirlaticilar = [ornekHatirlatici(id: 'e')];
      await ortam.hatirlaticilar.listele();
      ortam.api.cevrimdisi = true;

      await ortam.hatirlaticilar.ertele('e', ErteleSuresi.birSaat);

      final h = (await ortam.hatirlaticilar.yerelListe()).single;
      expect(h.erteleAn, isNotNull);
      expect(h.sonrakiAn, DateTime.utc(2026, 11, 2, 6));
      expect(h.etkinAn, h.erteleAn);
    });

    test('deleted: hidden at once, and the server is told', () async {
      ortam.api.hatirlaticilar = [ornekHatirlatici(id: 'x')];
      await ortam.hatirlaticilar.listele();

      await ortam.hatirlaticilar.sil('x');
      expect(await ortam.hatirlaticilar.yerelListe(), isEmpty);

      expect(await ortam.esitleyici.gonder(), 1);
      expect(ortam.api.cagrilar, contains('hatirlaticiSil'));
    });

    test('offline, the list comes from the cache and says so', () async {
      ortam.api.hatirlaticilar = [ornekHatirlatici(id: 'x', baslik: 'Önbellekte')];
      await ortam.hatirlaticilar.listele();

      ortam.api.cevrimdisi = true;
      final sonuc = await ortam.hatirlaticilar.listele();
      expect(sonuc.cevrimdisi, isTrue);
      expect(sonuc.liste.single.baslik, 'Önbellekte');
    });

    test('the list is sorted by the effective moment: overdue first, a snooze moves a reminder', () async {
      ortam.api.hatirlaticilar = [
        ornekHatirlatici(id: 'c', sonrakiAn: DateTime.utc(2026, 11, 20)),
        ornekHatirlatici(id: 'a', sonrakiAn: DateTime.utc(2026, 11, 2)),
        ornekHatirlatici(id: 'b', sonrakiAn: DateTime.utc(2026, 11, 5), erteleAn: DateTime.utc(2026, 11, 1)),
      ];
      final liste = (await ortam.hatirlaticilar.listele()).liste;
      expect(liste.map((h) => h.id), ['b', 'a', 'c']);
    });
  });

  group('with a fake HTTP server', () {
    late AppDatabase db;
    late FakeAdapter adapter;
    late Esitleyici esitleyici;
    late HatirlaticiRepository repo;
    var an = DateTime.utc(2026, 11, 4, 12);

    void kur(ResponseBody Function(RequestOptions) yanitla) {
      adapter = FakeAdapter(yanitla);
      final api = ApiService(Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter);
      esitleyici = Esitleyici(api: api, db: db, simdi: () => an = an.add(const Duration(seconds: 1)));
      repo = HatirlaticiRepository(api: api, db: db, esitleyici: esitleyici);
    }

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() async => db.close());

    test('entries go out in the order they were made, with the right verbs, paths and bodies', () async {
      kur((istek) => jsonYanit(istek.method == 'DELETE' ? 204 : 200, _sunucuHatirlatici('h1')));
      final id = await repo.ekle(_yaz('Süt al'));
      await repo.guncelle(id, _yaz('Süt ve ekmek al'));
      await repo.ertele(id, ErteleSuresi.yarin);
      await repo.yaptim(id);
      await repo.sil(id);

      expect(await esitleyici.gonder(), 5);
      expect(adapter.istekler.map((i) => '${i.method} ${i.path}'), [
        'POST /api/hatirlaticilar',
        'PUT /api/hatirlaticilar/$id',
        'POST /api/hatirlaticilar/$id/ertele',
        'POST /api/hatirlaticilar/$id/yaptim',
        'DELETE /api/hatirlaticilar/$id',
      ]);
      final govde = adapter.istekler.first.data as Map;
      expect(govde['id'], id);
      expect(govde['baslik'], 'Süt al');
      expect(govde['gun'], '2026-11-10');
      expect(govde['tur'], 'gorev');
      expect(govde['tekrar'], 'yok');
      expect(govde.containsKey('saat'), isFalse, reason: 'no hour: the server uses its default');
      expect((adapter.istekler[2].data as Map)['sure'], 'yarin');
    });

    test('an hour and a Söz are sent in the API wire format', () async {
      kur((istek) => jsonYanit(201, _sunucuHatirlatici('h1')));
      await repo.ekle(HatirlaticiYaz(
        baslik: 'Kitap',
        tur: HatirlaticiTuru.soz,
        kime: 'Ali',
        gun: DateTime.utc(2026, 12, 15),
        saat: const Saat(18, 30),
        tekrar: Tekrar.yillik,
        onceGun: 3,
      ));
      await esitleyici.gonder();

      final govde = adapter.istekler.single.data as Map;
      expect(govde['tur'], 'soz');
      expect(govde['kime'], 'Ali');
      expect(govde['saat'], '18:30:00');
      expect(govde['tekrar'], 'yillik');
      expect(govde['onceGun'], 3);
    });

    test('a server answer parses into the model', () async {
      kur((istek) => jsonYanit(200, [_sunucuHatirlatici('h1', baslik: 'A')]));
      final sonuc = await repo.listele();
      expect(sonuc.liste.single.baslik, 'A');
      expect(sonuc.liste.single.gun, DateTime.utc(2026, 11, 10));
      expect(sonuc.liste.single.sonrakiAn, DateTime.utc(2026, 11, 10, 6));
    });

    test('a failed send stays queued and goes again; the repeated POST carries the same id', () async {
      var deneme = 0;
      kur((istek) => ++deneme == 1 ? jsonYanit(503, {}) : jsonYanit(201, _sunucuHatirlatici('h1')));
      final id = await repo.ekle(_yaz('Süt al'));

      expect(await esitleyici.gonder(), 0);
      expect(await esitleyici.gonder(), 1);
      expect(adapter.istekler.map((i) => (i.data as Map)['id']), [id, id]);
    });

    test('Yaptım on a reminder that is not open (409) or gone (404) is not shown as a refused entry', () async {
      kur((istek) => jsonYanit(istek.path.endsWith('/yaptim') ? 409 : 404, {}));
      await repo.yaptim('a');
      await repo.ertele('b', ErteleSuresi.birSaat);

      expect(await esitleyici.gonder(), 2);
      expect(await esitleyici.reddedilenler(), isEmpty);
    });

    test('a refused create (400) is kept with its reason and does not block the rest', () async {
      kur((istek) => istek.method == 'POST' && istek.path == '/api/hatirlaticilar'
          ? jsonYanit(400, {'errors': {'baslik': ['Başlık zorunlu.']}})
          : jsonYanit(200, _sunucuHatirlatici('h1')));
      await repo.ekle(_yaz('x'));
      await repo.yaptim('baska');

      expect(await esitleyici.gonder(), 1);
      expect(await esitleyici.reddedilenler(), hasLength(1));
    });
  });
}
