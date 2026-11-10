import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/hatirlatici.dart';
import '../services/api_service.dart';
import '../services/database/app_database.dart';
import 'bekleyen_uygula.dart';
import 'esitleyici.dart';

/// Reminders: read from the API with a drift cache behind it, queued writes laid on top
/// ([hatirlaticilaraBekleyenleriUygula]). Every write goes to the phone's queue first; the caller then asks
/// [Esitleyici.gonder] to send it. Listeners are told after every local write so lists reload and the
/// notifications are planned again.
class HatirlaticiRepository extends ChangeNotifier {
  HatirlaticiRepository({
    required this._api,
    required this._db,
    required this._esitleyici,
  });

  static const _uuid = Uuid();

  final ApiService _api;
  final AppDatabase _db;
  final Esitleyici _esitleyici;

  /// Fetches the reminders and refreshes the cache. When the network is not reachable the cached list is returned
  /// instead; `cevrimdisi` says so. Queued writes are laid over both.
  Future<({List<Hatirlatici> liste, bool cevrimdisi})> listele() async {
    try {
      final liste = await _api.hatirlaticilariGetir();
      await _onbellegeYaz(liste);
      return (liste: await _bekleyenlerleBirlestir(liste), cevrimdisi: false);
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      return (liste: await yerelListe(), cevrimdisi: true);
    }
  }

  /// Cache plus queued writes, soonest first; no network.
  Future<List<Hatirlatici>> yerelListe() async => _bekleyenlerleBirlestir(await _onbellektenOku());

  Future<Hatirlatici?> getir(String id) async => (await yerelListe()).where((h) => h.id == id).firstOrNull;

  Future<List<Hatirlatici>> _bekleyenlerleBirlestir(List<Hatirlatici> liste) async {
    final birlesik = hatirlaticilaraBekleyenleriUygula(liste, await _esitleyici.bekleyenler());
    return birlesik..sort((a, b) {
      final an = a.etkinAn.compareTo(b.etkinAn);
      return an != 0 ? an : a.id.compareTo(b.id);
    });
  }

  Future<List<Hatirlatici>> _onbellektenOku() async {
    final satirlar = await (_db.select(_db.hatirlaticiOnbellek)..orderBy([(t) => OrderingTerm.asc(t.sira)])).get();
    return [for (final s in satirlar) Hatirlatici.fromJson(jsonDecode(s.govde) as Map<String, dynamic>)];
  }

  Future<void> _onbellegeYaz(List<Hatirlatici> liste) {
    return _db.transaction(() async {
      await _db.delete(_db.hatirlaticiOnbellek).go();
      await _db.batch((b) {
        b.insertAll(_db.hatirlaticiOnbellek, [
          for (var i = 0; i < liste.length; i++)
            HatirlaticiOnbellekCompanion.insert(id: liste[i].id, sira: i, govde: jsonEncode(liste[i].toJson())),
        ]);
      });
    });
  }

  /// Saves a new reminder on the phone and queues it. Needs no network. Returns its id.
  Future<String> ekle(HatirlaticiYaz yaz) async {
    final id = _uuid.v7();
    await _esitleyici.hatirlaticiEkleKuyrugaAl(_idile(yaz, id));
    notifyListeners();
    return id;
  }

  Future<void> guncelle(String id, HatirlaticiYaz yaz) async {
    await _esitleyici.hatirlaticiGuncelleKuyrugaAl(id, _idile(yaz, id));
    notifyListeners();
  }

  Future<void> sil(String id) async {
    await _esitleyici.hatirlaticiSilKuyrugaAl(id);
    notifyListeners();
  }

  Future<void> yaptim(String id) async {
    await _esitleyici.hatirlaticiYaptimKuyrugaAl(id);
    notifyListeners();
  }

  /// [sure] is `1s` or `yarin` ([ErteleSuresi]).
  Future<void> ertele(String id, String sure) async {
    await _esitleyici.hatirlaticiErteleKuyrugaAl(id, sure);
    notifyListeners();
  }

  HatirlaticiYaz _idile(HatirlaticiYaz y, String id) => HatirlaticiYaz(
        id: id,
        baslik: y.baslik,
        not: y.not,
        tur: y.tur,
        kime: y.kime,
        gun: y.gun,
        saat: y.saat,
        tekrar: y.tekrar,
        onceGun: y.onceGun,
        durum: y.durum,
        israrli: y.israrli,
        israrAraligiDakika: y.israrAraligiDakika,
        israrEnCok: y.israrEnCok,
        acil: y.acil,
        gunler: y.gunler,
      );
}
