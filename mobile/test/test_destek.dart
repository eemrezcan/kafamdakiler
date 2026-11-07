import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:kafamdakiler/data/models/aliskanlik.dart';
import 'package:kafamdakiler/data/models/ben.dart';
import 'package:kafamdakiler/data/models/beyin.dart';
import 'package:kafamdakiler/data/models/beyin_yazma.dart';
import 'package:kafamdakiler/data/models/brifing.dart';
import 'package:kafamdakiler/data/models/zaman_cizelgesi.dart';
import 'package:kafamdakiler/data/repositories/zaman_cizelgesi_repository.dart';
import 'package:kafamdakiler/data/models/enums.dart';
import 'package:kafamdakiler/data/models/eylem.dart';
import 'package:kafamdakiler/data/models/gelen.dart';
import 'package:kafamdakiler/data/models/gun.dart';
import 'package:kafamdakiler/data/models/hatirlatici.dart';
import 'package:kafamdakiler/data/models/oge.dart';
import 'package:kafamdakiler/data/models/giris.dart';
import 'package:kafamdakiler/data/models/oturum.dart';
import 'package:kafamdakiler/data/models/ses.dart';
import 'package:kafamdakiler/data/models/yakalama.dart';
import 'package:kafamdakiler/data/models/yonetim.dart';
import 'package:kafamdakiler/data/repositories/aliskanlik_repository.dart';
import 'package:kafamdakiler/data/repositories/beyin_repository.dart';
import 'package:kafamdakiler/data/repositories/brifing_repository.dart';
import 'package:kafamdakiler/data/repositories/esitleyici.dart';
import 'package:kafamdakiler/data/repositories/gun_plani_repository.dart';
import 'package:kafamdakiler/data/repositories/eylem_repository.dart';
import 'package:kafamdakiler/data/repositories/gelen_repository.dart';
import 'package:kafamdakiler/data/repositories/hatirlatici_repository.dart';
import 'package:kafamdakiler/data/repositories/yakalama_repository.dart';
import 'package:kafamdakiler/data/services/api_service.dart';
import 'package:kafamdakiler/data/services/bildirim_servisi.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';
import 'package:kafamdakiler/data/services/fotograf_deposu.dart';
import 'package:kafamdakiler/utils/aliskanlik_gunu.dart';
import 'package:kafamdakiler/utils/bildirim_plani.dart';

/// An [ApiService] that answers from memory. With [cevrimdisi] every call
/// fails like a lost connection.
class SahteApi extends ApiService {
  SahteApi({this.aliskanliklar = const [], this.ogeler = const [], this.ben_, this.gunler = const {}}) : super(Dio());

  List<Aliskanlik> aliskanliklar;

  /// Days per habit id for `/gunler`; a habit not in the map gets none.
  Map<String, List<Gun>> gunler;
  List<Oge> ogeler;
  Ben? ben_;

  /// Server captures for `/api/yakalamalar`.
  List<Yakalama> yakalamalar = [];
  bool cevrimdisi = false;

  /// When set, every call fails with this HTTP status.
  int? sunucuHatasi;

  final List<String> cagrilar = [];

  void _kontrol(String ad) {
    cagrilar.add(ad);
    if (sunucuHatasi != null) {
      final istek = RequestOptions(path: ad);
      throw DioException.badResponse(
        statusCode: sunucuHatasi!,
        requestOptions: istek,
        response: Response(requestOptions: istek, statusCode: sunucuHatasi),
      );
    }
    if (cevrimdisi) {
      throw DioException.connectionError(requestOptions: RequestOptions(path: ad), reason: 'offline');
    }
  }

  @override
  Future<Ben> ben() async {
    _kontrol('ben');
    return ben_!;
  }

  // Only recorded, never failed: the sign-in after a password change must not depend on the other switches.
  @override
  Future<GirisYaniti> girisYap(GirisIstegi istek) async {
    cagrilar.add('girisYap:${istek.email}:${istek.password}');
    return const GirisYaniti(tokenType: 'Bearer', accessToken: 'yeni-a', expiresIn: 3600, refreshToken: 'yeni-r');
  }

  @override
  Future<List<Aliskanlik>> aliskanliklariGetir({bool arsiv = false}) async {
    _kontrol('aliskanliklariGetir');
    return aliskanliklar;
  }

