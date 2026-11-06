import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../utils/aliskanlik_gunu.dart';
import '../models/aliskanlik.dart';
import '../models/ben.dart';
import '../models/beyin.dart';
import '../models/enums.dart';
import '../models/giris.dart';
import '../models/gun.dart';
import '../models/oge.dart';
import '../models/oturum.dart';
import '../models/yonetim.dart';
import '../models/yakalama.dart';
import 'token_depo.dart';
import 'token_interceptor.dart';

/// Builds the [Dio] used for all API calls: base URL plus [TokenInterceptor].
Dio apiDioOlustur({
  required String apiUrl,
  required TokenDepo depo,
  required void Function() oturumKapandi,
}) {
  final dio = Dio(BaseOptions(
    baseUrl: apiUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));
  dio.interceptors.add(TokenInterceptor(dio: dio, depo: depo, oturumKapandi: oturumKapandi));
  return dio;
}

/// One method per endpoint of the API contract
/// (docs/planlar/aliskanlik-takibi.md).
class ApiService {
  ApiService(this._dio);

  final Dio _dio;

  // ---- Account (Identity API) ----

  Future<GirisYaniti> girisYap(GirisIstegi istek) async {
    final yanit = await _dio.post<Map<String, dynamic>>(
      TokenInterceptor.loginYolu,
      data: istek.toJson(),
      options: Options(extra: {TokenInterceptor.girissizAnahtari: true}),
    );
    return GirisYaniti.fromJson(yanit.data!);
  }

  /// Who is signed in and with which roles (drives the Sahip-only screens).
  Future<Ben> ben() async {
    final yanit = await _dio.get<Map<String, dynamic>>('/api/ben');
    return Ben.fromJson(yanit.data!);
  }

  /// Lowest app build number the API accepts (anonymous; no token, no refresh).
  Future<int> enAzMobilSurumKodu() async {
    final yanit = await _dio.get<Map<String, dynamic>>(
      '/api/surum',
      options: Options(extra: {TokenInterceptor.girissizAnahtari: true}),
    );
    return yanit.data!['enAzMobilSurumKodu'] as int;
  }

  // ---- Habits ----

  Future<List<Aliskanlik>> aliskanliklariGetir({bool arsiv = false}) async {
    // arsiv=true is assumed to return the archived ones (contract is silent).
    final yanit = await _dio.get<List<dynamic>>(
      '/api/aliskanliklar',
      queryParameters: {'arsiv': arsiv},
    );
    return _liste(yanit, Aliskanlik.fromJson);
  }

  Future<Aliskanlik> aliskanlikGetir(String id) async {
    final yanit = await _dio.get<Map<String, dynamic>>('/api/aliskanliklar/$id');
    return Aliskanlik.fromJson(yanit.data!);
  }

  /// 201, or 200 with the existing record when the same `id` was sent before.
  Future<Aliskanlik> aliskanlikOlustur(AliskanlikYaz yaz) async {
    final yanit = await _dio.post<Map<String, dynamic>>('/api/aliskanliklar', data: yaz.toJson());
    return Aliskanlik.fromJson(yanit.data!);
  }

  Future<Aliskanlik> aliskanlikGuncelle(String id, AliskanlikYaz yaz) async {
    final yanit = await _dio.put<Map<String, dynamic>>('/api/aliskanliklar/$id', data: yaz.toJson());
    return Aliskanlik.fromJson(yanit.data!);
  }

  Future<void> aliskanlikSil(String id) => _dio.delete<void>('/api/aliskanliklar/$id');

  // ---- Daily records (Sayac) and days ----

  /// Writes the day's total (not an increment); idempotent.
  Future<Gun> gunYaz(String aliskanlikId, DateTime tarih, GunYaz yaz) async {
    final yanit = await _dio.put<Map<String, dynamic>>(
      '/api/aliskanliklar/$aliskanlikId/kayitlar/${tarihMetni(tarih)}',
      data: yaz.toJson(),
    );
    return Gun.fromJson(yanit.data!);
  }

