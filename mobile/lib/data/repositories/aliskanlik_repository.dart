import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../utils/aliskanlik_gunu.dart';
import '../models/aliskanlik.dart';
import '../models/gun.dart';
import '../models/giris.dart';
import '../models/oge.dart';
import '../models/oturum.dart';
import '../services/api_service.dart';
import '../services/database/app_database.dart';
import 'bekleyen_uygula.dart';
import 'esitleyici.dart';

/// Habits, shelf items and sessions: read from the API with a drift cache
/// behind it, queued writes laid on top ([bekleyenleriUygula]).
///
/// Listeners are told after every create/update/delete so lists reload.
class AliskanlikRepository extends ChangeNotifier {
  AliskanlikRepository({
    required this._api,
    required this._db,
    required this._esitleyici,
    DateTime Function()? simdi,
  }) : _simdi = simdi ?? DateTime.now;

  final ApiService _api;
  final AppDatabase _db;
  final Esitleyici _esitleyici;
  final DateTime Function() _simdi;
  final Map<String, Future<Uint8List>> _resimler = {};

  DateTime get bugun => aliskanlikGunu(_simdi());

  /// A server answer (even an error) is not "offline"; no answer is.
  bool _cevrimdisi(DioException e) => e.response == null;

  // ---- Habits ----

  /// Fetches the habits and refreshes the cache. When the network is not
  /// reachable the cached list is returned instead; `cevrimdisi` says so.
  /// Queued writes are laid over both.
  Future<({List<Aliskanlik> liste, bool cevrimdisi})> listele({bool arsiv = false}) async {
    try {
      final liste = await _api.aliskanliklariGetir(arsiv: arsiv);
      if (!arsiv) await _onbellegeYaz(liste);
      return (liste: await _bekleyenlerleBirlestir(liste), cevrimdisi: false);
    } on DioException catch (e) {
      if (!_cevrimdisi(e) || arsiv) rethrow;
      return (liste: await yerelListe(), cevrimdisi: true);
    }
  }

  /// Cache plus queued writes; no network. Used right after a local write.
  Future<List<Aliskanlik>> yerelListe() async => _bekleyenlerleBirlestir(await onbellektenOku());

  Future<List<Aliskanlik>> _bekleyenlerleBirlestir(List<Aliskanlik> liste) async =>
      bekleyenleriUygula(liste, await _esitleyici.bekleyenler(), bugun);

  Future<List<Aliskanlik>> onbellektenOku() async {
    final satirlar = await (_db.select(_db.aliskanlikOnbellek)
          ..orderBy([(t) => OrderingTerm.asc(t.sira)]))
        .get();
    return [
      for (final s in satirlar) Aliskanlik.fromJson(jsonDecode(s.govde) as Map<String, dynamic>),
    ];
  }

  Future<void> _onbellegeYaz(List<Aliskanlik> liste) {
    return _db.transaction(() async {
      await _db.delete(_db.aliskanlikOnbellek).go();
      await _db.batch((b) {
        b.insertAll(_db.aliskanlikOnbellek, [
          for (final a in liste)
            AliskanlikOnbellekCompanion.insert(
              id: a.id,
              sira: a.sira,
              govde: jsonEncode(a.toJson()),
            ),
        ]);
      });
    });
  }

  Future<Aliskanlik> aliskanlikGetir(String id) => _api.aliskanlikGetir(id);

  /// The last [gunSayisi] days up to today (inclusive); online only.
  Future<List<Gun>> sonGunler(String aliskanlikId, {int gunSayisi = 30}) {
    final bitis = bugun;
    return _api.gunleriGetir(aliskanlikId, bitis.subtract(Duration(days: gunSayisi - 1)), bitis);
  }

  Future<Aliskanlik> aliskanlikOlustur(AliskanlikYaz yaz) async {
    final a = await _api.aliskanlikOlustur(yaz);
    notifyListeners();
    return a;
  }