  // Not recorded in [cagrilar]: the Today tab fetches days in the background
  // after the list, and the call-order tests are about the list itself.
  @override
  Future<List<Gun>> gunleriGetir(String aliskanlikId, DateTime baslangic, DateTime bitis) async {
    if (cevrimdisi || sunucuHatasi != null) {
      throw DioException.connectionError(requestOptions: RequestOptions(path: 'gunler'), reason: 'offline');
    }
    return gunler[aliskanlikId] ?? const [];
  }

  @override
  Future<List<Oge>> ogeleriGetir(String aliskanlikId, {OgeDurumu? durum}) async {
    _kontrol('ogeleriGetir');
    return [for (final o in ogeler) if (o.aliskanlikId == aliskanlikId) o];
  }

  @override
  Future<Oge> ogeGetir(String id) async {
    _kontrol('ogeGetir');
    return ogeler.firstWhere((o) => o.id == id);
  }

  @override
  Future<Gun> gunYaz(String aliskanlikId, DateTime tarih, GunYaz yaz) async {
    _kontrol('gunYaz');
    return Gun(tarih: tarih, miktar: yaz.miktar, deger: 1, planli: true, guc: 0);
  }

  @override
  Future<void> gunSil(String aliskanlikId, DateTime tarih) async => _kontrol('gunSil');

  @override
  Future<Oturum> oturumEkle(String ogeId, OturumEkle ekle) async {
    _kontrol('oturumEkle');
    return Oturum(
      id: ekle.id ?? 'x',
      ogeId: ogeId,
      tarih: DateTime.utc(2026, 10, 31),
      baslangicKonum: ekle.baslangicKonum ?? 0,
      bitisKonum: ekle.bitisKonum,
      miktar: ekle.bitisKonum - (ekle.baslangicKonum ?? 0),
      olusturulma: DateTime.utc(2026, 10, 31),
      son: true,
    );
  }

  @override
  Future<List<Yakalama>> yakalamalariGetir() async {
    _kontrol('yakalamalariGetir');
    return yakalamalar;
  }

  /// Server reminders for `/api/hatirlaticilar`.
  List<Hatirlatici> hatirlaticilar = [];

  @override
  Future<List<Hatirlatici>> hatirlaticilariGetir() async {
    _kontrol('hatirlaticilariGetir');
    return hatirlaticilar;
  }

  @override
  Future<Hatirlatici> hatirlaticiOlustur(HatirlaticiYaz yaz) async {
    _kontrol('hatirlaticiOlustur');
    return ornekHatirlatici(id: yaz.id!, baslik: yaz.baslik);
  }

  @override
  Future<Hatirlatici> hatirlaticiGuncelle(String id, HatirlaticiYaz yaz) async {
    _kontrol('hatirlaticiGuncelle');
    return ornekHatirlatici(id: id, baslik: yaz.baslik);
  }

  @override
  Future<void> hatirlaticiSil(String id) async => _kontrol('hatirlaticiSil');

  @override
  Future<Hatirlatici> hatirlaticiYaptim(String id) async {
    _kontrol('hatirlaticiYaptim');
    return ornekHatirlatici(id: id);
  }

  @override
  Future<Hatirlatici> hatirlaticiErtele(String id, String sure) async {
    _kontrol('hatirlaticiErtele:$sure');
    return ornekHatirlatici(id: id);
  }

  // ---- Approval queue ----

  /// Server actions for `/api/eylemler?durum=`; a decision changes the stored copy like the server would.
  List<Eylem> eylemler = [];

  /// Modes for `/api/yonetim/eylem-izinleri`.
  List<EylemKipDurumu> eylemKipleri = [];

  /// When set, `eylemUygula`, `eylemReddet` and `eylemGeriAl` fail with this HTTP status (409: already decided).
  int? eylemKararHatasi;

  @override
  Future<List<Eylem>> eylemleriGetir(EylemDurumu durum) async {
    _kontrol('eylemleriGetir:${durum.name}');
    return [for (final e in eylemler) if (e.durum == durum) e];
  }

  Eylem _eylemKarari(String ad, String id, EylemDurumu yeni, {Map<String, dynamic>? yuk}) {
    _kontrol(ad);
    if (eylemKararHatasi != null) {
      final istek = RequestOptions(path: ad);
      throw DioException.badResponse(
        statusCode: eylemKararHatasi!,
        requestOptions: istek,
        response: Response(requestOptions: istek, statusCode: eylemKararHatasi),
      );
    }
    final yeniEylem = eylemler.firstWhere((e) => e.id == id).copyWith(durum: yeni, yuk: yuk);
    eylemler = [for (final e in eylemler) e.id == id ? yeniEylem : e];
    return yeniEylem;
  }

