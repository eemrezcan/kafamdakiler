import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kafamdakiler/data/models/sunucu_bildirimi.dart';
import 'package:kafamdakiler/data/repositories/auth_repository.dart';
import 'package:kafamdakiler/data/repositories/hatirlatici_bildirim_yoneticisi.dart';
import 'package:kafamdakiler/data/repositories/push_mesaj_isleyici.dart';
import 'package:kafamdakiler/data/repositories/push_yoneticisi.dart';
import 'package:kafamdakiler/data/services/api_service.dart';
import 'package:kafamdakiler/data/services/bildirim_servisi.dart';
import 'package:kafamdakiler/data/services/push_kaynagi.dart';
import 'package:kafamdakiler/data/services/sunucu_bildirim_gosterici.dart';
import 'package:kafamdakiler/data/services/token_depo.dart';
import 'package:kafamdakiler/utils/bildirim_plani.dart';

import '../test_destek.dart';
import 'fake_adapter.dart';

// The phone's side of the push channel: the token reaches the server (and leaves it on sign-out), the "wake up" message
// becomes a notification with the server's text, or a fallback text when the server cannot be reached, and a tap opens
// the route. Firebase and the notification plugin are behind interfaces; the HTTP calls are real, on a fake adapter.

class _SahteKaynak implements PushKaynagi {
  String? mevcut = 'token-1';
  final yenilenme = StreamController<String>.broadcast();
  final mesajlar = StreamController<Map<String, String>>.broadcast();

  @override
  Future<String?> token() async => mevcut;

  @override
  Stream<String> get tokenYenilendi => yenilenme.stream;

  @override
  Stream<Map<String, String>> get onPlanMesajlari => mesajlar.stream;
}

class Gosterilen {
  Gosterilen(this.id, this.baslik, this.govde, this.yuk);
  final int id;
  final String baslik;
  final String govde;
  final String yuk;
}

class HatirlaticiGosterimi {
  HatirlaticiGosterimi(this.id, this.baslik, this.govde, this.hatirlaticiId);
  final int id;
  final String baslik;
  final String govde;
  final String hatirlaticiId;
}

class IsKartiGosterimi {
  IsKartiGosterimi(this.id, this.baslik, this.govde, this.yuk, this.dugmeler);
  final int id;
  final String baslik;
  final String govde;
  final String yuk;
  final List<IsBildirimDugmesi> dugmeler;
}

class SahteGosterici implements SunucuBildirimGosterici {
  final gosterilenler = <Gosterilen>[];
  final hatirlaticilar = <HatirlaticiGosterimi>[];
  final isKartlari = <IsKartiGosterimi>[];

  @override
  Future<void> isKartiGoster({
    required int id,
    required String baslik,
    required String govde,
    required String yuk,
    required List<IsBildirimDugmesi> dugmeler,
  }) async =>
      isKartlari.add(IsKartiGosterimi(id, baslik, govde, yuk, dugmeler));

  @override
  Future<void> hatirlaticiGoster({required int id, required String baslik, required String govde, required String hatirlaticiId}) async =>
      hatirlaticilar.add(HatirlaticiGosterimi(id, baslik, govde, hatirlaticiId));

  @override
  Future<void> goster({required int id, required String baslik, required String govde, required String yuk}) async =>
      gosterilenler.add(Gosterilen(id, baslik, govde, yuk));
}

class _Depo implements TokenDepo {
  final olaylar = <String>[];
  @override
  Future<String?> accessToken() async => 'a';
  @override
  Future<String?> refreshToken() async => 'r';
  @override
  Future<void> kaydet({required String accessToken, required String refreshToken}) async {}
  @override
  Future<void> temizle() async => olaylar.add('temizle');
}