  Future<void> gunSil(String aliskanlikId, DateTime tarih) =>
      _dio.delete<void>('/api/aliskanliklar/$aliskanlikId/kayitlar/${tarihMetni(tarih)}');

  Future<List<Gun>> gunleriGetir(String aliskanlikId, DateTime baslangic, DateTime bitis) async {
    final yanit = await _dio.get<List<dynamic>>(
      '/api/aliskanliklar/$aliskanlikId/gunler',
      queryParameters: {'baslangic': tarihMetni(baslangic), 'bitis': tarihMetni(bitis)},
    );
    return _liste(yanit, Gun.fromJson);
  }

  // ---- Shelf items ----

  Future<List<Oge>> ogeleriGetir(String aliskanlikId, {OgeDurumu? durum}) async {
    final yanit = await _dio.get<List<dynamic>>(
      '/api/aliskanliklar/$aliskanlikId/ogeler',
      queryParameters: {if (durum != null) 'durum': _enumMetni(durum)},
    );
    return _liste(yanit, Oge.fromJson);
  }

  /// 201, or 200 with the existing item when the same `id` was sent before.
  Future<Oge> ogeOlustur(String aliskanlikId, OgeYaz yaz) async {
    final yanit = await _dio.post<Map<String, dynamic>>(
      '/api/aliskanliklar/$aliskanlikId/ogeler',
      data: yaz.toJson(),
    );
    return Oge.fromJson(yanit.data!);
  }

  Future<Oge> ogeGetir(String id) async {
    final yanit = await _dio.get<Map<String, dynamic>>('/api/ogeler/$id');
    return Oge.fromJson(yanit.data!);
  }

  Future<Oge> ogeGuncelle(String id, OgeYaz yaz) async {
    final yanit = await _dio.put<Map<String, dynamic>>('/api/ogeler/$id', data: yaz.toJson());
    return Oge.fromJson(yanit.data!);
  }

  Future<void> ogeSil(String id) => _dio.delete<void>('/api/ogeler/$id');

  // ---- Sessions (Raf) ----

  /// Newest first.
  Future<List<Oturum>> oturumlariGetir(String ogeId) async {
    final yanit = await _dio.get<List<dynamic>>('/api/ogeler/$ogeId/oturumlar');
    return _liste(yanit, Oturum.fromJson);
  }

  /// 201, or 200 with the existing session when the same `id` was sent before.
  Future<Oturum> oturumEkle(String ogeId, OturumEkle ekle) async {
    final yanit = await _dio.post<Map<String, dynamic>>(
      '/api/ogeler/$ogeId/oturumlar',
      data: ekle.toJson(),
    );
    return Oturum.fromJson(yanit.data!);
  }

  /// 409 if the session is not the last one.
  Future<Oturum> oturumGuncelle(String id, OturumGuncelle guncelle) async {
    final yanit = await _dio.put<Map<String, dynamic>>('/api/oturumlar/$id', data: guncelle.toJson());
    return Oturum.fromJson(yanit.data!);
  }

  /// 409 if the session is not the last one.
  Future<void> oturumSil(String id) => _dio.delete<void>('/api/oturumlar/$id');

  // ---- Captures ----

  /// Newest first (by the phone's capture time).
  Future<List<Yakalama>> yakalamalariGetir() async {
    final yanit = await _dio.get<List<dynamic>>('/api/yakalamalar');
    return _liste(yanit, Yakalama.fromJson);
  }

  /// 201, or 200 with the existing capture when the same `id` was sent before.
  Future<Yakalama> yakalamaOlustur(YakalamaYaz yaz) async {
    final yanit = await _dio.post<Map<String, dynamic>>('/api/yakalamalar', data: yaz.toJson());
    return Yakalama.fromJson(yanit.data!);
  }

  /// 409 once the capture left `bekliyor`.
  Future<Yakalama> yakalamaGuncelle(String id, YakalamaYaz yaz) async {
    final yanit = await _dio.put<Map<String, dynamic>>('/api/yakalamalar/$id', data: yaz.toJson());
    return Yakalama.fromJson(yanit.data!);
  }

