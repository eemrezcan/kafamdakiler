import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/models/yakalama.dart';
import 'package:kafamdakiler/data/repositories/esitleyici.dart';
import 'package:kafamdakiler/data/repositories/yakalama_repository.dart';
import 'package:kafamdakiler/data/services/api_service.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';
import 'package:kafamdakiler/data/services/fotograf_deposu.dart';

import 'fake_adapter.dart';

Map<String, dynamic> _sunucuYakalama(
  String id, {
  String durum = 'bekliyor',
  String? metin = 'sunucudaki',
  String? fotografId,
  String yakalandi = '2026-11-04T10:00:00Z',
}) =>
    {
      'id': id,
      'metin': metin,
      'fotografId': fotografId,
      'durum': durum,
      'yakalandiAt': yakalandi,
      'olusturulma': '2026-11-04T10:00:01Z',
    };

void main() {
  late AppDatabase db;
  late FakeAdapter adapter;
  late Esitleyici esitleyici;
  late YakalamaRepository repo;
  late Directory klasor;
  late Directory kaynak;
  var an = DateTime.utc(2026, 11, 4, 12);

  void kur(ResponseBody Function(RequestOptions) yanitla) {
    adapter = FakeAdapter(yanitla);
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    final api = ApiService(dio);
    esitleyici = Esitleyici(api: api, db: db, simdi: () => an = an.add(const Duration(seconds: 1)));
    repo = YakalamaRepository(
      api: api,
      db: db,
      esitleyici: esitleyici,
      fotograflar: FotografDeposu(klasor: () async => klasor),
      simdi: () => an = an.add(const Duration(seconds: 1)),
    );
  }

  /// A server that accepts uploads and captures; [yakalamaYaniti] can override the capture answer.
  ResponseBody Function(RequestOptions) saglam({ResponseBody Function(RequestOptions)? yakalamaYaniti}) => (istek) {
        if (istek.path == '/api/dosyalar') return jsonYanit(201, {'id': 'f1', 'url': '/api/dosyalar/f1'});
        if (yakalamaYaniti != null) return yakalamaYaniti(istek);
        if (istek.method == 'DELETE') return ResponseBody.fromString('', 204);
        final govde = istek.data as Map;
        return jsonYanit(istek.method == 'POST' ? 201 : 200, _sunucuYakalama(govde['id'] as String? ?? 'y1'));
      };

  File fotografOlustur() => File('${kaynak.path}/foto.jpg')..writeAsBytesSync([1, 2, 3, 4]);

  int sayi(String yontem, String yol) => adapter.istekler.where((i) => i.method == yontem && i.path == yol).length;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    klasor = Directory.systemTemp.createTempSync('yakalama_kopya');
    kaynak = Directory.systemTemp.createTempSync('yakalama_kaynak');
  });
  tearDown(() async {
    await db.close();
    klasor.deleteSync(recursive: true);
    kaynak.deleteSync(recursive: true);
  });

  group('new capture', () {
    test('is written to the phone while offline and sent later with the same id', () async {
      kur((istek) => throw DioException.connectionError(requestOptions: istek, reason: 'offline'));
      await repo.yakala(metin: '  süt al  ');

      final liste = await repo.yerelListe();
      expect(liste.single.metin, 'süt al');
      expect(liste.single.konum, YakalamaKonumu.telefonda);
      expect(liste.single.id[14], '7', reason: 'Guid v7');
      expect(await esitleyici.gonder(), 0);
      expect(await esitleyici.bekleyenler(), hasLength(1));

      // Back online.
      kur(saglam());
      expect(await esitleyici.gonder(), 1);
      final gonderilen = adapter.istekler.single;
      expect('${gonderilen.method} ${gonderilen.path}', 'POST /api/yakalamalar');
      expect((gonderilen.data as Map)['id'], liste.single.id);
      expect((gonderilen.data as Map)['metin'], 'süt al');
      expect((gonderilen.data as Map)['yakalandiAt'], endsWith('Z'));
      expect((gonderilen.data as Map).containsKey('fotografYolu'), isFalse, reason: 'local path never leaves the phone');
      expect(await esitleyici.bekleyenler(), isEmpty);
    });

    test('the photo is copied into the app folder, uploaded first, and not uploaded again on a retry', () async {
      var yakalamaDenemesi = 0;
      kur(saglam(yakalamaYaniti: (istek) {
        yakalamaDenemesi++;
        return yakalamaDenemesi == 1 ? jsonYanit(503, {}) : jsonYanit(201, _sunucuYakalama('x'));
      }));
      final secilen = fotografOlustur();
      await repo.yakala(fotografKaynagi: secilen.path);

      final kopya = (await repo.yerelListe()).single.fotografYolu!;
      expect(kopya, startsWith(klasor.path));
      expect(File(kopya).existsSync(), isTrue);
      expect(kopya, isNot(secilen.path));

      expect(await esitleyici.gonder(), 0, reason: 'the capture POST failed with 503');
      expect(sayi('POST', '/api/dosyalar'), 1);
      final satir = (await db.select(db.bekleyenIslemler).get()).single;
      expect(YakalamaGovde.fromJson(jsonDecode(satir.govde) as Map<String, dynamic>).yaz.fotografId, 'f1',
          reason: 'the uploaded id is written to the queue entry');

      expect(await esitleyici.gonder(), 1);
      expect(sayi('POST', '/api/dosyalar'), 1, reason: 'no second upload');
      expect(sayi('POST', '/api/yakalamalar'), 2);
      expect((adapter.istekler.last.data as Map)['fotografId'], 'f1');
      expect(File(kopya).existsSync(), isFalse, reason: 'the phone copy goes once the server has the photo');
      expect(await esitleyici.bekleyenler(), isEmpty);
    });

    test('the photo goes up before the capture', () async {
      kur(saglam());
      await repo.yakala(fotografKaynagi: fotografOlustur().path);
      await esitleyici.gonder();
      expect(adapter.istekler.map((i) => i.path), ['/api/dosyalar', '/api/yakalamalar']);
    });

    test('deleted before it was sent: leaves the queue, the server hears nothing', () async {
      kur(saglam());
      await repo.yakala(metin: 'x', fotografKaynagi: fotografOlustur().path);
      final satir = (await repo.yerelListe()).single;
      final kopya = satir.fotografYolu!;

      await repo.sil(satir.id);

      expect(await esitleyici.bekleyenler(reddedilenler: true), isEmpty);
      expect(await repo.yerelListe(), isEmpty);
      expect(File(kopya).existsSync(), isFalse);
      expect(await esitleyici.gonder(), 0);
      expect(adapter.istekler, isEmpty);
    });

    test('a 4xx marks the entry refused: visible with its reason, not retried, does not block others', () async {
      kur(saglam(yakalamaYaniti: (istek) {
        final govde = istek.data as Map;
        return govde['metin'] == 'kötü'
            ? jsonYanit(400, {'errors': {'hedef': ['Hedef geçersiz.']}})
            : jsonYanit(201, _sunucuYakalama(govde['id'] as String));
      }));
      await repo.yakala(metin: 'kötü');
      await repo.yakala(metin: 'iyi');

      expect(await esitleyici.gonder(), 1);

      final liste = await repo.yerelListe();
      final kotu = liste.firstWhere((s) => s.metin == 'kötü');
      expect(kotu.hata, startsWith('400'));
      expect(kotu.konum, YakalamaKonumu.telefonda);
      expect(liste.where((s) => s.metin == 'iyi'), isEmpty, reason: 'the good one was sent and is gone from the queue');
      expect(await esitleyici.bekleyenler(), isEmpty);

      await esitleyici.gonder();
      expect(sayi('POST', '/api/yakalamalar'), 2, reason: 'the refused entry is not tried again');

      // Deleting the refused one removes it for good.
      await repo.sil(kotu.id);
      expect(await repo.yerelListe(), isEmpty);
    });

    test('a 4xx on the photo upload refuses the entry', () async {
      kur((istek) => istek.path == '/api/dosyalar' ? jsonYanit(400, {'title': 'bad'}) : jsonYanit(201, {}));
      await repo.yakala(fotografKaynagi: fotografOlustur().path);
      expect(await esitleyici.gonder(), 0);
      expect((await repo.yerelListe()).single.hata, startsWith('400'));
      expect(adapter.istekler.map((i) => i.path), ['/api/dosyalar']);
    });

    test('a missing photo copy refuses the entry without a request', () async {
      kur(saglam());
      await repo.yakala(fotografKaynagi: fotografOlustur().path);
      File((await repo.yerelListe()).single.fotografYolu!).deleteSync();

      expect(await esitleyici.gonder(), 0);

      expect((await repo.yerelListe()).single.hata, contains('bulunamadı'));
      expect(adapter.istekler, isEmpty);
    });

    test('a 5xx keeps the entry queued without a reason', () async {
      kur((_) => jsonYanit(503, {}));
      await repo.yakala(metin: 'x');
      expect(await esitleyici.gonder(), 0);
      expect((await repo.yerelListe()).single.hata, isNull);
      expect(await esitleyici.bekleyenler(), hasLength(1));
    });
  });

  group('edit and delete', () {
    test('editing an unsent capture rewrites the queued body (one entry, not two)', () async {
      kur(saglam());
      await repo.yakala(metin: 'ilk');
      final ilk = (await repo.yerelListe()).single;

      await repo.guncelle(ilk, metin: 'ikinci');

      expect(await db.select(db.bekleyenIslemler).get(), hasLength(1));
      final liste = await repo.yerelListe();
      expect(liste.single.metin, 'ikinci');
      expect(liste.single.yakalandiAt, ilk.yakalandiAt, reason: 'the capture time stays');
      await esitleyici.gonder();
      expect(adapter.istekler.single.method, 'POST');
      expect((adapter.istekler.single.data as Map)['metin'], 'ikinci');
    });

    test('editing a refused capture clears the refusal so it is tried again', () async {
      kur((_) => jsonYanit(400, {'title': 'bad'}));
      await repo.yakala(metin: 'kötü');
      await esitleyici.gonder();
      final reddedilen = (await repo.yerelListe()).single;
      expect(reddedilen.hata, isNotNull);

      kur(saglam());
      await repo.guncelle(reddedilen, metin: 'düzeldi');
      expect((await repo.yerelListe()).single.hata, isNull);
      expect(await esitleyici.gonder(), 1);
    });

    test('removing the photo of an unsent capture deletes the phone copy and sends none', () async {
      kur(saglam());
      await repo.yakala(metin: 'x', fotografKaynagi: fotografOlustur().path);
      final satir = (await repo.yerelListe()).single;
      final kopya = satir.fotografYolu!;

      await repo.guncelle(satir, metin: 'x', fotografKaldir: true);

      expect(File(kopya).existsSync(), isFalse);
      await esitleyici.gonder();
      expect(adapter.istekler.map((i) => i.path), ['/api/yakalamalar'], reason: 'no upload');
      expect((adapter.istekler.single.data as Map).containsKey('fotografId'), isFalse);
    });

    test('replacing the photo of an unsent capture uploads only the new one', () async {
      kur(saglam());
      await repo.yakala(metin: 'x', fotografKaynagi: fotografOlustur().path);
      final eski = (await repo.yerelListe()).single;
      final yeni = File('${kaynak.path}/yeni.jpg')..writeAsBytesSync([9, 9]);

      await repo.guncelle(eski, metin: 'x', yeniFotografKaynagi: yeni.path);

      expect(File(eski.fotografYolu!).existsSync(), isFalse);
      await esitleyici.gonder();
      expect(sayi('POST', '/api/dosyalar'), 1);
    });

    test('editing a capture on the server queues a PUT with the capture time and the photo kept', () async {
      kur((istek) => istek.method == 'GET'
          ? jsonYanit(200, [_sunucuYakalama('y1', fotografId: 'sf', yakalandi: '2026-11-04T09:00:00Z')])
          : jsonYanit(200, _sunucuYakalama('y1')));
      final sunucudaki = (await repo.listele()).liste.single;
      expect(sunucudaki.konum, YakalamaKonumu.sunucuda);

      await repo.guncelle(sunucudaki, metin: 'yeni metin');

      // Offline: the cached list shows the edit as waiting on the phone.
      kur((istek) => throw DioException.connectionError(requestOptions: istek, reason: 'offline'));
      final cevrimdisi = await repo.listele();
      expect(cevrimdisi.cevrimdisi, isTrue);
      expect(cevrimdisi.liste.single.metin, 'yeni metin');
      expect(cevrimdisi.liste.single.konum, YakalamaKonumu.telefonda);

      kur(saglam());
      expect(await esitleyici.gonder(), 1);
      final istek = adapter.istekler.single;
      expect('${istek.method} ${istek.path}', 'PUT /api/yakalamalar/y1');
      expect((istek.data as Map)['metin'], 'yeni metin');
      expect((istek.data as Map)['fotografId'], 'sf');
      expect((istek.data as Map)['yakalandiAt'], '2026-11-04T09:00:00.000Z');
    });

    test('deleting a capture on the server queues a DELETE and hides it at once', () async {
      kur((istek) => istek.method == 'GET'
          ? jsonYanit(200, [_sunucuYakalama('y1')])
          : ResponseBody.fromString('', 204));
      await repo.listele();

      await repo.sil('y1');

      expect(await repo.yerelListe(), isEmpty);
      expect(await esitleyici.gonder(), 1);
      expect('${adapter.istekler.last.method} ${adapter.istekler.last.path}', 'DELETE /api/yakalamalar/y1');
    });

    test('a DELETE answered 404 counts as done', () async {
      kur((istek) => istek.method == 'GET' ? jsonYanit(200, [_sunucuYakalama('y1')]) : jsonYanit(404, {}));
      await repo.listele();
      await repo.sil('y1');
      expect(await esitleyici.gonder(), 1);
      expect(await esitleyici.bekleyenler(reddedilenler: true), isEmpty);
    });

    test('a 409 "being sent to the brain right now" keeps the entry queued; it goes through on the next try', () async {
      var gonderiliyor = true;
      kur((istek) {
        if (istek.method == 'GET') return jsonYanit(200, [_sunucuYakalama('y1')]);
        if (!gonderiliyor) return istek.method == 'DELETE' ? ResponseBody.fromString('', 204) : jsonYanit(200, _sunucuYakalama('y1'));
        return jsonYanit(409, {'title': 'Çakışma', 'detail': 'Yakalama şu an beyne gönderiliyor; birazdan tekrar dene.'});
      });
      await repo.listele();
      await repo.sil('y1');

      expect(await esitleyici.gonder(), 0);
      expect(await esitleyici.bekleyenler(), hasLength(1), reason: 'still waiting, not refused');
      expect(await esitleyici.reddedilenler(), isEmpty);

      gonderiliyor = false;
      expect(await esitleyici.gonder(), 1);
      expect(await esitleyici.bekleyenler(reddedilenler: true), isEmpty);
    });

    test('the same 409 on an edit keeps the edit queued too', () async {
      var gonderiliyor = true;
      kur((istek) {
        if (istek.method == 'GET') return jsonYanit(200, [_sunucuYakalama('y1')]);
        return gonderiliyor
            ? jsonYanit(409, {'title': 'Çakışma', 'detail': 'Yakalama şu an beyne gönderiliyor; birazdan tekrar dene.'})
            : jsonYanit(200, _sunucuYakalama('y1', metin: 'yeni'));
      });
      final sunucudaki = (await repo.listele()).liste.single;
      await repo.guncelle(sunucudaki, metin: 'yeni');

      expect(await esitleyici.gonder(), 0);
      expect(await esitleyici.reddedilenler(), isEmpty);

      gonderiliyor = false;
      expect(await esitleyici.gonder(), 1);
    });

    test('a DELETE answered 409 comes back to the list with the reason', () async {
      kur((istek) => istek.method == 'GET' ? jsonYanit(200, [_sunucuYakalama('y1')]) : jsonYanit(409, {'title': 'x'}));
      await repo.listele();
      await repo.sil('y1');
      expect(await esitleyici.gonder(), 0);

      final satir = (await repo.yerelListe()).single;
      expect(satir.id, 'y1');
      expect(satir.hata, startsWith('409'));
    });
  });

  group('list', () {
    test('newest capture first; server marks follow the status; sent-to-brain ones are read-only', () async {
      kur((istek) => istek.method == 'GET'
          ? jsonYanit(200, [
              _sunucuYakalama('eski', yakalandi: '2026-11-04T08:00:00Z'),
              _sunucuYakalama('beyinde', durum: 'beyneGitti', yakalandi: '2026-11-04T09:00:00Z'),
              _sunucuYakalama('islendi', durum: 'islendi', yakalandi: '2026-11-04T07:00:00Z'),
            ])
          : jsonYanit(201, {}));
      await repo.yakala(metin: 'telefonda'); // captured at 12:00:xx, newest

      final liste = (await repo.listele()).liste;

      expect(liste.map((s) => s.id).skip(1), ['beyinde', 'eski', 'islendi']);
      expect(liste.first.konum, YakalamaKonumu.telefonda);
      expect(liste.firstWhere((s) => s.id == 'eski').konum, YakalamaKonumu.sunucuda);
      final beyinde = liste.firstWhere((s) => s.id == 'beyinde');
      expect(beyinde.konum, YakalamaKonumu.beyinde);
      expect(beyinde.degistirilebilir, isFalse);
      final islendi = liste.firstWhere((s) => s.id == 'islendi');
      expect(islendi.konum, YakalamaKonumu.beyinde);
      expect(islendi.islendi, isTrue);
    });

    test('a server error (not offline) is thrown, so the screen can say so', () async {
      kur((_) => jsonYanit(500, {}));
      expect(repo.listele(), throwsA(isA<DioException>()));
    });
  });
}
