import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../utils/aliskanlik_gunu.dart';
import '../models/beyin.dart';
import '../services/database/app_database.dart';
import 'bekleyen_uygula.dart';
import 'beyin_repository.dart';
import 'esitleyici.dart';

/// A morning card entry: an item yesterday's plan left open, and the section it sat in.
class SabahMaddesi {
  const SabahMaddesi({required this.madde, required this.bolum});

  final BeyinGunMaddesi madde;
  final String bolum;
}

/// What the plan card tells the user about a write: one the server refused (and so was taken back off the screen), or
/// one it accepted without a clear "done" (an unclear answer, a split that stopped half way).
class YazmaBildirimi {
  const YazmaBildirimi({required this.id, required this.metin, required this.reddedildi});

  /// The queue entry; dismissing the message removes it.
  final String id;
  final String metin;

  /// True: refused, nothing was written and the write is off the screen. False: accepted, look at the plan.
  final bool reddedildi;
}

/// The brain's plan for a day, with the writes of K2.3a (add, tick, carry over, note, tasks, split) behind it.
///
/// Reads go through [BeyinRepository] and the last answer per day is kept on the phone, so a day can be shown and written
/// to offline. Every write is queued on the phone first ([Esitleyici]); the plan shown is always the cached answer with the
/// queued writes laid on top ([gunPlaninaBekleyenleriUygula]). Listeners are told after every local change.
class GunPlaniRepository extends ChangeNotifier {
  GunPlaniRepository({
    required this._beyin,
    required this._db,
    required this._esitleyici,
    DateTime Function()? simdi,
  }) : _simdi = simdi ?? DateTime.now;

  final BeyinRepository _beyin;
  final AppDatabase _db;
  final Esitleyici _esitleyici;
  final DateTime Function() _simdi;

  /// How long a cached day is kept.
  static const _saklamaSuresi = Duration(days: 14);

  /// Today by the rule shared with the brain (the day turns at 05:00).
  DateTime get bugun => aliskanlikGunu(_simdi());

  DateTime get dun => bugun.subtract(const Duration(days: 1));

  /// Fetches the day and keeps it; without an answer from the server (offline) the cached copy is used and `cevrimdisi`
  /// says so. Queued writes are laid over both. Any other failure (403, 503...) is thrown.
  Future<({BeyinGun gun, bool cevrimdisi})> oku(DateTime tarih) async {
    try {
      final gun = await _beyin.gun(tarih);
      await _onbellegeYaz(tarih, gun);
      return (gun: await _uygula(gun), cevrimdisi: false);
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      final yerel = await this.yerel(tarih);
      if (yerel == null) rethrow;
      return (gun: yerel, cevrimdisi: true);
    }
  }

  /// The cached day with the queued writes on top; no network. Null when the day was never read.
  Future<BeyinGun?> yerel(DateTime tarih) async {
    final satir = await (_db.select(_db.gunPlaniOnbellek)..where((t) => t.tarih.equals(tarihMetni(tarih)))).getSingleOrNull();
    if (satir == null) return null;
    return _uygula(BeyinGun.fromJson(jsonDecode(satir.govde) as Map<String, dynamic>));
  }

  Future<BeyinGun> _uygula(BeyinGun gun) async => gunPlaninaBekleyenleriUygula(gun, await _esitleyici.bekleyenler());

  Future<void> _onbellegeYaz(DateTime tarih, BeyinGun gun) async {
    await _db.into(_db.gunPlaniOnbellek).insertOnConflictUpdate(GunPlaniOnbellekCompanion.insert(
          tarih: tarihMetni(tarih),
          govde: jsonEncode(gun.toJson()),
          okunma: _simdi(),
        ));
    await (_db.delete(_db.gunPlaniOnbellek)..where((t) => t.okunma.isSmallerThanValue(_simdi().subtract(_saklamaSuresi)))).go();
  }

  // Writes. Each goes to the phone's queue and returns; the caller asks [Esitleyici.gonder] to send.

  Future<void> maddeEkle(DateTime tarih, String metin, {String? bolum}) async {
    await _esitleyici.beyinMaddeEkleKuyrugaAl(tarih, metin: metin.trim(), bolum: bolum);
    notifyListeners();
  }

  /// Ticks [madde] (or takes the tick away when it is done already).
  Future<void> isaretle(DateTime tarih, BeyinGunMaddesi madde) async {
    await _esitleyici.beyinMaddeIsaretleKuyrugaAl(tarih, madde.id, geri: madde.yapildi);
    notifyListeners();
  }

  Future<void> devret(DateTime tarih, BeyinGunMaddesi madde, {String? bolum}) async {
    await _esitleyici.beyinMaddeDevretKuyrugaAl(tarih, madde.id, baslik: madde.baslik, bolum: bolum, tahminDk: madde.tahminDk);
    notifyListeners();
  }

