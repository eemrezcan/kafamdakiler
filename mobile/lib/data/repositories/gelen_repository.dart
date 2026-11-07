import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../models/gelen.dart';
import '../services/api_service.dart';
import '../services/database/app_database.dart';
import 'bekleyen_uygula.dart';
import 'esitleyici.dart';

/// The inbox: read from the API with a drift cache behind it, queued decisions laid on top
/// ([gelenKartlarinaBekleyenleriUygula]). Placing and deleting go to the phone's queue first; the caller then asks
/// [Esitleyici.gonder] to send them. Approving or rejecting a card's suggestion is the approval queue's job
/// (`EylemRepository`); its queued decisions are laid over the cards here too. "Suggest again" needs the network.
class GelenRepository extends ChangeNotifier {
  GelenRepository({required this._api, required this._db, required this._esitleyici});

  final ApiService _api;
  final AppDatabase _db;
  final Esitleyici _esitleyici;

  /// Fetches the cards and refreshes the cache. When the network is not reachable the cached list is returned instead;
  /// `cevrimdisi` says so. Queued decisions are laid over both. A server answer such as 403 (no `gelen.oku`
  /// permission) or 503 (brain off) is thrown.
  Future<({List<GelenKarti> liste, bool cevrimdisi})> listele() async {
    try {
      final liste = await _api.gelenGetir();
      await _onbellegeYaz(liste);
      return (liste: await _bekleyenlerleBirlestir(liste), cevrimdisi: false);
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      return (liste: await yerelListe(), cevrimdisi: true);
    }
  }

  /// Cache plus queued decisions; no network.
  Future<List<GelenKarti>> yerelListe() async => _bekleyenlerleBirlestir(await _onbellektenOku());

  Future<List<GelenKarti>> _bekleyenlerleBirlestir(List<GelenKarti> liste) async =>
      gelenKartlarinaBekleyenleriUygula(liste, await _esitleyici.bekleyenler());

  Future<List<GelenKarti>> _onbellektenOku() async {
    final satirlar = await (_db.select(_db.gelenOnbellek)..orderBy([(t) => OrderingTerm.asc(t.sira)])).get();
    return [for (final s in satirlar) GelenKarti.fromJson(jsonDecode(s.govde) as Map<String, dynamic>)];
  }

  Future<void> _onbellegeYaz(List<GelenKarti> liste) {
    return _db.transaction(() async {
      await _db.delete(_db.gelenOnbellek).go();
      await _db.batch((b) {
        b.insertAll(_db.gelenOnbellek, [
          for (var i = 0; i < liste.length; i++)
            GelenOnbellekCompanion.insert(id: liste[i].kimlik, sira: i, govde: jsonEncode(liste[i].toJson())),
        ]);
      });
    });
  }

  /// Places card [kart] by hand. Needs no network.
  Future<void> isle(String kart, GelenIsleGirdi girdi) async {
    await _esitleyici.gelenIsleKuyrugaAl(kart, girdi);
    notifyListeners();
  }

  Future<void> sil(String kart) async {
    await _esitleyici.gelenSilKuyrugaAl(kart);
    notifyListeners();
  }

  /// Asks Claude for a new suggestion now (the server waits for the answer). Needs the network; the errors are thrown.
  Future<GelenOneriYaniti> oneriIste(String kart) async {
    final yanit = await _api.gelenOner(kart);
    notifyListeners();
    return yanit;
  }
}
