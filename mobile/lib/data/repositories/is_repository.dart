import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/beyin_yazma.dart';
import '../models/is_karti.dart';
import '../services/api_service.dart';
import '../services/database/app_database.dart';

/// What a write on a card answered: the card as it is now, or (when the brain's answer was unclear and the write may have
/// happened) a sentence to show and no card.
typedef IsYazmaSonucu = ({IsKarti? kart, String? uyari});

/// The work cards of the brain on the phone. The board is the only thing kept offline: the last one downloaded is shown when
/// there is no connection. A card's detail and every write need the server (a decision must not be taken on a stale card);
/// a failure is thrown as a [DioException] for the caller to turn into words. Listeners hear every successful write, so the
/// Bugün card and the board refresh themselves.
class IsRepository extends ChangeNotifier {
  IsRepository({required this._api, required this._db});

  final ApiService _api;
  final AppDatabase _db;

  static const _uuid = Uuid();
  static const _panoAnahtari = 'is.pano';

  /// The board: the open cards and the ones finished this week. With no answer from the server (offline) the last board
  /// on the phone is returned and `cevrimdisi` says so; with none on the phone the error is thrown. Without the permission
  /// (403) the phone forgets the board.
  Future<({List<IsKarti> liste, bool cevrimdisi})> panoyuGetir() async {
    try {
      final liste = await _api.islerGetir(kapali: true);
      await _panoYaz(liste);
      return (liste: liste, cevrimdisi: false);
    } on DioException catch (e) {
      if (e.response == null) {
        final yerel = await yerelPano();
        if (yerel != null) return (liste: yerel, cevrimdisi: true);
      } else if (e.response!.statusCode == 403) {
        await _panoYaz(const []);
      }
      rethrow;
    }
  }

  /// The board last downloaded, no network; null when there is none.
  Future<List<IsKarti>?> yerelPano() async {
    final satir = await (_db.select(_db.ayarKayitlari)..where((t) => t.anahtar.equals(_panoAnahtari))).getSingleOrNull();
    if (satir == null) return null;
    try {
      return [for (final k in jsonDecode(satir.deger) as List) IsKarti.fromJson(k as Map<String, dynamic>)];
    } on Object {
      return null;
    }
  }

  Future<void> _panoYaz(List<IsKarti> liste) => _db.into(_db.ayarKayitlari).insertOnConflictUpdate(
        AyarKayitlariCompanion.insert(anahtar: _panoAnahtari, deger: jsonEncode([for (final k in liste) k.toJson()])),
      );

  /// Sign-out: nothing of the account stays on the phone.
  Future<void> temizle() => (_db.delete(_db.ayarKayitlari)..where((t) => t.anahtar.equals(_panoAnahtari))).go();

  Future<IsAyrinti> ayrinti(String kimlik) => _api.isGetir(kimlik);

  // ---- Writes ----

  /// Opens a card. [anahtar] is the `Idempotency-Key`: the form keeps one for the card it is making, so a send repeated after
  /// a timeout does not open it twice.
  Future<IsYazmaSonucu> ac(IsAcGirdi girdi, {String? anahtar}) =>
      _yaz('/api/isler', girdi.toJson(), anahtar);

  Future<IsYazmaSonucu> cevapla(String kimlik, int soruNo, String cevap) =>
      _yaz('/api/isler/${Uri.encodeComponent(kimlik)}/cevap', {'soruNo': soruNo, 'cevap': cevap}, null);

  /// Moves the card. [asama] is the stage it goes to; [gerekce] goes only with `iptal`. The server adds the approval when a gate is left.
  Future<IsYazmaSonucu> asamaDegistir(String kimlik, String asama, {String? gerekce, String? not}) =>
      _yaz('/api/isler/${Uri.encodeComponent(kimlik)}/asama', {'asama': asama, 'gerekce': ?gerekce, 'not': ?not}, null);

  Future<IsYazmaSonucu> notYaz(String kimlik, String metin) =>
      _yaz('/api/isler/${Uri.encodeComponent(kimlik)}/not', {'metin': metin}, null);

  Future<IsYazmaSonucu> _yaz(String yol, Map<String, dynamic> govde, String? anahtar) async {
    final sonuc = await _api.isYaz(yol, govde, anahtar: anahtar ?? _uuid.v4());
    notifyListeners();
    if (sonuc.durum == BeyinYazmaDurumu.tamam) return (kart: IsKarti.fromJson(sonuc.govde), uyari: null);
    return (kart: null, uyari: sonuc.uyari);
  }
}
