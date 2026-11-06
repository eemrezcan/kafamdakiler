import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/repositories/surum_denetcisi.dart';
import 'package:kafamdakiler/data/services/api_service.dart';

import 'fake_adapter.dart';

void main() {
  Future<SurumDenetcisi> kontrolEdilmis(int derleme, ResponseBody Function(RequestOptions) yanit) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = FakeAdapter(yanit);
    final denetci = SurumDenetcisi(api: ApiService(dio), derlemeNumarasi: derleme);
    await denetci.kontrolEt();
    return denetci;
  }

  ResponseBody enAz(int n) => jsonYanit(200, {'enAzMobilSurumKodu': n});

  test('equal build number does not block', () async {
    expect((await kontrolEdilmis(3, (_) => enAz(3))).guncellemeGerekli, isFalse);
  });

  test('older build number blocks', () async {
    expect((await kontrolEdilmis(2, (_) => enAz(3))).guncellemeGerekli, isTrue);
  });

  test('newer build number does not block', () async {
    expect((await kontrolEdilmis(5, (_) => enAz(3))).guncellemeGerekli, isFalse);
  });

  test('network error passes silently', () async {
    final d = await kontrolEdilmis(
      1,
      (istek) => throw DioException(requestOptions: istek, type: DioExceptionType.connectionError),
    );
    expect(d.guncellemeGerekli, isFalse);
  });

  test('server error passes silently', () async {
    expect((await kontrolEdilmis(1, (_) => jsonYanit(500, {}))).guncellemeGerekli, isFalse);
  });

  test('a failed re-check keeps the last known blocking state', () async {
    var hata = false;
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = FakeAdapter((istek) => hata
          ? throw DioException(requestOptions: istek, type: DioExceptionType.connectionTimeout)
          : enAz(9));
    final d = SurumDenetcisi(api: ApiService(dio), derlemeNumarasi: 1);
    await d.kontrolEt();
    hata = true;
    await d.kontrolEt();
    expect(d.guncellemeGerekli, isTrue);
  });
}
