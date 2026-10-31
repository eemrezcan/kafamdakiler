import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../utils/aliskanlik_gunu.dart';
import '../models/gun.dart';
import '../models/oturum.dart';
import '../services/api_service.dart';
import '../services/database/app_database.dart';

/// Offline write queue and its sender.
///
/// Entries are written to the phone first ([gunYazKuyrugaAl], [gunSilKuyrugaAl],
/// [oturumKuyrugaAl]) and sent by [gonder], in the order they were made.
/// [gonder] is called after every write, when connectivity returns and when
/// the app comes to the foreground. Listeners are told whenever the queue
/// changed on the phone or entries reached the server.
class Esitleyici extends ChangeNotifier {
  Esitleyici({required this._api, required this._db, DateTime Function()? simdi})
      : _simdi = simdi ?? DateTime.now;

  static const _uuid = Uuid();

  final ApiService _api;
  final AppDatabase _db;
  final DateTime Function() _simdi;
  bool _calisiyor = false;
  bool _tekrarIstendi = false;

  /// Counts the sends that changed server state; screens reload when it moves.
  int _gonderimSayisi = 0;
  int get gonderimSayisi => _gonderimSayisi;

  /// Queues "the total of [tarih] is [govde]" for a Sayac habit.
  Future<String> gunYazKuyrugaAl(String aliskanlikId, DateTime tarih, GunYaz govde) {
    return _kuyrugaAl(
      id: _uuid.v7(),
      tur: BekleyenTur.gunYaz,
      hedefId: aliskanlikId,
      tarih: tarihMetni(tarih),
      govde: govde.toJson(),
    );
  }

  /// Queues "delete the record of [tarih]" (the day goes back to zero).
  Future<String> gunSilKuyrugaAl(String aliskanlikId, DateTime tarih) {
    return _kuyrugaAl(
      id: _uuid.v7(),
      tur: BekleyenTur.gunSil,
      hedefId: aliskanlikId,
      tarih: tarihMetni(tarih),
      govde: const {},
    );
  }

  /// Queues a session for an item. The Guid v7 is created here, so the server
  /// can recognise a repeated send.
  Future<String> oturumKuyrugaAl(String ogeId, OturumEkle ekle) {
    final id = _uuid.v7();
    final govde = OturumEkle(
      id: id,
      bitisKonum: ekle.bitisKonum,
      dakika: ekle.dakika,
      baslangicKonum: ekle.baslangicKonum,
      baslangicAni: ekle.baslangicAni,
    );
    return _kuyrugaAl(id: id, tur: BekleyenTur.oturumEkle, hedefId: ogeId, govde: govde.toJson());
  }

  Future<String> _kuyrugaAl({
    required String id,
    required BekleyenTur tur,
    required String hedefId,
    String? tarih,
    required Map<String, dynamic> govde,
  }) async {
    await _db.into(_db.bekleyenIslemler).insert(BekleyenIslemlerCompanion.insert(
          id: id,
          tur: tur,
          hedefId: hedefId,
          tarih: Value(tarih),
          govde: jsonEncode(govde),
          olusturulma: _simdi(),
        ));
    notifyListeners();
    return id;
  }

  /// Entries not sent yet (including refused ones when [reddedilenler] is true).
  Future<List<BekleyenIslemlerData>> bekleyenler({bool reddedilenler = false}) {
    final sorgu = _db.select(_db.bekleyenIslemler)
      ..where((t) => t.gonderildi.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.olusturulma), (t) => OrderingTerm.asc(t.id)]);
    if (!reddedilenler) sorgu.where((t) => t.hata.isNull());
    return sorgu.get();
  }

  /// Entries the server refused for good (shown on the profile screen).
  Future<List<BekleyenIslemlerData>> reddedilenler() {
    return (_db.select(_db.bekleyenIslemler)
          ..where((t) => t.gonderildi.equals(false) & t.hata.isNotNull())
          ..orderBy([(t) => OrderingTerm.asc(t.olusturulma)]))
        .get();
  }

  /// Removes one queue entry (the user dismissed a refused one).
  Future<void> sil(String id) async {
    await (_db.delete(_db.bekleyenIslemler)..where((t) => t.id.equals(id))).go();
    notifyListeners();
  }

  /// Sends the queue in order and returns how many entries were marked sent.
  ///
  /// - 2xx (including 200 for "this id already exists"): marked sent.
  /// - No answer (offline, timeout), 401, 408, 429, 5xx: stop and keep the
  ///   rest queued for the next call.
  /// - Any other 4xx: the server refused it for good; the reason is stored in
  ///   `hata` and the entry is skipped from now on.
  ///
  /// A call made while a send is running makes it run once more afterwards, so
  /// entries queued meanwhile are not left waiting.
  Future<int> gonder() async {
    if (_calisiyor) {
      _tekrarIstendi = true;
      return 0;
    }
    _calisiyor = true;
    var gonderilen = 0;
    var degisti = false;
    try {
      do {
        _tekrarIstendi = false;
        for (final islem in await bekleyenler()) {
          try {
            await _gonderTek(islem);
          } on DioException catch (e) {
            final kod = e.response?.statusCode;
            final kalici = kod != null && kod >= 400 && kod < 500 && kod != 401 && kod != 408 && kod != 429;
            if (!kalici) break;
            await (_db.update(_db.bekleyenIslemler)..where((t) => t.id.equals(islem.id)))
                .write(BekleyenIslemlerCompanion(hata: Value('$kod: ${e.response?.data}')));
            degisti = true;
            continue;
          }
          await (_db.update(_db.bekleyenIslemler)..where((t) => t.id.equals(islem.id)))
              .write(const BekleyenIslemlerCompanion(gonderildi: Value(true)));
          gonderilen++;
          degisti = true;
        }
      } while (_tekrarIstendi);
    } finally {
      _calisiyor = false;
    }
    if (gonderilen > 0) _gonderimSayisi++;
    if (degisti) notifyListeners();
    return gonderilen;
  }

  Future<void> _gonderTek(BekleyenIslemlerData islem) async {
    final govde = jsonDecode(islem.govde) as Map<String, dynamic>;
    switch (islem.tur) {
      case BekleyenTur.gunYaz:
        await _api.gunYaz(islem.hedefId, tarihCoz(islem.tarih!), GunYaz.fromJson(govde));
      case BekleyenTur.gunSil:
        try {
          await _api.gunSil(islem.hedefId, tarihCoz(islem.tarih!));
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) rethrow; // already gone
        }
      case BekleyenTur.oturumEkle:
        await _api.oturumEkle(islem.hedefId, OturumEkle.fromJson(govde));
    }
  }
}
