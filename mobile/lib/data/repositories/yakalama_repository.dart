import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/yakalama.dart';
import '../services/api_service.dart';
import '../services/database/app_database.dart';
import '../services/fotograf_deposu.dart';
import 'bekleyen_uygula.dart';
import 'esitleyici.dart';

/// Captures: read from the API with a drift cache behind it, queued writes
/// laid on top ([yakalamalaraBekleyenleriUygula]). Every write goes to the
/// phone's queue first; the caller then asks [Esitleyici.gonder] to send it.
///
/// Listeners are told after every local write so lists reload.
class YakalamaRepository extends ChangeNotifier {
  YakalamaRepository({
    required this._api,
    required this._db,
    required this._esitleyici,
    FotografDeposu? fotograflar,
    DateTime Function()? simdi,
  })  : _fotograflar = fotograflar ?? FotografDeposu(),
        _simdi = simdi ?? DateTime.now;

  static const _uuid = Uuid();

  final ApiService _api;
  final AppDatabase _db;
  final Esitleyici _esitleyici;
  final FotografDeposu _fotograflar;
  final DateTime Function() _simdi;

  /// Fetches the captures and refreshes the cache. When the network is not
  /// reachable the cached list is returned instead; `cevrimdisi` says so.
  /// Queued writes are laid over both.
  Future<({List<YakalamaSatiri> liste, bool cevrimdisi})> listele() async {
    try {
      final liste = await _api.yakalamalariGetir();
      await _onbellegeYaz(liste);
      return (liste: await _bekleyenlerleBirlestir(liste), cevrimdisi: false);
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      return (liste: await yerelListe(), cevrimdisi: true);
    }
  }

  /// Cache plus queued writes; no network.
  Future<List<YakalamaSatiri>> yerelListe() async => _bekleyenlerleBirlestir(await _onbellektenOku());

  Future<YakalamaSatiri?> getir(String id) async => (await yerelListe()).where((s) => s.id == id).firstOrNull;

  Future<List<YakalamaSatiri>> _bekleyenlerleBirlestir(List<Yakalama> liste) async =>
      yakalamalaraBekleyenleriUygula(liste, await _esitleyici.bekleyenler(reddedilenler: true));

  Future<List<Yakalama>> _onbellektenOku() async {
    final satirlar = await (_db.select(_db.yakalamaOnbellek)..orderBy([(t) => OrderingTerm.asc(t.sira)])).get();
    return [for (final s in satirlar) Yakalama.fromJson(jsonDecode(s.govde) as Map<String, dynamic>)];
  }

  Future<void> _onbellegeYaz(List<Yakalama> liste) {
    return _db.transaction(() async {
      await _db.delete(_db.yakalamaOnbellek).go();
      await _db.batch((b) {
        b.insertAll(_db.yakalamaOnbellek, [
          for (var i = 0; i < liste.length; i++)
            YakalamaOnbellekCompanion.insert(id: liste[i].id, sira: i, govde: jsonEncode(liste[i].toJson())),
        ]);
      });
    });
  }

  /// Saves a new capture on the phone and queues it. Needs no network.
  /// [fotografKaynagi] is the picked file; a copy goes to the app's folder.
  Future<void> yakala({String? metin, String? fotografKaynagi}) async {
    final yol = fotografKaynagi == null ? null : await _fotograflar.kopyala(fotografKaynagi);
    await _esitleyici.yakalamaKuyrugaAl(YakalamaGovde(
      yaz: YakalamaYaz(id: _uuid.v7(), metin: _bosYap(metin), yakalandiAt: _simdi()),
      fotografYolu: yol,
    ));
    notifyListeners();
  }

  /// Changes a capture that waits (on the phone or on the server). The
  /// capture time and the target stay as they were.
  ///
  /// The photo is kept unless [yeniFotografKaynagi] replaces it or
  /// [fotografKaldir] removes it.
  Future<void> guncelle(
    YakalamaSatiri mevcut, {
    String? metin,
    String? yeniFotografKaynagi,
    bool fotografKaldir = false,
  }) async {
    String? fotografId = mevcut.fotografId;
    String? fotografYolu = mevcut.fotografYolu;
    if (yeniFotografKaynagi != null) {
      fotografId = null;
      fotografYolu = await _fotograflar.kopyala(yeniFotografKaynagi);
    } else if (fotografKaldir) {
      fotografId = null;
      fotografYolu = null;
    }
    final eski = await _esitleyici.yakalamaDegistir(
      mevcut.id,
      YakalamaGovde(
        yaz: YakalamaYaz(
          id: mevcut.id,
          metin: _bosYap(metin),
          fotografId: fotografId,
          hedef: mevcut.hedef,
          yakalandiAt: mevcut.yakalandiAt,
        ),
        fotografYolu: fotografYolu,
      ),
    );
    if (eski?.fotografYolu != fotografYolu) yerelDosyaSil(eski?.fotografYolu);
    notifyListeners();
  }

  /// Deletes a capture that waits. One that never reached the server only
  /// leaves the queue; the server hears nothing about it.
  Future<void> sil(String id) async {
    for (final yol in await _esitleyici.yakalamaSilKuyrugaAl(id)) {
      yerelDosyaSil(yol);
    }
    notifyListeners();
  }

  /// Sign-out: removes the photo copies of the captures still in the queue
  /// (the queue itself is wiped by [AppDatabase.hepsiniTemizle]).
  Future<void> yerelFotograflariSil() async {
    for (final b in await _esitleyici.bekleyenler(reddedilenler: true)) {
      if (b.tur != BekleyenTur.yakalamaEkle && b.tur != BekleyenTur.yakalamaGuncelle) continue;
      yerelDosyaSil(YakalamaGovde.fromJson(jsonDecode(b.govde) as Map<String, dynamic>).fotografYolu);
    }
  }

  String? _bosYap(String? metin) {
    final t = metin?.trim() ?? '';
    return t.isEmpty ? null : t;
  }
}
