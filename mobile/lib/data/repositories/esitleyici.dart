import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../utils/aliskanlik_gunu.dart';
import '../models/gun.dart';
import '../models/hatirlatici.dart';
import '../models/oturum.dart';
import '../models/yakalama.dart';
import '../services/api_service.dart';
import '../services/database/app_database.dart';

/// Offline write queue and its sender.
///
/// Entries are written to the phone first ([gunYazKuyrugaAl], [gunSilKuyrugaAl],
/// [oturumKuyrugaAl], [yakalamaKuyrugaAl], [yakalamaDegistir],
/// [yakalamaSilKuyrugaAl]) and sent by [gonder], in the order they were made.
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

  /// Queues a new capture. [govde]`.yaz.id` is its Guid v7; the queue id is the
  /// same, so the server can recognise a repeated send.
  Future<String> yakalamaKuyrugaAl(YakalamaGovde govde) {
    final id = govde.yaz.id!;
    return _kuyrugaAl(id: id, tur: BekleyenTur.yakalamaEkle, hedefId: id, govde: govde.toJson());
  }

  /// Queues "the capture [id] becomes [govde]". When the capture still has an
  /// unsent entry (new, or an earlier edit; a refused one too) that entry's
  /// body is replaced instead and its refusal cleared, so it is tried again.
  /// Returns the replaced body, or null when a new entry was queued.
  Future<YakalamaGovde?> yakalamaDegistir(String id, YakalamaGovde govde) async {
    final eski = await _yakalamaKayitlari(id, [BekleyenTur.yakalamaEkle, BekleyenTur.yakalamaGuncelle]);
    if (eski.isEmpty) {
      await _kuyrugaAl(id: _uuid.v7(), tur: BekleyenTur.yakalamaGuncelle, hedefId: id, govde: govde.toJson());
      return null;
    }
    // Several unsent entries cannot exist (an edit rewrites the first one);
    // the first in queue order is the one to rewrite.
    final satir = eski.first;
    await (_db.update(_db.bekleyenIslemler)..where((t) => t.id.equals(satir.id))).write(
      BekleyenIslemlerCompanion(govde: Value(jsonEncode(govde.toJson())), hata: const Value(null)),
    );
    notifyListeners();
    return YakalamaGovde.fromJson(jsonDecode(satir.govde) as Map<String, dynamic>);
  }

  /// Queues "delete the capture [id]". A capture that never reached the server
  /// is just taken out of the queue and nothing is sent. Returns the local
  /// photo copies of the entries that were dropped, for the caller to delete.
  Future<List<String>> yakalamaSilKuyrugaAl(String id) async {
    final bekleyen = await _yakalamaKayitlari(id, BekleyenTur.values.where(_yakalamaTuru).toList());
    final sunucuda = !bekleyen.any((b) => b.tur == BekleyenTur.yakalamaEkle);
    final dosyalar = <String>[];
    for (final b in bekleyen) {
      final yol = b.tur == BekleyenTur.yakalamaSil
          ? null
          : YakalamaGovde.fromJson(jsonDecode(b.govde) as Map<String, dynamic>).fotografYolu;
      if (yol != null) dosyalar.add(yol);
    }
    await (_db.delete(_db.bekleyenIslemler)
          ..where((t) => t.id.isIn([for (final b in bekleyen) b.id])))
        .go();
    if (sunucuda) {
      await _kuyrugaAl(id: _uuid.v7(), tur: BekleyenTur.yakalamaSil, hedefId: id, govde: const {});
    } else {
      notifyListeners();
    }
    return dosyalar;
  }

  static bool _yakalamaTuru(BekleyenTur t) =>
      t == BekleyenTur.yakalamaEkle || t == BekleyenTur.yakalamaGuncelle || t == BekleyenTur.yakalamaSil;

  /// Unsent entries (refused ones included) of capture [id], in queue order.
  Future<List<BekleyenIslemlerData>> _yakalamaKayitlari(String id, List<BekleyenTur> turler) {
    return (_db.select(_db.bekleyenIslemler)
          ..where((t) => t.gonderildi.equals(false) & t.hedefId.equals(id) & t.tur.isInValues(turler))
          ..orderBy([(t) => OrderingTerm.asc(t.olusturulma), (t) => OrderingTerm.asc(t.id)]))
        .get();
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
  /// - No answer (offline, timeout), 401, 408, 429, 5xx, and the 409 "being sent
  ///   to the brain right now": stop and keep the rest queued for the next call.
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
        for (final siradaki in await bekleyenler()) {
          // A capture entry can be edited or dropped by the user while the
          // queue is being sent (a photo upload takes a while): read it again.
          final islem = _yakalamaTuru(siradaki.tur) ? await _satir(siradaki.id) : siradaki;
          if (islem == null || islem.gonderildi || islem.hata != null) continue;
          try {
            await _gonderTek(islem);
          } on _KaliciHata catch (e) {
            await (_db.update(_db.bekleyenIslemler)..where((t) => t.id.equals(islem.id)))
                .write(BekleyenIslemlerCompanion(hata: Value(e.mesaj)));
            degisti = true;
            continue;
          } on DioException catch (e) {
            final kod = e.response?.statusCode;
            final kalici = kod != null && kod >= 400 && kod < 500 && kod != 401 && kod != 408 && kod != 429;
            if (!kalici || _gonderiliyor(e)) break;
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

  // Reminders. Every write is queued as its own entry and sent in order (the server knows the client id, so a
  // repeated send is harmless); no entry is merged or dropped.

  /// Queues a new reminder; [yaz]`.id` is its Guid v7 and the queue id.
  Future<String> hatirlaticiEkleKuyrugaAl(HatirlaticiYaz yaz) =>
      _kuyrugaAl(id: yaz.id!, tur: BekleyenTur.hatirlaticiEkle, hedefId: yaz.id!, govde: yaz.toJson());

  Future<String> hatirlaticiGuncelleKuyrugaAl(String id, HatirlaticiYaz yaz) =>
      _kuyrugaAl(id: _uuid.v7(), tur: BekleyenTur.hatirlaticiGuncelle, hedefId: id, govde: yaz.toJson());

  Future<String> hatirlaticiSilKuyrugaAl(String id) =>
      _kuyrugaAl(id: _uuid.v7(), tur: BekleyenTur.hatirlaticiSil, hedefId: id, govde: const {});

  Future<String> hatirlaticiYaptimKuyrugaAl(String id) =>
      _kuyrugaAl(id: _uuid.v7(), tur: BekleyenTur.hatirlaticiYaptim, hedefId: id, govde: const {});

  /// [sure] is `1s` or `yarin` ([ErteleSuresi]).
  Future<String> hatirlaticiErteleKuyrugaAl(String id, String sure) =>
      _kuyrugaAl(id: _uuid.v7(), tur: BekleyenTur.hatirlaticiErtele, hedefId: id, govde: {'sure': sure});

  Future<BekleyenIslemlerData?> _satir(String id) =>
      (_db.select(_db.bekleyenIslemler)..where((t) => t.id.equals(id))).getSingleOrNull();

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
      case BekleyenTur.yakalamaEkle || BekleyenTur.yakalamaGuncelle:
        await _yakalamaGonder(islem, YakalamaGovde.fromJson(govde));
      case BekleyenTur.yakalamaSil:
        try {
          await _api.yakalamaSil(islem.hedefId);
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) rethrow; // already gone
        }
      case BekleyenTur.hatirlaticiEkle:
        await _api.hatirlaticiOlustur(HatirlaticiYaz.fromJson(govde));
      case BekleyenTur.hatirlaticiGuncelle:
        await _api.hatirlaticiGuncelle(islem.hedefId, HatirlaticiYaz.fromJson(govde));
      case BekleyenTur.hatirlaticiSil:
        try {
          await _api.hatirlaticiSil(islem.hedefId);
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) rethrow; // already gone
        }
      case BekleyenTur.hatirlaticiYaptim:
      case BekleyenTur.hatirlaticiErtele:
        try {
          if (islem.tur == BekleyenTur.hatirlaticiYaptim) {
            await _api.hatirlaticiYaptim(islem.hedefId);
          } else {
            await _api.hatirlaticiErtele(islem.hedefId, govde['sure'] as String);
          }
        } on DioException catch (e) {
          // 404: deleted meanwhile. 409: not open any more (done on another device, or a double tap on a one-off).
          // Both leave nothing to do, so they are not shown as refused entries.
          final kod = e.response?.statusCode;
          if (kod != 404 && kod != 409) rethrow;
        }
    }
  }

  /// 409 "the capture is being sent to the brain right now": temporary, the same
  /// entry works a moment later. The other 409s (the capture already left
  /// `bekliyor`) stay permanent. The server's message carries the word "gönderiliyor"
  /// (YakalamaIslemleri.GonderiliyorMesaji); a test on both sides keeps them in step.
  static bool _gonderiliyor(DioException e) =>
      e.response?.statusCode == 409 && '${e.response?.data}'.contains('gönderiliyor');

  /// Uploads the photo first (once), writes the returned id into the queued
  /// body, then sends the capture. A retry after a failed send finds the id in
  /// the body and does not upload the photo again.
  Future<void> _yakalamaGonder(BekleyenIslemlerData islem, YakalamaGovde govde) async {
    if (govde.yuklenecekFotografVar) {
      final yol = govde.fotografYolu!;
      if (!File(yol).existsSync()) throw const _KaliciHata('Fotoğraf dosyası telefonda bulunamadı.');
      final yuklenen = await _api.dosyaYukle(yol);
      final y = govde.yaz;
      govde = YakalamaGovde(
        yaz: YakalamaYaz(id: y.id, metin: y.metin, fotografId: yuklenen.id, hedef: y.hedef, yakalandiAt: y.yakalandiAt),
        fotografYolu: yol,
      );
      await (_db.update(_db.bekleyenIslemler)..where((t) => t.id.equals(islem.id)))
          .write(BekleyenIslemlerCompanion(govde: Value(jsonEncode(govde.toJson()))));
    }
    if (islem.tur == BekleyenTur.yakalamaEkle) {
      await _api.yakalamaOlustur(govde.yaz);
    } else {
      await _api.yakalamaGuncelle(islem.hedefId, govde.yaz);
    }
    yerelDosyaSil(govde.fotografYolu); // the server has the photo now
  }
}

/// A queued entry that can never be sent, for a reason other than a server answer.
class _KaliciHata implements Exception {
  const _KaliciHata(this.mesaj);

  final String mesaj;
}

/// Removes a photo copy kept in the app's folder; a missing file is fine.
void yerelDosyaSil(String? yol) {
  if (yol == null) return;
  try {
    File(yol).deleteSync();
  } on FileSystemException {
    // Already gone: nothing to clean up.
  }
}