  /// 409 once the capture left `bekliyor`; the server removes its photo too.
  Future<void> yakalamaSil(String id) => _dio.delete<void>('/api/yakalamalar/$id');

  // ---- Second brain (read only, /api/beyin) ----
  // 503: the brain is not set up on the server; 403: no `beyin.oku` permission.

  Future<List<ProjeOzet>> beyinProjeleri() async {
    final yanit = await _dio.get<List<dynamic>>('/api/beyin/projeler');
    return _liste(yanit, ProjeOzet.fromJson);
  }

  Future<ProjeDetay> beyinProje(String kimlik) async {
    final yanit = await _dio.get<Map<String, dynamic>>('/api/beyin/projeler/${Uri.encodeComponent(kimlik)}');
    return ProjeDetay.fromJson(yanit.data!);
  }

  Future<BeyinGun> beyinGun(DateTime tarih) async {
    final yanit = await _dio.get<Map<String, dynamic>>('/api/beyin/gunler/${tarihMetni(tarih)}');
    return BeyinGun.fromJson(yanit.data!);
  }

  Future<List<AramaSonucu>> beyinAra(String q, {String? proje, int? limit}) async {
    final yanit = await _dio.get<List<dynamic>>(
      '/api/beyin/ara',
      queryParameters: {'q': q, 'proje': ?proje, 'limit': ?limit},
    );
    return _liste(yanit, AramaSonucu.fromJson);
  }

  Future<BeyinNotu> beyinNot(String yol) async {
    final yanit = await _dio.get<Map<String, dynamic>>('/api/beyin/not', queryParameters: {'yol': yol});
    return BeyinNotu.fromJson(yanit.data!);
  }

  // ---- Management (Sahip only, /api/yonetim) ----

  Future<List<Izin>> izinleriGetir() async {
    final yanit = await _dio.get<List<dynamic>>('/api/yonetim/izinler');
    return _liste(yanit, Izin.fromJson);
  }

  /// Opens or closes one permission of the Asistan; takes effect on its next request.
  Future<Izin> izinAyarla(String izin, {required bool acik}) async {
    final yanit = await _dio.put<Map<String, dynamic>>('/api/yonetim/izinler/$izin', data: {'acik': acik});
    return Izin.fromJson(yanit.data!);
  }

  Future<YonetimBeyinDurumu> yonetimBeyinDurumu() async {
    final yanit = await _dio.get<Map<String, dynamic>>('/api/yonetim/beyin');
    return YonetimBeyinDurumu.fromJson(yanit.data!);
  }

  /// Every capture, the ones that need a look first.
  Future<List<Gonderim>> gonderimKuyrugu() async {
    final yanit = await _dio.get<List<dynamic>>('/api/yonetim/gonderim');
    return _liste(yanit, Gonderim.fromJson);
  }

  /// 409 while the server is sending it right now, or once it left `bekliyor`.
  Future<Gonderim> gonderimiYenidenDene(String id) async {
    final yanit = await _dio.post<Map<String, dynamic>>('/api/yonetim/gonderim/$id/yeniden-dene');
    return Gonderim.fromJson(yanit.data!);
  }

  // ---- Files ----

  Future<DosyaYaniti> dosyaYukle(String yol, {String? dosyaAdi}) async {
    final form = FormData.fromMap({
      'dosya': await MultipartFile.fromFile(yol, filename: dosyaAdi),
    });
    final yanit = await _dio.post<Map<String, dynamic>>('/api/dosyalar', data: form);
    return DosyaYaniti.fromJson(yanit.data!);
  }

  /// Image bytes; the bearer token is added by the interceptor.
  Future<Uint8List> dosyaGetir(String id) async {
    final yanit = await _dio.get<List<int>>(
      '/api/dosyalar/$id',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(yanit.data!);
  }

  // ---- Helpers ----

  List<T> _liste<T>(Response<List<dynamic>> yanit, T Function(Map<String, dynamic>) coz) =>
      [for (final e in yanit.data!) coz(e as Map<String, dynamic>)];

  /// Wire value of an enum (the enum names equal the contract's strings).
  String _enumMetni(Enum e) => e.name;
}
