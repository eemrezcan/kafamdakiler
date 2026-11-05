import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:kafamdakiler/data/models/aliskanlik.dart';
import 'package:kafamdakiler/data/models/ben.dart';
import 'package:kafamdakiler/data/models/beyin.dart';
import 'package:kafamdakiler/data/models/enums.dart';
import 'package:kafamdakiler/data/models/gun.dart';
import 'package:kafamdakiler/data/models/oge.dart';
import 'package:kafamdakiler/data/models/giris.dart';
import 'package:kafamdakiler/data/models/oturum.dart';
import 'package:kafamdakiler/data/models/yakalama.dart';
import 'package:kafamdakiler/data/repositories/aliskanlik_repository.dart';
import 'package:kafamdakiler/data/repositories/beyin_repository.dart';
import 'package:kafamdakiler/data/repositories/esitleyici.dart';
import 'package:kafamdakiler/data/repositories/yakalama_repository.dart';
import 'package:kafamdakiler/data/services/api_service.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';
import 'package:kafamdakiler/data/services/fotograf_deposu.dart';
import 'package:kafamdakiler/utils/aliskanlik_gunu.dart';

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

  @override
  Future<List<Oturum>> oturumlariGetir(String ogeId) async {
    _kontrol('oturumlariGetir');
    return const [];
  }
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
  }

  final SahteApi api;
  late final AppDatabase db;
  late final Esitleyici esitleyici;
  late final AliskanlikRepository repo;
  late final YakalamaRepository yakalamalar;
  late final BeyinRepository beyin;

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
