import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../utils/aliskanlik_gunu.dart';
import '../models/zaman_cizelgesi.dart';
import '../services/api_service.dart';
import '../services/database/app_database.dart';

/// A timeline and whether it is fresh from the server ([guncel]) or the phone's last copy of that day (offline).
typedef ZamanCizelgesiOkuma = ({ZamanCizelgesi cizelge, bool guncel});

/// The one timeline of a day (K2.3c): the day's events, timed reminders and plan items.
///
/// Read-only. Every answer is kept on the phone, so without a connection the last timeline read for that day is shown.
class ZamanCizelgesiRepository {
  ZamanCizelgesiRepository({required this._api, required this._db, DateTime Function()? simdi}) : _simdi = simdi ?? DateTime.now;

  final ApiService _api;
  final AppDatabase _db;
  final DateTime Function() _simdi;

  /// How many days are kept on the phone.
  static const saklanan = 14;

  /// Today by the rule shared with the brain (the day turns at 05:00).
  DateTime get bugun => aliskanlikGunu(_simdi());

  /// The day from the server and kept. Without an answer (offline) the phone's copy is returned with `guncel` false; with none
  /// on the phone the error is thrown. Any answer from the server that is an error (403, 5xx...) is thrown.
  Future<ZamanCizelgesiOkuma> oku(DateTime tarih) async {
    try {
      final cizelge = await _api.zamanCizelgesi(tarihMetni(tarih));
      await _sakla(cizelge);
      return (cizelge: cizelge, guncel: true);
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      final yerel = await this.yerel(tarih);
      if (yerel == null) rethrow;
      return (cizelge: yerel, guncel: false);
    }
  }

  /// The phone's copy of the day; no network. Null when the day was never read.
  Future<ZamanCizelgesi?> yerel(DateTime tarih) async {
    final satir = await (_db.select(_db.zamanCizelgesiOnbellek)..where((t) => t.gun.equals(tarihMetni(tarih)))).getSingleOrNull();
    return satir == null ? null : ZamanCizelgesi.fromJson(jsonDecode(satir.govde) as Map<String, dynamic>);
  }

  Future<void> _sakla(ZamanCizelgesi cizelge) async {
    await _db.into(_db.zamanCizelgesiOnbellek).insertOnConflictUpdate(ZamanCizelgesiOnbellekCompanion.insert(
          gun: cizelge.gun,
          govde: jsonEncode(cizelge.toJson()),
          okunma: _simdi(),
        ));
    final tumu = await (_db.select(_db.zamanCizelgesiOnbellek)..orderBy([(t) => OrderingTerm.desc(t.gun)])).get();
    for (final eski in tumu.skip(saklanan)) {
      await (_db.delete(_db.zamanCizelgesiOnbellek)..where((t) => t.gun.equals(eski.gun))).go();
    }
  }
}