  Future<Aliskanlik> aliskanlikGuncelle(String id, AliskanlikYaz yaz) async {
    final a = await _api.aliskanlikGuncelle(id, yaz);
    notifyListeners();
    return a;
  }

  Future<void> aliskanlikSil(String id) async {
    await _api.aliskanlikSil(id);
    notifyListeners();
  }

  // ---- Shelf items ----

  /// Items of a shelf habit; same cache-fallback rule as [listele].
  Future<List<Oge>> ogeleriListele(String aliskanlikId) async {
    List<Oge> liste;
    try {
      liste = await _api.ogeleriGetir(aliskanlikId);
      await _db.transaction(() async {
        await (_db.delete(_db.ogeOnbellek)..where((t) => t.aliskanlikId.equals(aliskanlikId))).go();
        await _db.batch((b) {
          b.insertAll(_db.ogeOnbellek, [
            for (final o in liste)
              OgeOnbellekCompanion.insert(
                id: o.id,
                aliskanlikId: aliskanlikId,
                govde: jsonEncode(o.toJson()),
              ),
          ]);
        });
      });
    } on DioException catch (e) {
      if (!_cevrimdisi(e)) rethrow;
      final satirlar = await (_db.select(_db.ogeOnbellek)
            ..where((t) => t.aliskanlikId.equals(aliskanlikId)))
          .get();
      liste = [
        for (final s in satirlar) Oge.fromJson(jsonDecode(s.govde) as Map<String, dynamic>),
      ];
    }
    final bekleyen = await _esitleyici.bekleyenler();
    return [for (final o in liste) ogeyeBekleyenleriUygula(o, bekleyen)];
  }

  /// One item, with queued sessions applied; cache fallback when offline.
  Future<Oge> oge(String id) async {
    Oge o;
    try {
      o = await _api.ogeGetir(id);
      await _db.into(_db.ogeOnbellek).insertOnConflictUpdate(OgeOnbellekCompanion.insert(
            id: o.id,
            aliskanlikId: o.aliskanlikId,
            govde: jsonEncode(o.toJson()),
          ));
    } on DioException catch (e) {
      if (!_cevrimdisi(e)) rethrow;
      final satir = await (_db.select(_db.ogeOnbellek)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (satir == null) rethrow;
      o = Oge.fromJson(jsonDecode(satir.govde) as Map<String, dynamic>);
    }
    return ogeyeBekleyenleriUygula(o, await _esitleyici.bekleyenler());
  }

  Future<Oge> ogeOlustur(String aliskanlikId, OgeYaz yaz) async {
    final o = await _api.ogeOlustur(aliskanlikId, yaz);
    notifyListeners();
    return o;
  }

  Future<Oge> ogeGuncelle(String id, OgeYaz yaz) async {
    final o = await _api.ogeGuncelle(id, yaz);
    notifyListeners();
    return o;
  }

  Future<void> ogeSil(String id) async {
    await _api.ogeSil(id);
    notifyListeners();
  }

  // ---- Sessions ----

  Future<List<Oturum>> oturumlar(String ogeId) => _api.oturumlariGetir(ogeId);

  Future<void> oturumGuncelle(String id, OturumGuncelle g) async {
    await _api.oturumGuncelle(id, g);
    notifyListeners();
  }

  Future<void> oturumSil(String id) async {
    await _api.oturumSil(id);
    notifyListeners();
  }

  // ---- Files ----

  Future<DosyaYaniti> dosyaYukle(String yol) => _api.dosyaYukle(yol);

  /// Photo bytes by file id (the endpoint needs the bearer token), kept in
  /// memory so scrolling a grid does not download again. A failed download is
  /// forgotten so the next build retries.
  Future<Uint8List> resim(String dosyaId) {
    return _resimler.putIfAbsent(
      dosyaId,
      () => _api.dosyaGetir(dosyaId).then((v) => v, onError: (Object e) {
        _resimler.remove(dosyaId);
        throw e;
      }),
    );
  }

  void resimleriBirak() => _resimler.clear();
}