void main() {
  late FakeAdapter adapter;
  late ApiService api;

  ResponseBody Function(RequestOptions) varsayilan = (_) => ResponseBody.fromString('', 204);

  setUpAll(() => initializeDateFormatting('tr'));

  setUp(() {
    varsayilan = (_) => ResponseBody.fromString('', 204);
    adapter = FakeAdapter((istek) => varsayilan(istek));
    api = ApiService(Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter);
  });

  group('PushMesajIsleyici', () {
    late SahteGosterici gosterici;
    late PushMesajIsleyici isleyici;

    setUp(() {
      gosterici = SahteGosterici();
      isleyici = PushMesajIsleyici(getir: api.sunucuBildirimiGetir, gosterici: gosterici, zamanAsimi: const Duration(milliseconds: 200));
    });

    test('fetches the text by the id in the message and shows it, with the route for the tap', () async {
      varsayilan = (_) => jsonYanit(200, {
            'id': 'b1',
            'baslik': 'Su iç',
            'metin': 'Bir bardak su',
            'rota': '/hatirlaticilar',
            'hedefKimligi': null,
            'kaynakTuru': 'test',
            'olusmaAni': '2026-11-09T10:00:00Z',
          });

      await isleyici.isle({'bildirimId': 'b1'});

      expect(adapter.istekler.single.method, 'GET');
      expect(adapter.istekler.single.path, '/api/bildirimler/b1');
      final g = gosterilenlerTek(gosterici);
      expect(g.baslik, 'Su iç');
      expect(g.govde, 'Bir bardak su');
      expect(g.yuk, 'rota:/hatirlaticilar');
    });

    test('a notification without a target opens Bugün', () async {
      varsayilan = (_) => jsonYanit(200, {'id': 'b1', 'baslik': 'x', 'metin': 'y'});

      await isleyici.isle({'bildirimId': 'b1'});

      expect(gosterilenlerTek(gosterici).yuk, 'rota:/');
    });

    test('the same notification always gets the same id, so a repeat replaces it', () async {
      varsayilan = (_) => jsonYanit(200, {'id': 'b1', 'baslik': 'x', 'metin': 'y'});

      await isleyici.isle({'bildirimId': 'b1'});
      await isleyici.isle({'bildirimId': 'b1'});

      expect(gosterici.gosterilenler[0].id, gosterici.gosterilenler[1].id);
    });

    test('when the server cannot be reached (tailnet off) it shows the fallback text', () async {
      varsayilan = (istek) => throw DioException(requestOptions: istek, type: DioExceptionType.connectionError);

      await isleyici.isle({'bildirimId': 'b1'});

      final g = gosterilenlerTek(gosterici);
      expect(g.baslik, PushMesajIsleyici.yedekBaslik);
      expect(g.govde, 'Yeni bildirim var');
      expect(g.yuk, 'rota:/');
    });

    test('a server error shows the fallback text too', () async {
      varsayilan = (_) => jsonYanit(500, {});

      await isleyici.isle({'bildirimId': 'b1'});

      expect(gosterilenlerTek(gosterici).govde, 'Yeni bildirim var');
    });

    test('a server that does not answer in time shows the fallback text', () async {
      final bekle = Completer<void>();
      final yavas = PushMesajIsleyici(
        getir: (_) async {
          await bekle.future;
          throw StateError('never');
        },
        gosterici: gosterici,
        zamanAsimi: const Duration(milliseconds: 50),
      );

      await yavas.isle({'bildirimId': 'b1'});
      bekle.complete();

      expect(gosterilenlerTek(gosterici).govde, 'Yeni bildirim var');
    });

    test('a 404 (not this user\'s notification) shows nothing', () async {
      varsayilan = (_) => jsonYanit(404, {});

      await isleyici.isle({'bildirimId': 'b1'});

      expect(gosterici.gosterilenler, isEmpty);
    });

    test('a message without bildirimId is not the server\'s and is ignored', () async {
      await isleyici.isle({'baska': 'x'});
      await isleyici.isle({});

      expect(adapter.istekler, isEmpty);
      expect(gosterici.gosterilenler, isEmpty);
    });

    test('a target outside the app is not followed', () async {
      varsayilan = (_) => jsonYanit(200, {'id': 'b1', 'baslik': 'x', 'metin': 'y', 'rota': 'https://evil.example'});

      await isleyici.isle({'bildirimId': 'b1'});

      expect(gosterilenlerTek(gosterici).yuk, 'rota:/');
    });

    // The reminder's moment sent by the server and the phone's own scheduled one are one notification: the same id.
    group('a reminder\'s moment', () {
      void sunucuHatirlaticiyiVer() {
        varsayilan = (_) => jsonYanit(200, {
              'id': 'b1',
              'baslik': 'İlaç al',
              'metin': 'bugün',
              'rota': '/hatirlatici/{id}/duzenle',
              'hedefKimligi': 'h-1',
              'kaynakTuru': 'hatirlatici',
              'olusmaAni': '2026-11-09T10:00:00Z',
            });
      }

      test('is shown through the reminder path, not as a plain server notification', () async {
        sunucuHatirlaticiyiVer();

        await isleyici.isle({'bildirimId': 'b1'});

        expect(gosterici.gosterilenler, isEmpty);
        final g = gosterici.hatirlaticilar.single;
        expect((g.baslik, g.govde, g.hatirlaticiId), ('İlaç al', 'bugün', 'h-1'));
      });

      test('has the id of the notification the phone schedules for that reminder', () async {
        sunucuHatirlaticiyiVer();
        await isleyici.isle({'bildirimId': 'b1'});

        final yerel = bildirimleriPlanla(
          [ornekHatirlatici(id: 'h-1', baslik: 'İlaç al', sonrakiAn: DateTime.utc(2026, 11, 9, 12))],
          DateTime.utc(2026, 11, 9, 8),
        ).single;

        expect(gosterici.hatirlaticilar.single.id, yerel.id);
      });

      test('the same id on every delivery of the same reminder, and another id for another reminder', () async {
        sunucuHatirlaticiyiVer();
        await isleyici.isle({'bildirimId': 'b1'});
        await isleyici.isle({'bildirimId': 'b2'});
        varsayilan = (_) => jsonYanit(200, {
              'id': 'b3', 'baslik': 'x', 'metin': 'bugün', 'rota': '/hatirlatici/{id}/duzenle', 'hedefKimligi': 'h-2', 'kaynakTuru': 'hatirlatici',
            });
        await isleyici.isle({'bildirimId': 'b3'});

        final idler = gosterici.hatirlaticilar.map((g) => g.id).toList();
        expect(idler[0], idler[1]);
        expect(idler[2], isNot(idler[0]));
      });

      test('a task notification of the server stays a plain server notification', () async {
        varsayilan = (_) => jsonYanit(200, {
              'id': 'b1', 'baslik': 'Görev', 'metin': 'x', 'rota': '/projeler/{id}', 'hedefKimligi': 'kitap-kulubu', 'kaynakTuru': 'gorev',
            });

        await isleyici.isle({'bildirimId': 'b1'});

        expect(gosterici.hatirlaticilar, isEmpty);
        expect(gosterilenlerTek(gosterici).yuk, 'rota:/projeler/kitap-kulubu');
      });

      test('a reminder notification without its reminder id is shown as a plain one', () async {
        varsayilan = (_) => jsonYanit(200, {'id': 'b1', 'baslik': 'x', 'metin': 'y', 'kaynakTuru': 'hatirlatici'});

        await isleyici.isle({'bildirimId': 'b1'});

        expect(gosterici.hatirlaticilar, isEmpty);
        expect(gosterici.gosterilenler, hasLength(1));
      });
    });
  });

  group('PushYoneticisi', () {
    late _SahteKaynak kaynak;
    late SahteGosterici gosterici;
    late PushYoneticisi yonetici;
    var girisYapildi = true;

    setUp(() {
      kaynak = _SahteKaynak();
      gosterici = SahteGosterici();
      girisYapildi = true;
      yonetici = PushYoneticisi(
        api: api,
        kaynak: kaynak,
        isleyici: PushMesajIsleyici(getir: api.sunucuBildirimiGetir, gosterici: gosterici),
        girisYapildi: () => girisYapildi,
        cihazAdi: 'Pixel',
        silmeZamanAsimi: const Duration(milliseconds: 200),
      );
    });
    tearDown(() => yonetici.durdur());

    test('signed in: the token and the device name go to the server', () async {
      await yonetici.kaydet();

      final istek = adapter.istekler.single;
      expect(istek.method, 'POST');
      expect(istek.path, '/api/bildirim/cihaz');
      expect(istek.data, {'token': 'token-1', 'cihazAdi': 'Pixel'});
    });

    test('signed out: nothing is sent', () async {
      girisYapildi = false;

      await yonetici.kaydet();

      expect(adapter.istekler, isEmpty);
    });

    test('Firebase not available (no token): nothing is sent', () async {
      kaynak.mevcut = null;

      await yonetici.kaydet();

      expect(adapter.istekler, isEmpty);
    });

    test('the same token is sent once per run', () async {
      await yonetici.kaydet();
      await yonetici.kaydet();

      expect(adapter.istekler, hasLength(1));
    });

    test('a failed send (offline) is tried again by the next call', () async {
      varsayilan = (istek) => throw DioException(requestOptions: istek, type: DioExceptionType.connectionError);
      await yonetici.kaydet();

      varsayilan = (_) => ResponseBody.fromString('', 204);
      await yonetici.kaydet();

      expect(adapter.istekler, hasLength(2));
    });

    test('a renewed token goes to the server', () async {
      yonetici.baslat();

      kaynak.yenilenme.add('token-2');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(adapter.istekler.single.data, containsPair('token', 'token-2'));
    });

    test('a message that arrives while the app is open is shown', () async {
      varsayilan = (_) => jsonYanit(200, {'id': 'b1', 'baslik': 'Açıkken', 'metin': 'geldi'});
      yonetici.baslat();

      kaynak.mesajlar.add({'bildirimId': 'b1'});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(gosterilenlerTek(gosterici).baslik, 'Açıkken');
    });

    test('sign-out deletes the token from the server', () async {
      await yonetici.kaydet();
      adapter.istekler.clear();

      await yonetici.cikisOncesiSil();

      final istek = adapter.istekler.single;
      expect(istek.method, 'DELETE');
      expect(istek.path, '/api/bildirim/cihaz');
      expect(istek.data, {'token': 'token-1'});
    });

    test('sign-out offline still finishes', () async {
      await yonetici.kaydet();
      varsayilan = (istek) => throw DioException(requestOptions: istek, type: DioExceptionType.connectionError);

      await yonetici.cikisOncesiSil();
    });
  });

  group('AuthRepository.cikis', () {
    test('runs the pre-sign-out work before the tokens are wiped, and a failure there does not stop the sign-out', () async {
      final depo = _Depo();
      final auth = AuthRepository(
        api: api,
        depo: depo,
        cikistanOnce: () async {
          depo.olaylar.add('once');
          throw StateError('offline');
        },
        cikistaTemizle: () async => depo.olaylar.add('temizlik'),
      );

      await auth.baslat();
      await auth.cikis();

      expect(depo.olaylar, ['once', 'temizle', 'temizlik']);
      expect(auth.girisYapildi, isFalse);
    });
  });

  group('tap on a server notification', () {
    test('opens the route the notification names', () async {
      final ortam = TestOrtami();
      final servis = SahteBildirimServisi();
      final yonetici = HatirlaticiBildirimYoneticisi(
        repo: ortam.hatirlaticilar,
        esitleyici: ortam.esitleyici,
        servis: servis,
        yazabilir: () => true,
      );
      final acilanlar = <String>[];
      var liste = 0;

      await yonetici.baslat(listeyiAc: () => liste++, rotayiAc: acilanlar.add);
      servis.yanitla!(const BildirimYaniti(rota: '/eylemler'));
      await Future<void>.delayed(Duration.zero);

      expect(acilanlar, ['/eylemler']);
      expect(liste, 0, reason: 'a server notification is not the reminders list');

      yonetici.durdur();
      await ortam.kapat();
    });

    test('the notification that opened the app from a closed state is answered too', () async {
      final ortam = TestOrtami();
      final servis = SahteBildirimServisi()..acilis = const BildirimYaniti(rota: '/');
      final yonetici = HatirlaticiBildirimYoneticisi(
        repo: ortam.hatirlaticilar,
        esitleyici: ortam.esitleyici,
        servis: servis,
        yazabilir: () => true,
      );
      final acilanlar = <String>[];

      await yonetici.baslat(listeyiAc: () {}, rotayiAc: acilanlar.add);

      expect(acilanlar, ['/'], reason: 'no target means Bugün');

      yonetici.durdur();
      await ortam.kapat();
    });
  });

  test('SunucuBildirimi reads the API answer', () {
    final b = SunucuBildirimi.fromJson({'id': 'x', 'baslik': 'B', 'metin': 'M', 'rota': '/a', 'hedefKimligi': '5'});
    expect([b.id, b.baslik, b.metin, b.rota, b.hedefKimligi], ['x', 'B', 'M', '/a', '5']);
  });
}

Gosterilen gosterilenlerTek(SahteGosterici g) {
  expect(g.gosterilenler, hasLength(1));
  return g.gosterilenler.single;
}
