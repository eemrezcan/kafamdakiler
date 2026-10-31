import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/gun.dart';
import 'package:kafamdakiler/data/models/oturum.dart';
import 'package:kafamdakiler/data/repositories/esitleyici.dart';
import 'package:kafamdakiler/data/services/api_service.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';

import 'fake_adapter.dart';

const _gun = {'tarih': '2026-10-31', 'miktar': 6, 'deger': 0.75, 'planli': true, 'guc': 0.5};
const _oturum = {
  'id': 's',
  'ogeId': 'o',
  'tarih': '2026-10-31',
  'baslangicKonum': 12,
  'bitisKonum': 35,
  'miktar': 23,
  'olusturulma': '2026-10-31T18:00:00Z',
  'son': true,
};

void main() {
  late AppDatabase db;
  late FakeAdapter adapter;
  late Esitleyici esitleyici;
  var an = DateTime.utc(2026, 10, 31, 12);

  void kur(ResponseBody Function(RequestOptions) yanitla) {
    adapter = FakeAdapter(yanitla);
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    esitleyici = Esitleyici(
      api: ApiService(dio),
      db: db,
      simdi: () => an = an.add(const Duration(seconds: 1)), // strictly increasing
    );
  }

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<BekleyenIslemlerData>> hepsi() => db.select(db.bekleyenIslemler).get();

  test('sends the queue in order and marks entries sent', () async {
    kur((istek) => jsonYanit(istek.method == 'PUT' ? 200 : 201, istek.method == 'PUT' ? _gun : _oturum));
    final tarih = DateTime.utc(2026, 10, 31);
    await esitleyici.gunYazKuyrugaAl('a1', tarih, const GunYaz(miktar: 6));
    await esitleyici.oturumKuyrugaAl('o1', const OturumEkle(bitisKonum: 35, baslangicKonum: 12));
    await esitleyici.gunYazKuyrugaAl('a1', tarih, const GunYaz(miktar: 7));

    expect(await esitleyici.gonder(), 3);

    expect(adapter.istekler.map((i) => '${i.method} ${i.path}'), [
      'PUT /api/aliskanliklar/a1/kayitlar/2026-10-31',
      'POST /api/ogeler/o1/oturumlar',
      'PUT /api/aliskanliklar/a1/kayitlar/2026-10-31',
    ]);
    expect(adapter.istekler[0].data, {'miktar': 6.0});
    expect((await hepsi()).every((s) => s.gonderildi), isTrue);
    expect(await esitleyici.bekleyenler(), isEmpty);
  });

  test('the session id queued on the phone is the id sent to the server', () async {
    kur((_) => jsonYanit(201, _oturum));
    final id = await esitleyici.oturumKuyrugaAl('o1', const OturumEkle(bitisKonum: 35));
    await esitleyici.gonder();
    expect((adapter.istekler.single.data as Map)['id'], id);
    expect(id[14], '7', reason: 'Guid v7: version nibble is 7');
  });

  test('200 ("this id already exists") counts as sent', () async {
    kur((_) => jsonYanit(200, _oturum));
    await esitleyici.oturumKuyrugaAl('o1', const OturumEkle(bitisKonum: 35));
    expect(await esitleyici.gonder(), 1);
    expect((await hepsi()).single.gonderildi, isTrue);
  });

  test('a network error leaves the entry (and everything after it) queued', () async {
    kur((istek) => throw DioException.connectionError(requestOptions: istek, reason: 'offline'));
    await esitleyici.gunYazKuyrugaAl('a1', DateTime.utc(2026, 10, 31), const GunYaz(miktar: 6));
    await esitleyici.oturumKuyrugaAl('o1', const OturumEkle(bitisKonum: 35));

    expect(await esitleyici.gonder(), 0);

    expect(adapter.istekler.length, 1, reason: 'stops at the first failure to keep order');
    expect((await hepsi()).where((s) => s.gonderildi), isEmpty);
    expect(await esitleyici.bekleyenler(), hasLength(2));

    // Back online: the next call sends them.
    kur((istek) => jsonYanit(istek.method == 'PUT' ? 200 : 201, istek.method == 'PUT' ? _gun : _oturum));
    expect(await esitleyici.gonder(), 2);
  });

  test('a 5xx keeps the entry queued', () async {
    kur((_) => jsonYanit(503, {}));
    await esitleyici.gunYazKuyrugaAl('a1', DateTime.utc(2026, 10, 31), const GunYaz(miktar: 6));
    expect(await esitleyici.gonder(), 0);
    final satir = (await hepsi()).single;
    expect(satir.gonderildi, isFalse);
    expect(satir.hata, isNull);
  });

  test('a 409 is stored as refused, skipped later, and does not block the next entry', () async {
    kur((istek) => istek.path.contains('oturumlar')
        ? jsonYanit(409, {'title': 'conflict'})
        : jsonYanit(200, _gun));
    await esitleyici.oturumKuyrugaAl('o1', const OturumEkle(bitisKonum: 35));
    await esitleyici.gunYazKuyrugaAl('a1', DateTime.utc(2026, 10, 31), const GunYaz(miktar: 6));

    expect(await esitleyici.gonder(), 1);

    final satirlar = await hepsi();
    final reddedilen = satirlar.firstWhere((s) => s.tur == BekleyenTur.oturumEkle);
    expect(reddedilen.gonderildi, isFalse);
    expect(reddedilen.hata, startsWith('409'));
    expect(await esitleyici.bekleyenler(), isEmpty);
    expect(await esitleyici.bekleyenler(reddedilenler: true), hasLength(1));

    expect(await esitleyici.gonder(), 0);
    expect(adapter.istekler.length, 2, reason: 'the refused entry is not retried');
  });

  test('queued body keeps the start instant for offline sessions', () async {
    kur((_) => jsonYanit(201, _oturum));
    await esitleyici.oturumKuyrugaAl(
      'o1',
      OturumEkle(bitisKonum: 35, baslangicKonum: 12, baslangicAni: DateTime.utc(2026, 10, 31, 18, 10)),
    );
    final govde = jsonDecode((await hepsi()).single.govde) as Map<String, dynamic>;
    expect(govde['baslangicAni'], '2026-10-31T18:10:00.000Z');
    expect(govde['baslangicKonum'], 12);
  });
}