  @override
  Future<Eylem> eylemUygula(String id, {Map<String, dynamic>? yuk}) async =>
      _eylemKarari('eylemUygula:$id${yuk == null ? '' : ':yuk=${jsonEncode(yuk)}'}', id, EylemDurumu.uygulandi, yuk: yuk);

  @override
  Future<Eylem> eylemReddet(String id, {bool birDahaOnerme = false}) async =>
      _eylemKarari('eylemReddet:$id:$birDahaOnerme', id, EylemDurumu.reddedildi);

  @override
  Future<Eylem> eylemGeriAl(String id) async => _eylemKarari('eylemGeriAl:$id', id, EylemDurumu.geriAlindi);

  @override
  Future<List<EylemKipDurumu>> eylemKipleriniGetir() async {
    _kontrol('eylemKipleriniGetir');
    return eylemKipleri;
  }

  @override
  Future<EylemKipDurumu> eylemKipiAyarla(String tur, EylemKipi kip) async {
    _kontrol('eylemKipiAyarla:$tur:${kip.name}');
    final eski = eylemKipleri.firstWhere((k) => k.tur == tur);
    final yeni = EylemKipDurumu(tur: tur, turAdi: eski.turAdi, kip: kip);
    eylemKipleri = [for (final k in eylemKipleri) k.tur == tur ? yeni : k];
    return yeni;
  }

  // ---- Inbox ----

  /// Server cards for `/api/gelen`; a placement or a deletion removes the card like the server would.
  List<GelenKarti> gelenKartlari = [];

  /// When set, `gelenIsle` and `gelenSil` fail with this HTTP status (400: the placement broke a rule).
  int? gelenYazmaHatasi;

  /// What `gelenOner` answers.
  GelenOneriYaniti gelenOneriYaniti = const GelenOneriYaniti(durum: 'olustu');

  /// When set, `gelenOner` fails with this HTTP status (409, 422, 429, 503).
  int? gelenOneriHatasi;

  @override
  Future<List<GelenKarti>> gelenGetir() async {
    _kontrol('gelenGetir');
    return gelenKartlari;
  }

  void _gelenYazmaKontrol(String ad) {
    _kontrol(ad);
    if (gelenYazmaHatasi == null) return;
    final istek = RequestOptions(path: ad);
    throw DioException.badResponse(
      statusCode: gelenYazmaHatasi!,
      requestOptions: istek,
      response: Response(requestOptions: istek, statusCode: gelenYazmaHatasi, data: {
        'errors': {
          'yol': ['Yol vault\'a göreli olmalı.'],
        },
      }),
    );
  }

  @override
  Future<void> gelenIsle(String kart, GelenIsleGirdi girdi) async {
    _gelenYazmaKontrol('gelenIsle:$kart:${girdi.yol}:${girdi.baslik}:${girdi.etiketler.join(',')}');
    gelenKartlari = [for (final k in gelenKartlari) if (k.kimlik != kart) k];
  }

  @override
  Future<void> gelenSil(String kart) async {
    _gelenYazmaKontrol('gelenSil:$kart');
    gelenKartlari = [for (final k in gelenKartlari) if (k.kimlik != kart) k];
  }

  @override
  Future<GelenOneriYaniti> gelenOner(String kart) async {
    _kontrol('gelenOner:$kart');
    if (gelenOneriHatasi != null) {
      final istek = RequestOptions(path: 'oneri');
      throw DioException.badResponse(
        statusCode: gelenOneriHatasi!,
        requestOptions: istek,
        response: Response(requestOptions: istek, statusCode: gelenOneriHatasi, data: {'detail': 'Kart elle yerleştirilir.'}),
      );
    }
    return gelenOneriYaniti;
  }

  // ---- Morning briefing ----

  /// What `brifingBugun` answers; null means 404 (not ready yet).
  Brifing? brifingYaniti;

  /// `(gun, sira, oy)` of every vote sent.
  final List<(String, int, int)> brifingOylari = [];
  int brifingYenilemeleri = 0;

  void _brifingKontrol(String ad) {
    _kontrol(ad);
    if (brifingHatasi == null) return;
    final istek = RequestOptions(path: ad);
    throw DioException.badResponse(
      statusCode: brifingHatasi!,
      requestOptions: istek,
      response: Response(requestOptions: istek, statusCode: brifingHatasi),
    );
  }

