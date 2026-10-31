import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/services/token_depo.dart';
import 'package:kafamdakiler/data/services/token_interceptor.dart';

import 'fake_adapter.dart';

class BellekTokenDepo implements TokenDepo {
  BellekTokenDepo({this.access, this.refresh});

  String? access;
  String? refresh;

  @override
  Future<String?> accessToken() async => access;

  @override
  Future<String?> refreshToken() async => refresh;

  @override
  Future<void> kaydet({required String accessToken, required String refreshToken}) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> temizle() async {
    access = null;
    refresh = null;
  }
}

void main() {
  late BellekTokenDepo depo;
  late FakeAdapter adapter;
  late Dio dio;
  late int kapanmaSayisi;

  Dio kur(ResponseBody Function(RequestOptions) yanitla) {
    adapter = FakeAdapter(yanitla);
    final d = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    d.interceptors.add(TokenInterceptor(dio: d, depo: depo, oturumKapandi: () => kapanmaSayisi++));
    return d;
  }

  setUp(() {
    depo = BellekTokenDepo(access: 'eski', refresh: 'r1');
    kapanmaSayisi = 0;
  });

  test('adds the bearer token', () async {
    dio = kur((_) => jsonYanit(200, []));
    await dio.get<void>('/api/aliskanliklar');
    expect(adapter.istekler.single.headers['Authorization'], 'Bearer eski');
  });

  test('401 -> refresh -> repeats the request once with the new token', () async {
    dio = kur((istek) {
      if (istek.path == TokenInterceptor.yenileYolu) {
        expect(istek.data, {'refreshToken': 'r1'});
        return jsonYanit(200, {
          'tokenType': 'Bearer',
          'accessToken': 'yeni',
          'expiresIn': 3600,
          'refreshToken': 'r2',
        });
      }
      return istek.headers['Authorization'] == 'Bearer yeni' ? jsonYanit(200, [1]) : jsonYanit(401, {});
    });

    final yanit = await dio.get<List<dynamic>>('/api/aliskanliklar');

    expect(yanit.data, [1]);
    expect(adapter.istekler.map((i) => i.path), ['/api/aliskanliklar', TokenInterceptor.yenileYolu, '/api/aliskanliklar']);
    expect(adapter.istekler.last.headers['Authorization'], 'Bearer yeni');
    expect(depo.access, 'yeni');
    expect(depo.refresh, 'r2');
    expect(kapanmaSayisi, 0);
  });

  test('refresh also 401 -> session closes, tokens cleared, original 401 surfaces', () async {
    dio = kur((_) => jsonYanit(401, {}));

    await expectLater(
      dio.get<void>('/api/aliskanliklar'),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 401)),
    );

    expect(adapter.istekler.map((i) => i.path), ['/api/aliskanliklar', TokenInterceptor.yenileYolu]);
    expect(kapanmaSayisi, 1);
    expect(depo.access, isNull);
    expect(depo.refresh, isNull);
  });

  test('the repeated request is not refreshed a second time', () async {
    var yenilemeSayisi = 0;
    dio = kur((istek) {
      if (istek.path == TokenInterceptor.yenileYolu) {
        yenilemeSayisi++;
        return jsonYanit(200, {
          'tokenType': 'Bearer',
          'accessToken': 'yeni',
          'expiresIn': 3600,
          'refreshToken': 'r2',
        });
      }
      return jsonYanit(401, {}); // the API keeps refusing even the new token
    });

    await expectLater(dio.get<void>('/api/aliskanliklar'), throwsA(isA<DioException>()));
    expect(yenilemeSayisi, 1);
    expect(adapter.istekler.length, 3);
  });

  test('network failure during refresh keeps the session', () async {
    dio = kur((istek) {
      if (istek.path == TokenInterceptor.yenileYolu) {
        throw DioException.connectionError(requestOptions: istek, reason: 'offline');
      }
      return jsonYanit(401, {});
    });

    await expectLater(dio.get<void>('/api/aliskanliklar'), throwsA(isA<DioException>()));
    expect(kapanmaSayisi, 0);
    expect(depo.refresh, 'r1');
  });

  test('login 401 is not refreshed', () async {
    dio = kur((_) => jsonYanit(401, {}));
    await expectLater(
      dio.post<void>(TokenInterceptor.loginYolu, options: Options(extra: {TokenInterceptor.girissizAnahtari: true})),
      throwsA(isA<DioException>()),
    );
    expect(adapter.istekler.length, 1);
    expect(adapter.istekler.single.headers.containsKey('Authorization'), isFalse);
    expect(kapanmaSayisi, 0);
  });
}
