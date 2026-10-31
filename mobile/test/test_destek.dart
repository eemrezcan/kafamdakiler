import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:kafamdakiler/data/models/aliskanlik.dart';
import 'package:kafamdakiler/data/models/ben.dart';
import 'package:kafamdakiler/data/models/enums.dart';
import 'package:kafamdakiler/data/models/gun.dart';
import 'package:kafamdakiler/data/models/oge.dart';
import 'package:kafamdakiler/data/models/oturum.dart';
import 'package:kafamdakiler/data/repositories/aliskanlik_repository.dart';
import 'package:kafamdakiler/data/repositories/esitleyici.dart';
import 'package:kafamdakiler/data/services/api_service.dart';
import 'package:kafamdakiler/data/services/database/app_database.dart';

/// An [ApiService] that answers from memory. With [cevrimdisi] every call
/// fails like a lost connection.
class SahteApi extends ApiService {
  SahteApi({this.aliskanliklar = const [], this.ogeler = const [], this.ben_}) : super(Dio());

  List<Aliskanlik> aliskanliklar;
  List<Oge> ogeler;
  Ben? ben_;
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
  }

  final SahteApi api;
  late final AppDatabase db;
  late final Esitleyici esitleyici;
  late final AliskanlikRepository repo;

  var _saat = sabitAn;

  /// Strictly increasing, so queue order is deterministic.
  DateTime _artanSaat() => _saat = _saat.add(const Duration(seconds: 1));

  Future<void> kapat() => db.close();
}
