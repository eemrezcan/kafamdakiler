import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../models/brifing.dart';
import '../services/api_service.dart';
import '../services/database/app_database.dart';

/// A briefing and whether it is today's, fresh from the server ([guncel]) or the last one the phone kept (offline, or the
/// server has none yet).
typedef BrifingOkuma = ({Brifing brifing, bool guncel});

/// The morning briefing (K2.7) and the phone's briefing setting.
///
/// Reading goes to the server; every answer is kept on the phone, so without a connection the last briefing is shown. A vote
/// needs the server (it has no offline queue: a thumb is a small, repeatable gesture).
class BrifingRepository {
  BrifingRepository({required this._api, required this._db, DateTime Function()? simdi}) : _simdi = simdi ?? DateTime.now;

  final ApiService _api;
  final AppDatabase _db;
  final DateTime Function() _simdi;

  /// How many briefings are kept on the phone.
  static const saklanan = 14;

  static const _ayarAnahtari = 'brifing.saat';

  // ---- Setting ----

  Future<BrifingAyari> ayar() async {
    final satir = await (_db.select(_db.ayarKayitlari)..where((t) => t.anahtar.equals(_ayarAnahtari))).getSingleOrNull();
    return BrifingAyari.oku(satir?.deger);
  }

  Future<void> ayarYaz(BrifingAyari ayar) => _db.into(_db.ayarKayitlari).insertOnConflictUpdate(
        AyarKayitlariCompanion.insert(anahtar: _ayarAnahtari, deger: ayar.depolama),
      );

  // ---- Reading ----

  /// Today's briefing from the server (which makes it now if the hour has passed). Without an answer (offline) or before the
  /// hour (404) the last briefing on the phone is returned with `guncel` false; with none on the phone the error is thrown.
  /// Any other failure (403, 503...) is thrown.
  Future<BrifingOkuma> bugun() async {
    try {
      final brifing = await _api.brifingBugun();
      await _sakla(brifing);
      return (brifing: brifing, guncel: true);
    } on DioException catch (e) {
      final kod = e.response?.statusCode;
      if (kod != null && kod != 404) rethrow;
      final yerel = await son();
      if (yerel == null) rethrow;
      return (brifing: yerel, guncel: false);
    }
  }

  /// The newest briefing the phone has; no network. Null when it never read one.
  Future<Brifing?> son() async {
    final satir = await (_db.select(_db.brifingOnbellek)
          ..orderBy([(t) => OrderingTerm.desc(t.gun)])
          ..limit(1))
        .getSingleOrNull();
    return satir == null ? null : Brifing.fromJson(jsonDecode(satir.govde) as Map<String, dynamic>);
  }

  // ---- Writing ----

  /// Sets the vote on card [sira] (1, -1, or 0 to take it back) and returns the briefing as the server now has it.
  Future<Brifing> oyVer(Brifing brifing, int sira, int oy) async {
    final yeni = await _api.brifingOyVer(brifing.gun, sira, oy);
    await _sakla(yeni);
    return yeni;
  }

  /// Asks for a new briefing for today (the Sahip; the server allows three a day).
  Future<Brifing> yenile() async {
    final yeni = await _api.brifingYenile();
    await _sakla(yeni);
    return yeni;
  }

  Future<void> _sakla(Brifing brifing) async {
    await _db.into(_db.brifingOnbellek).insertOnConflictUpdate(BrifingOnbellekCompanion.insert(
          gun: brifing.gun,
          govde: jsonEncode(brifing.toJson()),
          okunma: _simdi(),
        ));
    final tumu = await (_db.select(_db.brifingOnbellek)..orderBy([(t) => OrderingTerm.desc(t.gun)])).get();
    for (final eski in tumu.skip(saklanan)) {
      await (_db.delete(_db.brifingOnbellek)..where((t) => t.gun.equals(eski.gun))).go();
    }
  }
}
