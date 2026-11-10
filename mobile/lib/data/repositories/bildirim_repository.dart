import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../models/bildirim_ogesi.dart';
import '../services/api_service.dart';
import '../services/database/app_database.dart';
import 'esitleyici.dart';

/// The notification centre (K-0024, sözleşme §6): the list with read marks, and the number on the bell.
///
/// The newest page is kept on the phone, so the list shows offline. A read mark is queued on the phone first ([Esitleyici]) and
/// laid on the list at once; older pages are read from the server only. Listeners are told after every local mark.
class BildirimRepository extends ChangeNotifier {
  BildirimRepository({required this._api, required this._db, required this._esitleyici});

  final ApiService _api;
  final AppDatabase _db;
  final Esitleyici _esitleyici;

  /// The size of a page, and so how many rows the newest page keeps.
  static const sayfaBoyu = 30;

  /// The newest page from the server, kept; without an answer (offline) the kept page with `cevrimdisi` true. Marks that wait in
  /// the queue are laid over both. Any other failure (403, 5xx) is thrown.
  Future<({List<BildirimOgesi> liste, bool cevrimdisi})> ilkSayfa() async {
    try {
      final liste = await _api.bildirimleriGetir(limit: sayfaBoyu);
      await _sakla(liste);
      return (liste: await _isaretlerle(liste), cevrimdisi: false);
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      final yerel = await _kayitli();
      if (yerel == null) rethrow;
      return (liste: await _isaretlerle(yerel), cevrimdisi: true);
    }
  }

  /// The page older than [once] (the time of the oldest row shown); server only.
  Future<List<BildirimOgesi>> dahaEski(DateTime once) async => _isaretlerle(await _api.bildirimleriGetir(once: once, limit: sayfaBoyu));

  /// The kept page; null when no page was ever read (an empty list that was read is an empty page, not "nothing kept").
  Future<List<BildirimOgesi>?> _kayitli() async {
    final satirlar = await (_db.select(_db.bildirimOnbellek)..orderBy([(t) => OrderingTerm.asc(t.sira)])).get();
    if (satirlar.isEmpty) {
      final okunmus = await (_db.select(_db.ayarKayitlari)..where((t) => t.anahtar.equals(_okunduAnahtari))).getSingleOrNull();
      return okunmus == null ? null : const [];
    }
    return [for (final s in satirlar) BildirimOgesi.fromJson(jsonDecode(s.govde) as Map<String, dynamic>)];
  }

  static const _okunduAnahtari = 'bildirim.liste.okundu';

  Future<void> _sakla(List<BildirimOgesi> liste) {
    return _db.transaction(() async {
      await _db.into(_db.ayarKayitlari).insertOnConflictUpdate(AyarKayitlariCompanion.insert(anahtar: _okunduAnahtari, deger: '1'));
      await _db.delete(_db.bildirimOnbellek).go();
      await _db.batch((b) {
        b.insertAll(_db.bildirimOnbellek, [
          for (var i = 0; i < liste.length; i++)
            BildirimOnbellekCompanion.insert(id: liste[i].id, sira: i, govde: jsonEncode(liste[i].toJson())),
        ]);
      });
    });
  }

  /// The marks still waiting in the queue: the ids, and whether "hepsi" is among them.
  Future<({Set<String> idler, bool hepsi})> _bekleyenIsaretler() async {
    final bekleyen = await _esitleyici.bekleyenler();
    return (
      idler: {for (final b in bekleyen) if (b.tur == BekleyenTur.bildirimOkundu) b.hedefId},
      hepsi: bekleyen.any((b) => b.tur == BekleyenTur.bildirimHepsiOkundu),
    );
  }

  Future<List<BildirimOgesi>> _isaretlerle(List<BildirimOgesi> liste) async {
    final isaret = await _bekleyenIsaretler();
    return [for (final b in liste) (isaret.hepsi || isaret.idler.contains(b.id)) && !b.okundu ? b.okunmus() : b];
  }

  /// How many are unread: the server's number, less the marks that wait in the queue.
  Future<int> okunmamisSayi() async {
    final sayi = await _api.bildirimSayisi();
    final isaret = await _bekleyenIsaretler();
    if (isaret.hepsi) return 0;
    final kalan = sayi - isaret.idler.length;
    return kalan < 0 ? 0 : kalan;
  }

  Future<void> okundu(String id) async {
    await _esitleyici.bildirimOkunduKuyrugaAl(id);
    notifyListeners();
  }

  Future<void> hepsiOkundu() async {
    await _esitleyici.bildirimHepsiOkunduKuyrugaAl();
    notifyListeners();
  }
}