  Future<void> notEkle(DateTime tarih, BeyinGunMaddesi madde, String metin) async {
    await _esitleyici.beyinMaddeNotKuyrugaAl(tarih, madde.id, metin.trim());
    notifyListeners();
  }

  Future<void> gorevEkle({required String baslik, required String proje, DateTime? bitis}) async {
    await _esitleyici.beyinGorevEkleKuyrugaAl(baslik: baslik.trim(), proje: proje, bitis: bitis);
    notifyListeners();
  }

  Future<void> gorevBitir(String kimlik) async {
    await _esitleyici.beyinGorevBitirKuyrugaAl(kimlik);
    notifyListeners();
  }

  Future<void> gunlereBol(String kimlik, {required int gunSayisi, DateTime? baslangic}) async {
    await _esitleyici.beyinGunlereBolKuyrugaAl(kimlik, gunSayisi: gunSayisi, baslangic: baslangic);
    notifyListeners();
  }

  // The morning card.

  /// What yesterday's plan left open and the user has not let go. Yesterday's plan is read first (quietly: with no answer the
  /// cached copy is used, and with none the card is simply empty). Items added on the phone and not sent yet are left out
  /// (they cannot be carried before they have an id), and so is a day that was closed already.
  Future<List<SabahMaddesi>> sabah({bool oku = true}) async {
    final gun = dun;
    if (oku) {
      try {
        await this.oku(gun);
      } on DioException {
        // Offline with nothing cached, or not allowed: the card is empty, the plan card shows the reason.
      }
    }
    final plan = await yerel(gun);
    if (plan == null || plan.kapandi) return const [];
    final birakilan = {
      for (final s in await (_db.select(_db.sabahBirakilanlar)..where((t) => t.tarih.equals(tarihMetni(gun)))).get()) s.id,
    };
    return [
      for (final b in plan.bolumler)
        for (final m in b.maddeler)
          if (m.acik && !m.yerel && !birakilan.contains(m.id)) SabahMaddesi(madde: m, bolum: b.ad),
    ];
  }

  /// "Taşı": carries the item from yesterday to today in the brain (a carry-over dated yesterday).
  Future<void> sabahTasi(SabahMaddesi s) => devret(dun, s.madde, bolum: s.bolum);

  /// "Bırak": writes nothing to the brain (closing yesterday is the closing job's work); the card stops offering the item.
  Future<void> sabahBirak(SabahMaddesi s) async {
    final gun = dun;
    await _db.into(_db.sabahBirakilanlar).insertOnConflictUpdate(
          SabahBirakilanlarCompanion.insert(id: s.madde.id, tarih: tarihMetni(gun)),
        );
    await (_db.delete(_db.sabahBirakilanlar)..where((t) => t.tarih.isSmallerThanValue(tarihMetni(gun)))).go();
    notifyListeners();
  }

  /// The projects the phone knows (the capture picker's list), for the new-task form.
  Future<List<ProjeOzet>> projeler() => _beyin.yerelProjeler();

  // What the user should be told.

  /// Refused writes (taken back off the screen) and accepted ones that need a look, oldest first.
  Future<List<YazmaBildirimi>> bildirimler() async {
    final bildirimler = <(DateTime, YazmaBildirimi)>[];
    for (final b in await _esitleyici.reddedilenler()) {
      if (_baslik(b) case final baslik?) {
        bildirimler.add((b.olusturulma, YazmaBildirimi(id: b.id, metin: '$baslik geri alındı: ${b.hata}', reddedildi: true)));
      }
    }
    for (final b in await _esitleyici.uyarilar()) {
      if (_baslik(b) case final baslik?) {
        bildirimler.add((b.olusturulma, YazmaBildirimi(id: b.id, metin: '$baslik: ${b.uyari}', reddedildi: false)));
      }
    }
    bildirimler.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final b in bildirimler) b.$2];
  }

  /// Dismisses a message.
  Future<void> bildirimiKapat(String id) => _esitleyici.sil(id);

  /// Null for entries that are not plan or task writes.
  static String? _baslik(BekleyenIslemlerData b) {
    final govde = jsonDecode(b.govde) as Map<String, dynamic>;
    final istek = govde['istek'] as Map<String, dynamic>? ?? const {};
    return switch (b.tur) {
      BekleyenTur.beyinMaddeEkle => 'Madde "${govde['baslik']}" (${b.tarih})',
      BekleyenTur.beyinMaddeIsaretle => 'Madde işareti (${b.tarih})',
      BekleyenTur.beyinMaddeDevret => 'Devretme: ${govde['baslik']} (${b.tarih})',
      BekleyenTur.beyinMaddeNot => 'Madde notu (${b.tarih})',
      BekleyenTur.beyinGorevEkle => 'Görev "${istek['baslik']}"',
      BekleyenTur.beyinGorevBitir => 'Görevi bitirme (${b.hedefId})',
      BekleyenTur.beyinGunlereBol => 'Günlere bölme (${b.hedefId})',
      _ => null,
    };
  }
}
