import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../models/eylem.dart';
import '../services/api_service.dart';
import '../services/database/app_database.dart';
import 'bekleyen_uygula.dart';
import 'esitleyici.dart';

/// The approval queue: read from the API with a drift cache behind it, queued decisions laid on top
/// ([eylemlereBekleyenleriUygula]). Every decision goes to the phone's queue first; the caller then asks
/// [Esitleyici.gonder] to send it. Listeners are told after every local decision so lists reload.
class EylemRepository extends ChangeNotifier {
  EylemRepository({
    required this._api,
    required this._db,
    required this._esitleyici,
  });

  final ApiService _api;
  final AppDatabase _db;
  final Esitleyici _esitleyici;

  /// The statuses the screens show: the waiting ones, the applied ones (to undo) and the failed ones.
  static const _okunanlar = [EylemDurumu.bekliyor, EylemDurumu.uygulandi, EylemDurumu.hatali];

  /// Fetches the actions and refreshes the cache. When the network is not reachable the cached list is returned
  /// instead; `cevrimdisi` says so. Queued decisions are laid over both. A server answer such as 403 (no
  /// `eylem.oku` permission) is thrown.
  Future<({List<Eylem> liste, bool cevrimdisi})> listele() async {
    try {
      final liste = <Eylem>[];
      for (final durum in _okunanlar) {
        liste.addAll(await _api.eylemleriGetir(durum));
      }
      await _onbellegeYaz(liste);
      return (liste: await _bekleyenlerleBirlestir(liste), cevrimdisi: false);
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      return (liste: await yerelListe(), cevrimdisi: true);
    }
  }

  /// Cache plus queued decisions; no network.
  Future<List<Eylem>> yerelListe() async => _bekleyenlerleBirlestir(await _onbellektenOku());

  Future<Eylem?> getir(String id) async => (await yerelListe()).where((e) => e.id == id).firstOrNull;

  Future<List<Eylem>> _bekleyenlerleBirlestir(List<Eylem> liste) async =>
      eylemlereBekleyenleriUygula(liste, await _esitleyici.bekleyenler());

  Future<List<Eylem>> _onbellektenOku() async {
    final satirlar = await (_db.select(_db.eylemOnbellek)..orderBy([(t) => OrderingTerm.asc(t.sira)])).get();
    return [for (final s in satirlar) Eylem.fromJson(jsonDecode(s.govde) as Map<String, dynamic>)];
  }

  Future<void> _onbellegeYaz(List<Eylem> liste) {
    return _db.transaction(() async {
      // Which ones were announced already survives the refresh.
      final bildirilmis = {
        for (final s in await _db.select(_db.eylemOnbellek).get())
          if (s.bildirildi) s.id,
      };
      await _db.delete(_db.eylemOnbellek).go();
      await _db.batch((b) {
        b.insertAll(_db.eylemOnbellek, [
          for (var i = 0; i < liste.length; i++)
            EylemOnbellekCompanion.insert(
              id: liste[i].id,
              sira: i,
              govde: jsonEncode(liste[i].toJson()),
              bildirildi: Value(bildirilmis.contains(liste[i].id)),
            ),
        ]);
      });
    });
  }

  /// Approves [id]; with [yuk] the corrected payload is applied. Needs no network.
  Future<void> uygula(String id, {Map<String, dynamic>? yuk}) async {
    await _esitleyici.eylemUygulaKuyrugaAl(id, yuk: yuk);
    notifyListeners();
  }

  Future<void> reddet(String id, {bool birDahaOnerme = false}) async {
    await _esitleyici.eylemReddetKuyrugaAl(id, birDahaOnerme: birDahaOnerme);
    notifyListeners();
  }

  Future<void> geriAl(String id) async {
    await _esitleyici.eylemGeriAlKuyrugaAl(id);
    notifyListeners();
  }

  /// Waiting actions (after the queued decisions) that no notification was shown for yet.
  Future<List<Eylem>> bildirilmemisBekleyenler() async {
    final bildirilmis = {
      for (final s in await _db.select(_db.eylemOnbellek).get())
        if (s.bildirildi) s.id,
    };
    return [
      for (final e in await yerelListe())
        if (e.durum == EylemDurumu.bekliyor && !bildirilmis.contains(e.id)) e,
    ];
  }

  Future<void> bildirildiIsaretle(Iterable<String> idler) async {
    await (_db.update(_db.eylemOnbellek)..where((t) => t.id.isIn(idler.toList())))
        .write(const EylemOnbellekCompanion(bildirildi: Value(true)));
  }
}