  /// When set, the briefing calls fail with this HTTP status (403, 429, 503).
  int? brifingHatasi;

  @override
  Future<Brifing> brifingBugun() async {
    _brifingKontrol('brifingBugun');
    final b = brifingYaniti;
    if (b == null) {
      final istek = RequestOptions(path: 'brifingBugun');
      throw DioException.badResponse(statusCode: 404, requestOptions: istek, response: Response(requestOptions: istek, statusCode: 404));
    }
    return b;
  }

  @override
  Future<Brifing> brifingOyVer(String gun, int sira, int oy) async {
    _brifingKontrol('brifingOyVer');
    brifingOylari.add((gun, sira, oy));
    return brifingYaniti = brifingYaniti!.oyla(sira, oy);
  }

  @override
  Future<Brifing> brifingYenile() async {
    _brifingKontrol('brifingYenile');
    brifingYenilemeleri++;
    return brifingYaniti!;
  }

  // ---- Timeline ----

  /// What `zamanCizelgesi` answers; null means the server has nothing for the day (404).
  ZamanCizelgesi? zamanCizelgesiYaniti;

  /// The days asked for, in order.
  final List<String> zamanCizelgesiGunleri = [];

  /// When set, the timeline call fails with this HTTP status (403, 503) even when online.
  int? zamanCizelgesiHatasi;

  @override
  Future<ZamanCizelgesi> zamanCizelgesi(String gun) async {
    _kontrol('zamanCizelgesi');
    zamanCizelgesiGunleri.add(gun);
    final kod = zamanCizelgesiHatasi ?? (zamanCizelgesiYaniti == null ? 404 : null);
    if (kod != null) {
      final istek = RequestOptions(path: 'zamanCizelgesi');
      throw DioException.badResponse(statusCode: kod, requestOptions: istek, response: Response(requestOptions: istek, statusCode: kod));
    }
    return zamanCizelgesiYaniti!;
  }

  // ---- Voice and text ----

  /// What `isCikar` answers (the preview).
  IsCikarYaniti isCikarYaniti = const IsCikarYaniti(bugun: '2026-11-07', haftaninGunu: 'Cumartesi', oneriler: [], atlananlar: []);

  /// What `isCikarUygula` answers; null means "all applied", built from the request.
  IsCikarUygulaYaniti? uygulaYaniti;

  /// The texts `isCikar` and `metniYenidenYaz` were sent, and the suggestions `isCikarUygula` was sent, per call.
  final List<String> isCikarMetinleri = [];
  final List<List<IsOnerisi>> uygulananIstekler = [];
  final List<String?> uygulamaKaynaklari = [];
  final List<(String, YenidenYazKipi)> yenidenYazIstekleri = [];

  /// What `metniYenidenYaz` answers.
  String yenidenYazSonucu = 'Kısa özet.';

  /// When set, the voice calls fail with this HTTP status (503, 429, 502, 403).
  int? sesHatasi;

  void _sesKontrol(String ad) {
    _kontrol(ad);
    if (sesHatasi == null) return;
    final istek = RequestOptions(path: ad);
    throw DioException.badResponse(
      statusCode: sesHatasi!,
      requestOptions: istek,
      response: Response(requestOptions: istek, statusCode: sesHatasi),
    );
  }

  @override
  Future<IsCikarYaniti> isCikar(String metin) async {
    _sesKontrol('isCikar');
    isCikarMetinleri.add(metin);
    return isCikarYaniti;
  }

  @override
  Future<IsCikarUygulaYaniti> isCikarUygula(List<IsOnerisi> secilenler, {String? kaynak}) async {
    _sesKontrol('isCikarUygula');
    uygulananIstekler.add(secilenler);
    uygulamaKaynaklari.add(kaynak);
    return uygulaYaniti ??
        IsCikarUygulaYaniti(
          uygulanan: secilenler.length,
          basarisiz: 0,
          sonuclar: [for (var i = 0; i < secilenler.length; i++) IsUygulaSonucu(sira: i, durum: 'uygulandi')],
        );
  }

  @override
  Future<String> metniYenidenYaz(String metin, YenidenYazKipi kip) async {
    _sesKontrol('metniYenidenYaz');
    yenidenYazIstekleri.add((metin, kip));
    return yenidenYazSonucu;
  }

  // ---- Second brain ----

  List<ProjeOzet> projeler = [];
  Map<String, ProjeDetay> projeDetaylari = {};

