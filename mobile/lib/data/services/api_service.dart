import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../utils/aliskanlik_gunu.dart';
import '../models/aliskanlik.dart';
import '../models/asistan.dart';
import '../models/bildirim_ogesi.dart';
import '../models/ben.dart';
import '../models/beyin.dart';
import '../models/beyin_yazma.dart';
import '../models/proje_repo.dart';
import '../models/brifing.dart';
import '../models/enums.dart';
import '../models/eylem.dart';
import '../models/gelen.dart';
import '../models/gun_gorunum.dart';
import '../models/giris.dart';
import '../models/hatirlatici.dart';
import '../models/gun.dart';
import '../models/is_karti.dart';
import '../models/oge.dart';
import '../models/oturum.dart';
import '../models/ses.dart';
import '../models/sunucu_bildirimi.dart';
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

  /// Changes the signed-in user's own password (Identity's manage endpoint). A wrong current password or a
  /// password that breaks the rules is a 400 with Turkish messages. The server renews the security stamp, so the
  /// refresh token held before is refused afterwards: the caller signs in again with the new password.
  Future<void> sifreDegistir({required String mevcutSifre, required String yeniSifre}) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/hesap/manage/info',
      data: {'oldPassword': mevcutSifre, 'newPassword': yeniSifre},
    );
  }

  /// Lowest app build number the API accepts (anonymous; no token, no refresh).
  Future<int> enAzMobilSurumKodu() async {
    final yanit = await _dio.get<Map<String, dynamic>>(
      '/api/surum',
      options: Options(extra: {TokenInterceptor.girissizAnahtari: true}),
    );
    return yanit.data!['enAzMobilSurumKodu'] as int;
  }

  // ---- Push (FCM) ----

  /// Registers this phone's FCM token for the signed-in user; the same token again only refreshes the row.
  Future<void> bildirimCihazKaydet({required String token, String? cihazAdi}) async {
    await _dio.post<void>('/api/bildirim/cihaz', data: {'token': token, 'cihazAdi': ?cihazAdi});
  }

  /// Removes the token (sign-out). A token the server no longer knows is not an error.
  Future<void> bildirimCihazSil(String token) async {
    await _dio.delete<void>('/api/bildirim/cihaz', data: {'token': token});
  }

  /// The text of the notification the server woke the phone for (404: not this user's, or gone).
  Future<SunucuBildirimi> sunucuBildirimiGetir(String id) async {
    final yanit = await _dio.get<Map<String, dynamic>>('/api/bildirimler/$id');
    return SunucuBildirimi.fromJson(yanit.data!);
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

  // ---- Reminders ----

  /// `GET /api/hatirlaticilar` (all statuses, sorted by the effective moment).
  Future<List<Hatirlatici>> hatirlaticilariGetir() async {
    final yanit = await _dio.get<List<dynamic>>('/api/hatirlaticilar');
    return _liste(yanit, Hatirlatici.fromJson);
  }

  /// `POST /api/hatirlaticilar`; the same client id twice returns the existing record (200).
  Future<Hatirlatici> hatirlaticiOlustur(HatirlaticiYaz yaz) async {
    final yanit = await _dio.post<Map<String, dynamic>>('/api/hatirlaticilar', data: yaz.toJson());
    return Hatirlatici.fromJson(yanit.data!);
  }

  Future<Hatirlatici> hatirlaticiGuncelle(String id, HatirlaticiYaz yaz) async {
    final yanit = await _dio.put<Map<String, dynamic>>('/api/hatirlaticilar/$id', data: yaz.toJson());
    return Hatirlatici.fromJson(yanit.data!);
  }

  Future<void> hatirlaticiSil(String id) => _dio.delete<void>('/api/hatirlaticilar/$id');

  Future<Hatirlatici> hatirlaticiYaptim(String id) async {
    final yanit = await _dio.post<Map<String, dynamic>>('/api/hatirlaticilar/$id/yaptim');
    return Hatirlatici.fromJson(yanit.data!);
  }

  /// [sure] is `1s` or `yarin` ([ErteleSuresi]).
  Future<Hatirlatici> hatirlaticiErtele(String id, String sure) async {
    final yanit = await _dio.post<Map<String, dynamic>>('/api/hatirlaticilar/$id/ertele', data: {'sure': sure});
    return Hatirlatici.fromJson(yanit.data!);
  }

  // ---- Approval queue (/api/eylemler, K2.6) ----

  /// `GET /api/eylemler?durum=` (newest decision first). 403 without the `eylem.oku` permission.
  Future<List<Eylem>> eylemleriGetir(EylemDurumu durum) async {
    final yanit = await _dio.get<List<dynamic>>('/api/eylemler', queryParameters: {'durum': _enumMetni(durum)});
    return _liste(yanit, Eylem.fromJson);
  }

  /// Approves an action; with [yuk] the corrected payload is applied (the server checks it again: 400).
  /// 409 when it is not waiting any more.
  Future<Eylem> eylemUygula(String id, {Map<String, dynamic>? yuk}) async {
    final yanit = await _dio.post<Map<String, dynamic>>('/api/eylemler/$id/uygula', data: {'yuk': ?yuk});
    return Eylem.fromJson(yanit.data!);
  }

  /// Rejects an action; [birDahaOnerme] also makes its kind `yasak` for good. 409 when it is not waiting any more.
  Future<Eylem> eylemReddet(String id, {bool birDahaOnerme = false}) async {
    final yanit = await _dio.post<Map<String, dynamic>>('/api/eylemler/$id/reddet', data: {'birDahaOnerme': birDahaOnerme});
    return Eylem.fromJson(yanit.data!);
  }

  /// 409 unless the action was applied.
  Future<Eylem> eylemGeriAl(String id) async {
    final yanit = await _dio.post<Map<String, dynamic>>('/api/eylemler/$id/geri-al');
    return Eylem.fromJson(yanit.data!);
  }

  // ---- Inbox (/api/gelen, K2.2) ----

  /// `GET /api/gelen`: the cards in the brain's inbox (hidden ones never come), each with its waiting suggestion.
  /// 403 without the `gelen.oku` permission, 503 when the brain is not set up.
  Future<List<GelenKarti>> gelenGetir() async {
    final yanit = await _dio.get<List<dynamic>>('/api/gelen');
    return _liste(yanit, GelenKarti.fromJson);
  }

  /// `GET /api/gelen/etiketler`: the dictionary's main tags with their synonyms (`gelen.oku`).
  Future<List<GelenEtiket>> gelenEtiketleri() async {
    final yanit = await _dio.get<List<dynamic>>('/api/gelen/etiketler');
    return _liste(yanit, GelenEtiket.fromJson);
  }

  /// `GET /api/gelen/klasorler`: the folders a card may be placed in (`gelen.oku`).
  Future<List<GelenKlasoru>> gelenKlasorleri() async {
    final yanit = await _dio.get<List<dynamic>>('/api/gelen/klasorler');
    return _liste(yanit, GelenKlasoru.fromJson);
  }

  /// `POST /api/gelen/{kart}/isle`: places the card by hand. 400 when the path or a tag breaks the rules, 404 when the
  /// card is gone.
  Future<void> gelenIsle(String kart, GelenIsleGirdi girdi) async {
    await _dio.post<Map<String, dynamic>>('/api/gelen/${Uri.encodeComponent(kart)}/isle', data: girdi.toJson());
  }

  /// `DELETE /api/gelen/{kart}` (the Sahip only). 404 when the card is gone.
  Future<void> gelenSil(String kart) async {
    await _dio.delete<Map<String, dynamic>>('/api/gelen/${Uri.encodeComponent(kart)}');
  }

  /// `POST /api/gelen/{kart}/oneri`: asks Claude again now. The server answers when Claude is done, which can take
  /// a couple of minutes, so the wait is longer than for the other calls. 409 when a suggestion already waits,
  /// 422 when the card may not be sent, 429 at the daily cap, 503 when Claude is off.
  Future<GelenOneriYaniti> gelenOner(String kart) async {
    final yanit = await _dio.post<Map<String, dynamic>>(
      '/api/gelen/${Uri.encodeComponent(kart)}/oneri',
      options: Options(receiveTimeout: const Duration(seconds: 150)),
    );
    return GelenOneriYaniti.fromJson(yanit.data!);
  }

  // ---- Voice and text (K2.4) ----
  // The phone turns speech into text; only the text is sent. 403: no `asistan.kullan` permission, 503: Claude is not set
  // up, 429: the daily Claude cap, 502: Claude's answer was unusable.

  /// `POST /api/is-cikar`: what could be done with [metin]. Saves nothing. The server waits for Claude, so the wait is
  /// longer than for the other calls. 400 when the text is empty or over about 4000 characters.
  Future<IsCikarYaniti> isCikar(String metin) async {
    final yanit = await _dio.post<Map<String, dynamic>>(
      '/api/is-cikar',
      data: {'metin': metin},
      options: Options(receiveTimeout: const Duration(seconds: 150)),
    );
    return IsCikarYaniti.fromJson(yanit.data!);
  }

  /// `POST /api/is-cikar/uygula`: applies the suggestions the person picked, one by one. 200 when all went through, 207
  /// when some did not; both are answers (the results tell them apart), the applied ones stay applied.
  Future<IsCikarUygulaYaniti> isCikarUygula(List<IsOnerisi> secilenler) async {
    final yanit = await _dio.post<Map<String, dynamic>>(
      '/api/is-cikar/uygula',
      data: {
        'secilenler': [for (final s in secilenler) s.toJson()],
      },
    );
    return IsCikarUygulaYaniti.fromJson(yanit.data!);
  }

  // ---- Morning briefing (K2.7) ----
  // Needs the `brifing.oku` permission (403 without). 404 before the briefing hour, 503 when it could not be made.

  /// `GET /api/brifing/bugun`: today's briefing; the server makes it now if the hour has passed and none exists yet.
  Future<Brifing> brifingBugun() async {
    final yanit = await _dio.get<Map<String, dynamic>>(
      '/api/brifing/bugun',
      options: Options(receiveTimeout: const Duration(seconds: 150)),
    );
    return Brifing.fromJson(yanit.data!);
  }

  /// `POST /api/brifing/{gun}/kartlar/{sira}/oy`: [oy] is 1, -1, or 0 to take the vote back.
  Future<Brifing> brifingOyVer(String gun, int sira, int oy) async {
    final yanit = await _dio.post<Map<String, dynamic>>('/api/brifing/$gun/kartlar/$sira/oy', data: {'oy': oy});
    return Brifing.fromJson(yanit.data!);
  }

  /// `POST /api/brifing/bugun/yenile` (the Sahip; three times a day at most, 429 after that).
  Future<Brifing> brifingYenile() async {
    final yanit = await _dio.post<Map<String, dynamic>>(
      '/api/brifing/bugun/yenile',
      options: Options(receiveTimeout: const Duration(seconds: 150)),
    );
    return Brifing.fromJson(yanit.data!);
  }

  // ---- Timeline (K2.3c) ----
  // Needs the `takvim.oku` permission (403 without).

  /// `POST /api/metin/yeniden-yaz`: the text as a summary or a bullet list. Saves nothing.
  Future<String> metniYenidenYaz(String metin, YenidenYazKipi kip) async {
    final yanit = await _dio.post<Map<String, dynamic>>(
      '/api/metin/yeniden-yaz',
      data: {'metin': metin, 'kip': kip.name},
      options: Options(receiveTimeout: const Duration(seconds: 150)),
    );
    return yanit.data!['metin'] as String;
  }

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

  /// `GET /api/beyin/projeler/{kimlik}/repo`: the repository card; null when no repository is linked to the project (404).
  Future<ProjeRepoOzeti?> beyinProjeRepo(String kimlik) async {
    try {
      final yanit = await _dio.get<Map<String, dynamic>>('/api/beyin/projeler/${Uri.encodeComponent(kimlik)}/repo');
      return ProjeRepoOzeti.fromJson(yanit.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<AramaSonucu>> beyinAra(String q, {String? proje, int? limit}) async {
    final yanit = await _dio.get<List<dynamic>>(
      '/api/beyin/ara',
      queryParameters: {'q': q, 'proje': ?proje, 'limit': ?limit},
    );
    return _liste(yanit, AramaSonucu.fromJson);
  }

  /// A plan or task write (`POST /api/beyin/...`, K2.3a). [anahtar] is the `Idempotency-Key`: the same key sent twice is
  /// applied once, the second send gets the first answer. 200 written, 202 the brain's answer was unclear (the write may
  /// have happened), 207 a split stopped half way: all three are accepted answers, told apart in the result. 4xx/5xx are
  /// thrown as [DioException] (nothing was written for those).
  Future<BeyinYazmaSonucu> beyinYaz(String yol, Map<String, dynamic> govde, {required String anahtar}) async {
    final yanit = await _dio.post<Object>(
      yol,
      data: govde,
      options: Options(headers: {'Idempotency-Key': anahtar}),
    );
    return BeyinYazmaSonucu.durumKodundan(yanit.statusCode, yanit.data);
  }

  Future<BeyinNotu> beyinNot(String yol) async {
    final yanit = await _dio.get<Map<String, dynamic>>('/api/beyin/not', queryParameters: {'yol': yol});
    return BeyinNotu.fromJson(yanit.data!);
  }

  // ---- Work cards (/api/isler, backend/Isler) ----
  // 403: no `isler.oku` / `isler.yaz` permission; 503: the brain is not set up. A refusal of the brain is a ProblemDetails whose
  // `detail` is a sentence for the person (409: the card cannot do that now, 404: no such card).

  /// The open cards, newest update first; [kapali] adds the ones finished this week.
  Future<List<IsKarti>> islerGetir({bool kapali = false}) async {
    final yanit = await _dio.get<List<dynamic>>('/api/isler', queryParameters: {if (kapali) 'kapali': true});
    return _liste(yanit, IsKarti.fromJson);
  }

  Future<IsAyrinti> isGetir(String kimlik) async {
    final yanit = await _dio.get<Map<String, dynamic>>('/api/isler/${Uri.encodeComponent(kimlik)}');
    return IsAyrinti.fromJson(yanit.data!);
  }

  /// A write on a card (open, answer, stage, note). [anahtar] is the `Idempotency-Key` (see [beyinYaz]); the answer's `govde` is the card.
  Future<BeyinYazmaSonucu> isYaz(String yol, Map<String, dynamic> govde, {required String anahtar}) => beyinYaz(yol, govde, anahtar: anahtar);

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

  /// Sets a new password for the Asistan without the old one (204). 400 with Turkish messages when it breaks
  /// the rules. The Asistan's sessions are closed on the server.
  Future<void> asistaninSifresiniYenile(String yeniSifre) =>
      _dio.put<void>('/api/yonetim/asistan/sifre', data: {'yeniSifre': yeniSifre});

  /// The mode of every kind of action the Asistan may suggest.
  Future<List<EylemKipDurumu>> eylemKipleriniGetir() async {
    final yanit = await _dio.get<List<dynamic>>('/api/yonetim/eylem-izinleri');
    return _liste(yanit, EylemKipDurumu.fromJson);
  }

  Future<EylemKipDurumu> eylemKipiAyarla(String tur, EylemKipi kip) async {
    final yanit = await _dio.put<Map<String, dynamic>>('/api/yonetim/eylem-izinleri/$tur', data: {'kip': _enumMetni(kip)});
    return EylemKipDurumu.fromJson(yanit.data!);
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

  /// `GET /api/asistan/durum`: whether Claude is set up on the server. False when it is not, and also when the
  /// answer cannot be had (offline, no `asistan.kullan` permission): the buttons that need Claude then stay hidden.
  Future<bool> asistanBagliMi() async {
    try {
      final yanit = await _dio.get<Map<String, dynamic>>('/api/asistan/durum');
      return yanit.data?['bagli'] == true;
    } on DioException {
      return false;
    }
  }

  // ---- Google Calendar (Sahip only, /api/google) ----

  Future<GoogleDurum> googleDurumu() async {
    final yanit = await _dio.get<Map<String, dynamic>>('/api/google/durum');
    return GoogleDurum.fromJson(yanit.data!);
  }

  /// A sync round now. 503 when the Google settings are missing, 409 when Google refuses the access.
  Future<GoogleEsitlemeOzeti> googleEsitle() async {
    final yanit = await _dio.post<Map<String, dynamic>>('/api/google/esitle');
    return GoogleEsitlemeOzeti.fromJson(yanit.data!);
  }

  // ---- Day view, calendar and settings of the UI revision (K-0024, docs/planlar/ui-revizyon/sozlesme.md) ----

  /// `GET /api/gun/{tarih}`: [tarih] is `yyyy-MM-dd` or `bugun`.
  Future<GunGorunum> gunGorunumu(String tarih) async {
    final yanit = await _dio.get<Map<String, dynamic>>('/api/gun/$tarih');
    return GunGorunum.fromJson(yanit.data!);
  }

  /// `POST /api/gun/{tarih}/yaptim`: the one "done" for any kind of row. [anahtar] is the `Idempotency-Key`.
  Future<YaptimYaniti> gunYaptim(String tarih, String kimlik, {bool geri = false, required String anahtar}) async {
    final yanit = await _dio.post<Map<String, dynamic>>(
      '/api/gun/$tarih/yaptim',
      data: {'kimlik': kimlik, 'geri': geri},
      options: Options(headers: {'Idempotency-Key': anahtar}),
    );
    return YaptimYaniti.fromJson(yanit.data!);
  }

  /// `POST /api/gun/{tarih}/dunden/{maddeId}/birak`: yesterday's open item is let go (nothing is written to the brain).
  Future<void> dundenBirak(String tarih, String maddeId) =>
      _dio.post<void>('/api/gun/$tarih/dunden/${Uri.encodeComponent(maddeId)}/birak');

  /// `POST /api/gun/{tarih}/ogeler`: a new "yapılacak", with a reminder when the body carries one.
  Future<Yapilacak> gunOgeEkle(String tarih, YeniOgeYaz yaz, {required String anahtar}) async {
    final yanit = await _dio.post<Map<String, dynamic>>(
      '/api/gun/$tarih/ogeler',
      data: yaz.toJson(),
      options: Options(headers: {'Idempotency-Key': anahtar}),
    );
    return Yapilacak.fromJson(yanit.data!);
  }

  /// `POST` (set up) or `PUT` (change) `/api/gun/{tarih}/ogeler/{kimlik}/hatirlatici`: the reminder tied to a row.
  Future<void> ogeHatirlaticiYaz(String tarih, String kimlik, HatirlaticiGovde govde, {required bool guncelle}) {
    final yol = '/api/gun/$tarih/ogeler/${Uri.encodeComponent(kimlik)}/hatirlatici';
    return guncelle ? _dio.put<void>(yol, data: govde.toJson()) : _dio.post<void>(yol, data: govde.toJson());
  }

  /// `DELETE /api/gun/{tarih}/ogeler/{kimlik}/hatirlatici`.
  Future<void> ogeHatirlaticiSil(String tarih, String kimlik) =>
      _dio.delete<void>('/api/gun/$tarih/ogeler/${Uri.encodeComponent(kimlik)}/hatirlatici');

  /// `GET /api/takvim?baslangic=&bitis=` (at most 42 days).
  Future<TakvimAraligi> takvimAraligi(DateTime baslangic, DateTime bitis) async {
    final yanit = await _dio.get<Map<String, dynamic>>(
      '/api/takvim',
      queryParameters: {'baslangic': tarihMetni(baslangic), 'bitis': tarihMetni(bitis)},
    );
    return TakvimAraligi.fromJson(yanit.data!);
  }

  /// `GET /api/ayarlar/gun`.
  Future<GunAyari> gunAyari() async {
    final yanit = await _dio.get<Map<String, dynamic>>('/api/ayarlar/gun');
    return GunAyari.fromJson(yanit.data!);
  }

  /// `PUT /api/ayarlar/gun` (Sahip).
  Future<void> gunAyariYaz(GunAyari ayar) => _dio.put<void>('/api/ayarlar/gun', data: ayar.toJson());

  /// `GET /api/bildirimler/sayi`: how many notifications are unread (the badge on the bell).
  Future<int> bildirimSayisi() async {
    final yanit = await _dio.get<Map<String, dynamic>>('/api/bildirimler/sayi');
    return (yanit.data?['okunmamis'] as num?)?.toInt() ?? 0;
  }

  /// `POST /api/gun/{tarih}/devret` (sözleşme E2): the row [kimlik] goes to the next day. Answers the row of the new day.
  Future<Yapilacak> gunDevret(String tarih, String kimlik, {required String anahtar}) async {
    final yanit = await _dio.post<Map<String, dynamic>>(
      '/api/gun/$tarih/devret',
      data: {'kimlik': kimlik},
      options: Options(headers: {'Idempotency-Key': anahtar}),
    );
    return Yapilacak.fromJson((yanit.data!['oge'] ?? yanit.data!) as Map<String, dynamic>);
  }

  // ---- Notification centre (sözleşme §6) ----

  /// `GET /api/bildirimler?once=&limit=`: newest first, only this person's.
  Future<List<BildirimOgesi>> bildirimleriGetir({DateTime? once, int limit = 30}) async {
    final yanit = await _dio.get<List<dynamic>>(
      '/api/bildirimler',
      queryParameters: {'limit': limit, if (once != null) 'once': once.toUtc().toIso8601String()},
    );
    return _liste(yanit, BildirimOgesi.fromJson);
  }

  /// `POST /api/bildirimler/{id}/okundu`.
  Future<void> bildirimOkundu(String id) => _dio.post<void>('/api/bildirimler/${Uri.encodeComponent(id)}/okundu');

  /// `POST /api/bildirimler/okundu`: all of them.
  Future<void> bildirimlerinHepsiOkundu() => _dio.post<void>('/api/bildirimler/okundu');

  // ---- Assistant (sözleşme §7) ----

  /// `POST /api/asistan/girdi`: the one input. The same [AsistanGirdisi.id] again gets the same answer.
  Future<AsistanYaniti> asistanGirdi(AsistanGirdisi girdi) async {
    final yanit = await _dio.post<Map<String, dynamic>>('/api/asistan/girdi', data: girdi.toJson());
    return AsistanYaniti.fromJson(yanit.data!);
  }

  /// `POST /api/asistan/sorular/{id}/cevap`.
  Future<AsistanYaniti> asistanSoruCevap(String soruId, String cevap) async {
    final yanit = await _dio.post<Map<String, dynamic>>(
      '/api/asistan/sorular/${Uri.encodeComponent(soruId)}/cevap',
      data: {'cevap': cevap},
    );
    return AsistanYaniti.fromJson(yanit.data!);
  }

  /// `GET /api/asistan/akis?once=&limit=&suzgec=`: newest first.
  Future<List<AkisOgesi>> asistanAkis({DateTime? once, int limit = 40, String suzgec = AkisSuzgeci.hepsi}) async {
    final yanit = await _dio.get<List<dynamic>>(
      '/api/asistan/akis',
      queryParameters: {'limit': limit, 'suzgec': suzgec, if (once != null) 'once': once.toUtc().toIso8601String()},
    );
    return _liste(yanit, AkisOgesi.fromJson);
  }

  /// `GET /api/asistan/sayi`: how many things wait on the person (the badge of the Asistan tab).
  Future<int> asistanSayi() async {
    final yanit = await _dio.get<Map<String, dynamic>>('/api/asistan/sayi');
    return (yanit.data?['bekleyen'] as num?)?.toInt() ?? 0;
  }

  // ---- Helpers ----

  List<T> _liste<T>(Response<List<dynamic>> yanit, T Function(Map<String, dynamic>) coz) =>
      [for (final e in yanit.data!) coz(e as Map<String, dynamic>)];

  /// Wire value of an enum (the enum names equal the contract's strings).
  String _enumMetni(Enum e) => e.name;
}
