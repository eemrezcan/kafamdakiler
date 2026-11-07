import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../models/ben.dart';
import '../services/api_service.dart';
import '../services/database/app_database.dart';

/// Who is signed in and with which role, shared with `provider`.
/// The last answer of `GET /api/ben` is cached so the role is known offline.
class KullaniciRepository extends ChangeNotifier {
  KullaniciRepository({required this._api, required this._db});

  final ApiService _api;
  final AppDatabase _db;

  Ben? _ben;
  Ben? get ben => _ben;

  /// Only the Sahip role sees and may open the management screens (M07).
  bool get sahip => _ben?.sahip ?? false;

  /// The morning briefing (K2.7) is read with the `brifing.oku` permission; the Sahip always may.
  bool get brifingOkuyabilir => sahip || (_ben?.izinler.contains(brifingIzni) ?? false);

  static const brifingIzni = 'brifing.oku';

  /// Reads the cached answer (no network): called at app start.
  Future<void> baslat() async {
    final satir = await (_db.select(_db.kullaniciOnbellek)..where((t) => t.id.equals(1))).getSingleOrNull();
    if (satir != null) {
      _ben = Ben.fromJson(jsonDecode(satir.govde) as Map<String, dynamic>);
      notifyListeners();
    }
  }

  /// Asks the server; offline or on a server error the cached role is kept.
  Future<void> yukle() async {
    try {
      final ben = await _api.ben();
      _ben = ben;
      await _db.into(_db.kullaniciOnbellek).insertOnConflictUpdate(
            KullaniciOnbellekCompanion.insert(id: const Value(1), govde: jsonEncode(ben.toJson())),
          );
      notifyListeners();
    } on DioException {
      // keep what we know
    }
  }

  void temizle() {
    _ben = null;
    notifyListeners();
  }
}
