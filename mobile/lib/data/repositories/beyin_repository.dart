import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../models/beyin.dart';
import '../models/proje_repo.dart';
import '../services/api_service.dart';
import '../services/database/app_database.dart';

/// The second brain, read only (K-0023). Only the project list is kept on the
/// phone (Kat 1, karar 3), so the capture screen's project picker works offline;
/// the other reads (project, day plan, search, note) need the network and are not
/// cached. A read that fails with an HTTP status (403 no permission, 503 brain not
/// set up, ...) is thrown to the caller as a [DioException]; "no answer at all"
/// (offline) is thrown too, except for the project list, which falls back to the cache.
class BeyinRepository {
  BeyinRepository({required this._api, required this._db});

  final ApiService _api;
  final AppDatabase _db;

  /// Fetches the project list and replaces the cache with it. With no answer from
  /// the server (offline) the cached list is returned and `cevrimdisi` says so.
  Future<({List<ProjeOzet> liste, bool cevrimdisi})> projeleriGetir() async {
    try {
      final liste = await _api.beyinProjeleri();
      await _onbellegeYaz(liste);
      return (liste: liste, cevrimdisi: false);
    } on DioException catch (e) {
      if (e.response == null) return (liste: await yerelProjeler(), cevrimdisi: true);
      // Without the permission the phone does not keep the project names either.
      if (e.response!.statusCode == 403) await _onbellegeYaz(const []);
      rethrow;
    }
  }

  /// Refreshes the cache quietly (app start, picker): true when the server answered.
  Future<bool> projeleriYenile() async {
    try {
      return !(await projeleriGetir()).cevrimdisi;
    } on DioException {
      return false;
    }
  }

  /// The cached list, no network.
  Future<List<ProjeOzet>> yerelProjeler() async {
    final satirlar = await (_db.select(_db.projeOnbellek)..orderBy([(t) => OrderingTerm.asc(t.sira)])).get();
    return [for (final s in satirlar) ProjeOzet.fromJson(jsonDecode(s.govde) as Map<String, dynamic>)];
  }

  Future<void> _onbellegeYaz(List<ProjeOzet> liste) {
    return _db.transaction(() async {
      await _db.delete(_db.projeOnbellek).go();
      await _db.batch((b) {
        b.insertAll(_db.projeOnbellek, [
          for (var i = 0; i < liste.length; i++)
            ProjeOnbellekCompanion.insert(id: liste[i].kimlik, sira: i, govde: jsonEncode(liste[i].toJson())),
        ]);
      });
    });
  }

  Future<ProjeDetay> proje(String kimlik) => _api.beyinProje(kimlik);

  /// The project's repository card; null when none is linked. Needs the network, errors are thrown.
  Future<ProjeRepoOzeti?> projeRepo(String kimlik) => _api.beyinProjeRepo(kimlik);

  Future<List<AramaSonucu>> ara(String q, {String? proje}) => _api.beyinAra(q, proje: proje);

  Future<BeyinNotu> notuOku(String yol) => _api.beyinNot(yol);
}