  /// Day plans by "2026-11-03".
  Map<String, BeyinGun> gunPlanlari = {};
  List<AramaSonucu> aramaSonuclari = [];
  Map<String, BeyinNotu> notlar = {};

  /// When set, every `/api/beyin` call fails with this HTTP status (503: brain not set up, 403: no permission).
  int? beyinHatasi;

  /// When true, only the `/api/beyin` calls fail like a lost connection.
  bool beyinCevrimdisi = false;

  /// Every plan or task write the fake server was sent: the path, the body and the Idempotency-Key.
  final List<({String yol, Map<String, dynamic> govde, String anahtar})> beyinYazimlari = [];

  /// What the next plan or task writes answer, by order of arrival (a list consumed from the front; the last one repeats).
  /// An entry is a status: 200/202/207 with `beyinYazmaGovdesi`, or a 4xx/5xx that is thrown like the server's refusal.
  List<int> beyinYazmaKodlari = [];

  /// The JSON body that goes with 202 and 207.
  Map<String, dynamic> beyinYazmaGovdesi = {};

  /// A ProblemDetails body for a refusal.
  Map<String, dynamic> beyinYazmaProblemi = {'title': 'İşlem uygulanamadı', 'detail': 'Beyin işlemi uygulamadı.'};

  @override
  Future<BeyinYazmaSonucu> beyinYaz(String yol, Map<String, dynamic> govde, {required String anahtar}) async {
    _beyinKontrol('beyinYaz:$yol');
    beyinYazimlari.add((yol: yol, govde: govde, anahtar: anahtar));
    final kod = beyinYazmaKodlari.length > 1 ? beyinYazmaKodlari.removeAt(0) : (beyinYazmaKodlari.firstOrNull ?? 200);
    if (kod >= 400) {
      final istek = RequestOptions(path: yol);
      throw DioException.badResponse(
        statusCode: kod,
        requestOptions: istek,
        response: Response(requestOptions: istek, statusCode: kod, data: beyinYazmaProblemi),
      );
    }
    return BeyinYazmaSonucu.durumKodundan(kod, beyinYazmaGovdesi);
  }

  void _beyinKontrol(String ad) {
    cagrilar.add(ad);
    final istek = RequestOptions(path: ad);
    if (beyinHatasi != null) {
      throw DioException.badResponse(
        statusCode: beyinHatasi!,
        requestOptions: istek,
        response: Response(requestOptions: istek, statusCode: beyinHatasi),
      );
    }
    if (beyinCevrimdisi || cevrimdisi) {
      throw DioException.connectionError(requestOptions: istek, reason: 'offline');
    }
  }

  @override
  Future<List<ProjeOzet>> beyinProjeleri() async {
    _beyinKontrol('beyinProjeleri');
    return projeler;
  }

  @override
  Future<ProjeDetay> beyinProje(String kimlik) async {
    _beyinKontrol('beyinProje');
    return projeDetaylari[kimlik] ?? (throw _yok('beyinProje'));
  }

  @override
  Future<BeyinGun> beyinGun(DateTime tarih) async {
    _beyinKontrol('beyinGun');
    return gunPlanlari[tarihMetni(tarih)] ?? BeyinGun(tarih: tarih);
  }

  @override
  Future<List<AramaSonucu>> beyinAra(String q, {String? proje, int? limit}) async {
    _beyinKontrol('beyinAra:$q');
    return aramaSonuclari;
  }

  @override
  Future<BeyinNotu> beyinNot(String yol) async {
    _beyinKontrol('beyinNot');
    return notlar[yol] ?? (throw _yok('beyinNot'));
  }

  DioException _yok(String ad) {
    final istek = RequestOptions(path: ad);
    return DioException.badResponse(
      statusCode: 404,
      requestOptions: istek,
      response: Response(requestOptions: istek, statusCode: 404),
    );
  }

  @override
  Future<DosyaYaniti> dosyaYukle(String yol, {String? dosyaAdi}) async {
    _kontrol('dosyaYukle');
    return const DosyaYaniti(id: 'f1', url: '/api/dosyalar/f1');
  }

  @override
  Future<Yakalama> yakalamaOlustur(YakalamaYaz yaz) async {
    _kontrol('yakalamaOlustur');
    return Yakalama(
      id: yaz.id!,
      metin: yaz.metin,
      fotografId: yaz.fotografId,
      durum: YakalamaDurumu.bekliyor,
      yakalandiAt: yaz.yakalandiAt,
      olusturulma: yaz.yakalandiAt,
    );
  }

