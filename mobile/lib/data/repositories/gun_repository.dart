import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../utils/aliskanlik_gunu.dart';
import '../models/gun_gorunum.dart';
import '../services/api_service.dart';
import '../services/database/app_database.dart';
import 'bekleyen_uygula.dart';
import 'esitleyici.dart';

/// One day of the day view and whether it is fresh from the server (`cevrimdisi` false) or the phone's last copy of it.
typedef GunOkuma = ({GunGorunum gun, bool cevrimdisi});

/// The day view behind Bugün and Takvim (K-0024, sözleşme §1-§5): the day, the calendar range and the writes on a row.
///
/// Reads keep their last answer on the phone, so a day is shown offline. Every write is queued on the phone first
/// ([Esitleyici]); the day shown is always the cached answer with the queued writes laid on top
/// ([gunGorunumuneBekleyenleriUygula]). Listeners are told after every local write so the screens reload.
class GunRepository extends ChangeNotifier {
  GunRepository({
    required this._api,
    required this._db,
    required this._esitleyici,
    DateTime Function()? simdi,
  }) : _simdi = simdi ?? DateTime.now;

  final ApiService _api;
  final AppDatabase _db;
  final Esitleyici _esitleyici;
  final DateTime Function() _simdi;

  /// How long a cached day or range is kept.
  static const _saklamaSuresi = Duration(days: 14);
  static const _ayarAnahtari = 'gun.kapasite';

  /// Today by the rule shared with the brain (the day turns at 05:00).
  DateTime get bugun => aliskanlikGunu(_simdi());

  // Reads.

  /// The day from the server, kept; with no answer (offline) the cached copy is used and `cevrimdisi` says so. Queued writes
  /// are laid over both. Any other failure (403, 5xx...) is thrown.
  Future<GunOkuma> oku(DateTime tarih) async {
    try {
      final gun = await _api.gunGorunumu(tarihMetni(tarih));
      await _db.into(_db.gunGorunumOnbellek).insertOnConflictUpdate(GunGorunumOnbellekCompanion.insert(
            tarih: tarihMetni(tarih),
            govde: jsonEncode(gun.toJson()),
            okunma: _simdi(),
          ));
      await (_db.delete(_db.gunGorunumOnbellek)..where((t) => t.okunma.isSmallerThanValue(_simdi().subtract(_saklamaSuresi)))).go();
      return (gun: await _uygula(gun), cevrimdisi: false);
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      final yerel = await this.yerel(tarih);
      if (yerel == null) rethrow;
      return (gun: yerel, cevrimdisi: true);
    }
  }

  /// The cached day with the queued writes on top; no network. Null when the day was never read.
  Future<GunGorunum?> yerel(DateTime tarih) async {
    final satir = await (_db.select(_db.gunGorunumOnbellek)..where((t) => t.tarih.equals(tarihMetni(tarih)))).getSingleOrNull();
    if (satir == null) return null;
    return _uygula(GunGorunum.fromJson(jsonDecode(satir.govde) as Map<String, dynamic>));
  }

  Future<GunGorunum> _uygula(GunGorunum gun) async => gunGorunumuneBekleyenleriUygula(gun, await _esitleyici.bekleyenler());

  /// The days of a range (at most 42) and the upcoming rows; kept per range, the cached copy offline.
  Future<({TakvimAraligi aralik, bool cevrimdisi})> takvim(DateTime baslangic, DateTime bitis) async {
    final anahtar = '${tarihMetni(baslangic)}/${tarihMetni(bitis)}';
    try {
      final aralik = await _api.takvimAraligi(baslangic, bitis);
      await _db.into(_db.takvimOnbellek).insertOnConflictUpdate(TakvimOnbellekCompanion.insert(
            aralik: anahtar,
            govde: jsonEncode(aralik.toJson()),
            okunma: _simdi(),
          ));
      await (_db.delete(_db.takvimOnbellek)..where((t) => t.okunma.isSmallerThanValue(_simdi().subtract(_saklamaSuresi)))).go();
      return (aralik: aralik, cevrimdisi: false);
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      final satir = await (_db.select(_db.takvimOnbellek)..where((t) => t.aralik.equals(anahtar))).getSingleOrNull();
      if (satir == null) rethrow;
      return (aralik: TakvimAraligi.fromJson(jsonDecode(satir.govde) as Map<String, dynamic>), cevrimdisi: true);
    }
  }

  // Writes. Each goes to the phone's queue and returns; the caller asks [Esitleyici.gonder] to send.

