import 'package:dio/dio.dart';

import '../models/giris.dart';
import 'token_depo.dart';

/// Adds the bearer token, and on a 401 refreshes it once and repeats the
/// request once (K-0019). If the refresh fails the session is closed.
///
/// A [QueuedInterceptor] handles one request at a time, so parallel 401s do
/// not start parallel refreshes.
class TokenInterceptor extends QueuedInterceptor {
  TokenInterceptor({
    required this.dio,
    required this.depo,
    required this.oturumKapandi,
  }) : _yenilemeDio = Dio(dio.options.copyWith())..httpClientAdapter = dio.httpClientAdapter;

  static const loginYolu = '/api/hesap/login';
  static const yenileYolu = '/api/hesap/refresh';

  /// Marks a request that must not carry a token or trigger a refresh.
  static const girissizAnahtari = 'girissiz';
  static const _tekrarAnahtari = 'tekrarlandi';

  final Dio dio;
  final TokenDepo depo;
  final void Function() oturumKapandi;
  final Dio _yenilemeDio;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[girissizAnahtari] != true) {
      final token = await depo.accessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final istek = err.requestOptions;
    final yenilenebilir = err.response?.statusCode == 401 &&
        istek.extra[girissizAnahtari] != true &&
        istek.extra[_tekrarAnahtari] != true;
    if (!yenilenebilir) return handler.next(err);

    // Another queued request may have refreshed already: compare the token
    // this request used with the stored one before spending the refresh token.
    final gonderilen = istek.headers['Authorization'] as String?;
    var guncel = await depo.accessToken();
    if (guncel == null || gonderilen == 'Bearer $guncel') {
      final sonuc = await _yenile();
      if (sonuc.token == null) {
        if (sonuc.reddedildi) oturumKapandi();
        return handler.next(err);
      }
      guncel = sonuc.token;
    }

    istek.headers['Authorization'] = 'Bearer $guncel';
    istek.extra[_tekrarAnahtari] = true;
    try {
      // Retry on the interceptor-free client: going through [dio] again would
      // wait behind this very error handler in the queue (deadlock).
      handler.resolve(await _yenilemeDio.fetch<dynamic>(istek));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// `token` is the new access token. If it is null, `reddedildi` tells
  /// whether the server refused the refresh token (session over) or the
  /// refresh just could not be tried (offline, server error).
  Future<({String? token, bool reddedildi})> _yenile() async {
    final refresh = await depo.refreshToken();
    if (refresh == null) return (token: null, reddedildi: true);
    try {
      final yanit = await _yenilemeDio.post<Map<String, dynamic>>(
        yenileYolu,
        data: {'refreshToken': refresh},
        options: Options(extra: {girissizAnahtari: true}),
      );
      final tokenlar = GirisYaniti.fromJson(yanit.data!);
      await depo.kaydet(
        accessToken: tokenlar.accessToken,
        refreshToken: tokenlar.refreshToken,
      );
      return (token: tokenlar.accessToken, reddedildi: false);
    } on DioException catch (e) {
      // Only a refused refresh token ends the session; a network error must
      // not log the user out (the phone may simply be offline).
      final kod = e.response?.statusCode;
      final reddedildi = kod == 401 || kod == 403 || kod == 400;
      if (reddedildi) await depo.temizle();
      return (token: null, reddedildi: reddedildi);
    }
  }
}