  @override
  Future<Yakalama> yakalamaGuncelle(String id, YakalamaYaz yaz) async {
    _kontrol('yakalamaGuncelle');
    return Yakalama(
      id: id,
      metin: yaz.metin,
      fotografId: yaz.fotografId,
      hedef: yaz.hedef,
      durum: YakalamaDurumu.bekliyor,
      yakalandiAt: yaz.yakalandiAt,
      olusturulma: yaz.yakalandiAt,
    );
  }

  // ---- Management (Sahip only) ----

  List<Izin> izinler = [];
  YonetimBeyinDurumu yonetimBeyni = const YonetimBeyinDurumu(bagli: true, vault: '.ornek-beyin-calisma');
  List<Gonderim> gonderimler = [];

  /// When set, `gonderimiYenidenDene` fails with this HTTP status (409: being sent right now).
  int? yenidenDeneHatasi;

  @override
  Future<List<Izin>> izinleriGetir() async {
    _kontrol('izinleriGetir');
    return izinler;
  }

  @override
  Future<Izin> izinAyarla(String izin, {required bool acik}) async {
    _kontrol('izinAyarla:$izin:$acik');
    final yeni = Izin(izin: izin, aciklama: izinler.firstWhere((i) => i.izin == izin).aciklama, acik: acik);
    izinler = [for (final i in izinler) i.izin == izin ? yeni : i];
    return yeni;
  }

  /// When set, the password calls fail with this HTTP status (400: the server refused the password).
  int? sifreHatasi;

  @override
  Future<void> sifreDegistir({required String mevcutSifre, required String yeniSifre}) async {
    _kontrol('sifreDegistir:$mevcutSifre:$yeniSifre');
    _sifreHatasiniFirlat();
  }

  @override
  Future<void> asistaninSifresiniYenile(String yeniSifre) async {
    _kontrol('asistaninSifresiniYenile:$yeniSifre');
    _sifreHatasiniFirlat();
  }

  void _sifreHatasiniFirlat() {
    if (sifreHatasi == null) return;
    final istek = RequestOptions(path: 'sifre');
    throw DioException.badResponse(
      statusCode: sifreHatasi!,
      requestOptions: istek,
      response: Response(
        requestOptions: istek,
        statusCode: sifreHatasi,
        data: {
          'errors': {
            'PasswordMismatch': ['Mevcut şifre yanlış.'],
          },
        },
      ),
    );
  }

  @override
  Future<YonetimBeyinDurumu> yonetimBeyinDurumu() async {
    _kontrol('yonetimBeyinDurumu');
    return yonetimBeyni;
  }

  @override
  Future<List<Gonderim>> gonderimKuyrugu() async {
    _kontrol('gonderimKuyrugu');
    return gonderimler;
  }

  @override
  Future<Gonderim> gonderimiYenidenDene(String id) async {
    _kontrol('gonderimiYenidenDene:$id');
    if (yenidenDeneHatasi != null) {
      final istek = RequestOptions(path: 'yeniden-dene');
      throw DioException.badResponse(
        statusCode: yenidenDeneHatasi!,
        requestOptions: istek,
        response: Response(requestOptions: istek, statusCode: yenidenDeneHatasi),
      );
    }
    final eski = gonderimler.firstWhere((g) => g.id == id);
    final yeni = Gonderim(
      id: id,
      metin: eski.metin,
      durum: eski.durum,
      gonderim: GonderimDurumu.bekliyor,
      yakalandiAt: eski.yakalandiAt,
    );
    gonderimler = [for (final g in gonderimler) g.id == id ? yeni : g];
    return yeni;
  }

  @override
  Future<List<Oturum>> oturumlariGetir(String ogeId) async {
    _kontrol('oturumlariGetir');
    return const [];
  }
}

Gonderim ornekGonderim({
  String id = 'g1',
  String metin = 'Ali\'ye kitabı ver',
  GonderimDurumu gonderim = GonderimDurumu.hatali,
  YakalamaDurumu durum = YakalamaDurumu.bekliyor,
  int deneme = 2,
  String? sonHata = 'beyin.py zaman aşımı',
}) {
  return Gonderim(
    id: id,
    metin: metin,
    durum: durum,
    gonderim: gonderim,
    yakalandiAt: DateTime.utc(2026, 11, 4, 10),
    denemeSayisi: deneme,
    sonHata: sonHata,
  );
}