  /// "Yaptım" on a row of [tarih] (or, with [geri], taking it back). Events and rows not sent yet have none.
  Future<void> yaptim(DateTime tarih, Yapilacak oge) async {
    if (!oge.yapilabilir || oge.yerel) return;
    await _esitleyici.gunYaptimKuyrugaAl(tarih, oge.kimlik, geri: oge.yapildi);
    notifyListeners();
  }

  Future<void> ogeEkle(DateTime tarih, YeniOgeYaz yaz) async {
    await _esitleyici.gunOgeEkleKuyrugaAl(tarih, yaz);
    notifyListeners();
  }

  /// Sets up or changes the reminder of [oge].
  Future<void> hatirlaticiYaz(DateTime tarih, Yapilacak oge, HatirlaticiGovde govde) async {
    await _esitleyici.ogeHatirlaticiYazKuyrugaAl(tarih, oge.kimlik, govde, guncelle: oge.hatirlatici != null);
    notifyListeners();
  }

  Future<void> hatirlaticiSil(DateTime tarih, Yapilacak oge) async {
    await _esitleyici.ogeHatirlaticiSilKuyrugaAl(tarih, oge.kimlik);
    notifyListeners();
  }

  /// "Yarına devret" for any row that is not an event (sözleşme E2): a plan item, a task or a reminder goes to the next day. A
  /// row not sent yet has no id to carry.
  Future<void> yarinaDevret(DateTime tarih, Iterable<Yapilacak> ogeler) async {
    for (final o in ogeler) {
      if (o.tur == YapilacakTuru.etkinlik || o.yerel) continue;
      await _esitleyici.gunDevretKuyrugaAl(tarih, o.kimlik, baslik: o.baslik, bolum: o.bolum, tahminDk: o.tahminDk);
    }
    notifyListeners();
  }

  /// "Bugüne al": yesterday's open item is carried to today (the carry-over of yesterday's plan item).
  Future<void> bugunAl(DateTime bugun, DundenKalan d) async {
    await _esitleyici.gunDevretKuyrugaAl(bugun.subtract(const Duration(days: 1)), 'm:${d.maddeId}', baslik: d.baslik, tahminDk: d.tahminDk);
    notifyListeners();
  }

  Future<void> dundenBirak(DateTime bugun, DundenKalan d) async {
    await _esitleyici.dundenBirakKuyrugaAl(bugun, d.maddeId);
    notifyListeners();
  }

  /// A note on a plan row.
  Future<void> notEkle(DateTime tarih, Yapilacak oge, String metin) async {
    if (oge.maddeId == null) return;
    await _esitleyici.beyinMaddeNotKuyrugaAl(tarih, oge.maddeId!, metin.trim());
    notifyListeners();
  }

  /// Splits the task behind [oge] over [gunSayisi] days from [tarih].
  Future<void> gunlereBol(DateTime tarih, Yapilacak oge, int gunSayisi) async {
    final gorev = oge.gorevKimligi;
    if (gorev == null) return;
    await _esitleyici.beyinGunlereBolKuyrugaAl(gorev, gunSayisi: gunSayisi, baslangic: tarih);
    notifyListeners();
  }

  // The day capacity.

  /// The capacity setting: the server's when it answers, else the phone's last copy, else the defaults. A change still in the
  /// queue is shown instead of what the server had.
  Future<GunAyari> gunAyari() async {
    final bekleyen = (await _esitleyici.bekleyenler()).where((b) => b.tur == BekleyenTur.ayarGunYaz).lastOrNull;
    if (bekleyen != null) return GunAyari.fromJson(jsonDecode(bekleyen.govde) as Map<String, dynamic>);
    try {
      final ayar = await _api.gunAyari();
      await _ayarYaz(ayar);
      return ayar;
    } on DioException {
      final satir = await (_db.select(_db.ayarKayitlari)..where((t) => t.anahtar.equals(_ayarAnahtari))).getSingleOrNull();
      return satir == null ? const GunAyari() : GunAyari.fromJson(jsonDecode(satir.deger) as Map<String, dynamic>);
    }
  }

  Future<void> gunAyariYaz(GunAyari ayar) async {
    await _ayarYaz(ayar);
    await _esitleyici.ayarGunYazKuyrugaAl(ayar);
    notifyListeners();
  }

  Future<void> _ayarYaz(GunAyari ayar) => _db.into(_db.ayarKayitlari).insertOnConflictUpdate(
        AyarKayitlariCompanion.insert(anahtar: _ayarAnahtari, deger: jsonEncode(ayar.toJson())),
      );
}