/// A suggested "create a reminder" action, waiting for a decision.
Eylem ornekEylem({
  String id = 'e1',
  String ozet = 'Ali\'yi ara',
  EylemDurumu durum = EylemDurumu.bekliyor,
  bool disKaynak = false,
  double? guven,
  String? gerekce = 'Mailde yazıyor',
  Map<String, dynamic>? yuk,
  DateTime? createdAt,
  String? kararVerenId,
  bool geriAlinabilir = true,
}) {
  return Eylem(
    id: id,
    tur: 'hatirlatici-kur',
    turAdi: 'Hatırlatıcı kur',
    yuk: yuk ?? {'baslik': ozet, 'gun': '2030-01-01'},
    ozet: ozet,
    kaynak: 'gelen',
    disKaynak: disKaynak,
    gerekce: gerekce,
    guven: guven,
    durum: durum,
    createdAt: createdAt ?? DateTime.utc(2026, 11, 1, 8),
    kararVerenId: kararVerenId,
    geriAlinabilir: geriAlinabilir,
  );
}

/// An inbox card; with [eylemId] it has a placement suggestion waiting in the approval queue.
GelenKarti ornekGelenKarti({
  String kimlik = '2026-11-03-1840-kitap-onerisi',
  String ozet = 'Kitap önerisi: Simyacı',
  String? eylemId,
  bool disKaynak = false,
  double? guven = 0.9,
  bool laptoptaIslenecek = false,
  bool gorselVar = false,
}) {
  return GelenKarti(
    kimlik: kimlik,
    ozet: ozet,
    gorselVar: gorselVar,
    yakalandi: '2026-11-03T18:40',
    laptoptaIslenecek: laptoptaIslenecek,
    laptopNotu: laptoptaIslenecek ? 'Sözlükte \'mimari-karar\' yok.' : null,
    oneri: eylemId == null
        ? null
        : GelenOneri(
            eylemId: eylemId,
            yol: 'projects/kitap-kulubu/notlar/simyaci.md',
            baslik: 'Simyacı önerisi',
            etiketler: const ['kaynak', 'okul'],
            gerekce: 'Kitap önerisi.',
            guven: guven,
            disKaynak: disKaynak,
          ),
  );
}

/// A reminder on 2026-11-02 09:00 Istanbul time (06:00Z), the day after [sabitAn]'s habit day plus one.
Hatirlatici ornekHatirlatici({
  String id = 'h1',
  String baslik = 'Faturayı öde',
  HatirlaticiTuru tur = HatirlaticiTuru.gorev,
  String? kime,
  DateTime? gun,
  Saat? saat,
  Tekrar tekrar = Tekrar.yok,
  int onceGun = 0,
  HatirlaticiDurumu durum = HatirlaticiDurumu.acik,
  DateTime? sonrakiAn,
  DateTime? erteleAn,
}) {
  return Hatirlatici(
    id: id,
    baslik: baslik,
    tur: tur,
    kime: kime,
    gun: gun ?? DateTime.utc(2026, 11, 2),
    saat: saat,
    tekrar: tekrar,
    onceGun: onceGun,
    durum: durum,
    sonrakiAn: sonrakiAn ?? DateTime.utc(2026, 11, 2, 6),
    erteleAn: erteleAn,
    createdAt: DateTime.utc(2026, 10, 1),
  );
}

/// 2026-10-31 12:00 Istanbul time (habit day 2026-10-31).
final sabitAn = DateTime.utc(2026, 10, 31, 9);
final sabitBugun = DateTime.utc(2026, 10, 31);

Aliskanlik ornekAliskanlik({
  String id = 'a1',
  String ad = 'Su iç',
  AliskanlikTuru tur = AliskanlikTuru.sayac,
  Olcu olcu = Olcu.sayili,
  HedefYonu yon = HedefYonu.enAz,
  double? hedef = 8,
  String? birim = 'bardak',
  bool planli = true,
  double miktar = 0,
  int sira = 0,
  List<OgeOzet> devamEdenler = const [],
}) {
  return Aliskanlik(
    id: id,
    ad: ad,
    tur: tur,
    ikon: 'droplet',
    renk: 'violet',
    olcu: olcu,
    hedefYonu: yon,
    gunlukHedef: olcu == Olcu.evetHayir ? null : hedef,
    birim: olcu == Olcu.evetHayir ? null : birim,
    ogeEtiketi: tur == AliskanlikTuru.raf ? 'Kitap' : null,
    siklik: Siklik.herGun,
    sira: sira,
    arsivlendi: false,
    olusturulma: DateTime.utc(2026, 10, 1),
    bugun: BugunDurumu(tarih: sabitBugun, miktar: miktar, deger: 0, planli: planli),
    guc: 0.5,
    seri: 3,
    enUzunSeri: 5,
    devamEdenler: devamEdenler,
  );
}

Oge ornekOge({String id = 'o1', String aliskanlikId = 'r1', double konum = 12, double? toplam = 160}) {
  return Oge(
    id: id,
    aliskanlikId: aliskanlikId,
    ad: 'Kürk Mantolu Madonna',
    toplam: toplam,
    baslangicKonumu: 0,
    guncelKonum: konum,
    ilerleme: toplam == null ? null : konum / toplam,
    durum: OgeDurumu.devam,
    olusturulma: DateTime.utc(2026, 10, 1),
  );
}

/// In-memory database plus the repositories wired to a [SahteApi].
class TestOrtami {
  TestOrtami({SahteApi? api}) : api = api ?? SahteApi() {
    db = AppDatabase(NativeDatabase.memory());
    esitleyici = Esitleyici(api: this.api, db: db, simdi: _artanSaat);
    repo = AliskanlikRepository(api: this.api, db: db, esitleyici: esitleyici, simdi: () => sabitAn);
    yakalamalar = YakalamaRepository(
      api: this.api,
      db: db,
      esitleyici: esitleyici,
      fotograflar: FotografDeposu(klasor: () async => fotografKlasoru),
      simdi: () => sabitAn,
    );
    beyin = BeyinRepository(api: this.api, db: db);
    gunPlani = GunPlaniRepository(beyin: beyin, db: db, esitleyici: esitleyici, simdi: () => sabitAn);
    hatirlaticilar = HatirlaticiRepository(api: this.api, db: db, esitleyici: esitleyici);
    eylemler = EylemRepository(api: this.api, db: db, esitleyici: esitleyici);
    gelen = GelenRepository(api: this.api, db: db, esitleyici: esitleyici);
    brifing = BrifingRepository(api: this.api, db: db, simdi: () => sabitAn);
    zamanCizelgesi = ZamanCizelgesiRepository(api: this.api, db: db, simdi: () => sabitAn);
  }

  final SahteApi api;
  late final AppDatabase db;
  late final Esitleyici esitleyici;
  late final AliskanlikRepository repo;
  late final YakalamaRepository yakalamalar;
  late final BeyinRepository beyin;
  late final GunPlaniRepository gunPlani;
  late final HatirlaticiRepository hatirlaticilar;
  late final EylemRepository eylemler;
  late final GelenRepository gelen;
  late final BrifingRepository brifing;
  late final ZamanCizelgesiRepository zamanCizelgesi;

  /// Where the photo copies of the captures go in tests.
  final Directory fotografKlasoru = Directory.systemTemp.createTempSync('yakalama_test');

  var _saat = sabitAn;

  /// Strictly increasing, so queue order is deterministic.
  DateTime _artanSaat() => _saat = _saat.add(const Duration(seconds: 1));

  Future<void> kapat() async {
    await db.close();
    if (fotografKlasoru.existsSync()) fotografKlasoru.deleteSync(recursive: true);
  }
}

/// A [BildirimServisi] that remembers what it was asked to set up, so tests need no platform plugin.
class SahteBildirimServisi implements BildirimServisi {
  /// Every plan handed to [kur], oldest first.
  final List<List<PlanliBildirim>> planlar = [];
  int izinIstekleri = 0;
  BildirimYaniti? acilis;
  void Function(BildirimYaniti)? yanitla;
  bool baslatildi = false;

  List<PlanliBildirim> get son => planlar.last;

  @override
  Future<void> baslat({required void Function(BildirimYaniti) yanit}) async {
    baslatildi = true;
    yanitla = yanit;
  }

  @override
  Future<BildirimYaniti?> acilisYaniti() async => acilis;

  @override
  Future<bool> izinIste() async {
    izinIstekleri++;
    return true;
  }

  @override
  Future<void> kur(List<PlanliBildirim> plan) async => planlar.add(plan);

  /// Every approval queue notification shown, oldest first.
  final List<EylemBildirimi> eylemBildirimleri = [];

  /// Ids of the notifications taken down.
  final List<int> kapatilanlar = [];

  @override
  Future<void> eylemBildir(EylemBildirimi bildirim) async => eylemBildirimleri.add(bildirim);

  @override
  Future<void> bildirimiKapat(int id) async => kapatilanlar.add(id);
}
