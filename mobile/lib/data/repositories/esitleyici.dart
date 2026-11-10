import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../utils/aliskanlik_gunu.dart';
import '../models/asistan.dart';
import '../models/gelen.dart';
import '../models/gun_gorunum.dart';
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
          String? uyari;
          try {
            uyari = await _gonderTek(islem);
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
                .write(BekleyenIslemlerCompanion(
                    hata: Value(_beyinTuru(islem.tur) || _gelenTuru(islem.tur) || _gunTuru(islem.tur) ? _ayrinti(e) : '$kod: ${e.response?.data}')));
            degisti = true;
            continue;
          }
          await (_db.update(_db.bekleyenIslemler)..where((t) => t.id.equals(islem.id)))
              .write(BekleyenIslemlerCompanion(gonderildi: const Value(true), uyari: Value(uyari)));
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

  // Approval queue decisions (K2.6). Each is its own entry, sent in order; a decision made twice is harmless
  // (the server answers 409, which is treated as "nothing left to do").

  /// Queues "approve action [id]"; [yuk] is the corrected payload, or null to apply the suggested one.
  Future<String> eylemUygulaKuyrugaAl(String id, {Map<String, dynamic>? yuk}) =>
      _kuyrugaAl(id: _uuid.v7(), tur: BekleyenTur.eylemUygula, hedefId: id, govde: {'yuk': ?yuk});

  /// Queues "reject action [id]"; [birDahaOnerme] also makes its kind forbidden on the server.
  Future<String> eylemReddetKuyrugaAl(String id, {bool birDahaOnerme = false}) =>
      _kuyrugaAl(id: _uuid.v7(), tur: BekleyenTur.eylemReddet, hedefId: id, govde: {'birDahaOnerme': birDahaOnerme});

  Future<String> eylemGeriAlKuyrugaAl(String id) =>
      _kuyrugaAl(id: _uuid.v7(), tur: BekleyenTur.eylemGeriAl, hedefId: id, govde: const {});

  // Day plan and task writes (K2.3a). Each is its own entry; the entry id is the `Idempotency-Key` of its send, so a send
  // repeated after a lost answer is applied once. [govde]`['istek']` is the request body; the other keys are what the
  // plan card needs to show the write before it is sent ([gunPlaninaBekleyenleriUygula]).

  /// Queues "add [metin] to the plan of [tarih]" (optionally in section [bolum]).
  Future<String> beyinMaddeEkleKuyrugaAl(DateTime tarih, {required String metin, String? bolum}) {
    final id = _uuid.v7();
    return _kuyrugaAl(
      id: id,
      tur: BekleyenTur.beyinMaddeEkle,
      hedefId: id,
      tarih: tarihMetni(tarih),
      govde: {
        'istek': {'metin': metin, 'bolum': ?bolum},
        'baslik': metin,
        'bolum': ?bolum,
      },
    );
  }

  /// Queues a tick of plan item [madde] on [tarih]; [geri] takes the tick away.
  Future<String> beyinMaddeIsaretleKuyrugaAl(DateTime tarih, String madde, {bool geri = false}) => _kuyrugaAl(
        id: _uuid.v7(),
        tur: BekleyenTur.beyinMaddeIsaretle,
        hedefId: madde,
        tarih: tarihMetni(tarih),
        govde: {
          'istek': {'madde': madde, 'geri': geri},
        },
      );

  /// Queues "carry [madde] of [tarih] to the next day". [baslik], [bolum] and [tahminDk] are kept so the next day's plan
  /// can show the item before it is sent.
  Future<String> beyinMaddeDevretKuyrugaAl(DateTime tarih, String madde, {required String baslik, String? bolum, int? tahminDk}) =>
      _kuyrugaAl(
        id: _uuid.v7(),
        tur: BekleyenTur.beyinMaddeDevret,
        hedefId: madde,
        tarih: tarihMetni(tarih),
        govde: {
          'istek': {'madde': madde},
          'baslik': baslik,
          'bolum': ?bolum,
          'tahminDk': ?tahminDk,
        },
      );

  Future<String> beyinMaddeNotKuyrugaAl(DateTime tarih, String madde, String metin) => _kuyrugaAl(
        id: _uuid.v7(),
        tur: BekleyenTur.beyinMaddeNot,
        hedefId: madde,
        tarih: tarihMetni(tarih),
        govde: {
          'istek': {'madde': madde, 'metin': metin},
        },
      );

  /// Queues a new task in project [proje] (optionally due on [bitis]).
  Future<String> beyinGorevEkleKuyrugaAl({required String baslik, required String proje, DateTime? bitis}) {
    final id = _uuid.v7();
    return _kuyrugaAl(
      id: id,
      tur: BekleyenTur.beyinGorevEkle,
      hedefId: id,
      govde: {
        'istek': {'baslik': baslik, 'proje': proje, 'bitis': ?(bitis == null ? null : tarihMetni(bitis))},
      },
    );
  }

  /// Queues "finish task [kimlik]". The server adds the app's own proof; none travels from the phone.
  Future<String> beyinGorevBitirKuyrugaAl(String kimlik) =>
      _kuyrugaAl(id: _uuid.v7(), tur: BekleyenTur.beyinGorevBitir, hedefId: kimlik, govde: {'istek': const {}});

  /// Queues "split task [kimlik] over [gunSayisi] days" from [baslangic] (default: the server's today).
  Future<String> beyinGunlereBolKuyrugaAl(String kimlik, {required int gunSayisi, DateTime? baslangic}) => _kuyrugaAl(
        id: _uuid.v7(),
        tur: BekleyenTur.beyinGunlereBol,
        hedefId: kimlik,
        govde: {
          'istek': {'gunSayisi': gunSayisi, 'baslangic': ?(baslangic == null ? null : tarihMetni(baslangic))},
        },
      );

  // The inbox (K2.2). A placement or a deletion is its own entry; sending it twice is harmless (the second try finds the
  // card gone, a 404, which counts as done).

  /// Queues "place card [kart] as [girdi]".
  Future<String> gelenIsleKuyrugaAl(String kart, GelenIsleGirdi girdi) =>
      _kuyrugaAl(id: _uuid.v7(), tur: BekleyenTur.gelenIsle, hedefId: kart, govde: girdi.toJson());

  /// Queues "delete card [kart]".
  Future<String> gelenSilKuyrugaAl(String kart) =>
      _kuyrugaAl(id: _uuid.v7(), tur: BekleyenTur.gelenSil, hedefId: kart, govde: const {});

  // The day view of the UI revision (`/api/gun`, `/api/ayarlar/gun`). Each write is its own entry; the entry id is the
  // `Idempotency-Key` where the server takes one. [govde]`['istek']` is the request body, the other keys are what the
  // screens need to show the write before it is sent ([gunGorunumuneBekleyenleriUygula]).

  /// Queues "done" (or, with [geri], "not done") for the row [kimlik] of [tarih].
  Future<String> gunYaptimKuyrugaAl(DateTime tarih, String kimlik, {bool geri = false}) => _kuyrugaAl(
        id: _uuid.v7(),
        tur: BekleyenTur.gunYaptim,
        hedefId: kimlik,
        tarih: tarihMetni(tarih),
        govde: {'geri': geri},
      );

  /// Queues a new "yapılacak" on [tarih].
  Future<String> gunOgeEkleKuyrugaAl(DateTime tarih, YeniOgeYaz yaz) {
    final id = _uuid.v7();
    return _kuyrugaAl(id: id, tur: BekleyenTur.gunOgeEkle, hedefId: id, tarih: tarihMetni(tarih), govde: yaz.toJson());
  }

  /// Queues the reminder of the row [kimlik]: set up, or with [guncelle] changed.
  Future<String> ogeHatirlaticiYazKuyrugaAl(DateTime tarih, String kimlik, HatirlaticiGovde govde, {required bool guncelle}) => _kuyrugaAl(
        id: _uuid.v7(),
        tur: BekleyenTur.ogeHatirlaticiYaz,
        hedefId: kimlik,
        tarih: tarihMetni(tarih),
        govde: {'guncelle': guncelle, 'istek': govde.toJson()},
      );

  Future<String> ogeHatirlaticiSilKuyrugaAl(DateTime tarih, String kimlik) =>
      _kuyrugaAl(id: _uuid.v7(), tur: BekleyenTur.ogeHatirlaticiSil, hedefId: kimlik, tarih: tarihMetni(tarih), govde: const {});

  /// Queues "let go of [maddeId], left open on yesterday's plan"; [tarih] is today.
  Future<String> dundenBirakKuyrugaAl(DateTime tarih, String maddeId) =>
      _kuyrugaAl(id: _uuid.v7(), tur: BekleyenTur.dundenBirak, hedefId: maddeId, tarih: tarihMetni(tarih), govde: const {});

  /// Queues the new day capacity.
  Future<String> ayarGunYazKuyrugaAl(GunAyari ayar) {
    final id = _uuid.v7();
    return _kuyrugaAl(id: id, tur: BekleyenTur.ayarGunYaz, hedefId: id, govde: ayar.toJson());
  }

  /// Queues "carry [kimlik] of [tarih] to the next day" (sözleşme E2). [baslik], [bolum] and [tahminDk] are kept so the next
  /// day's list can show the row before it is sent.
  Future<String> gunDevretKuyrugaAl(DateTime tarih, String kimlik, {required String baslik, String? bolum, int? tahminDk}) => _kuyrugaAl(
        id: _uuid.v7(),
        tur: BekleyenTur.gunDevret,
        hedefId: kimlik,
        tarih: tarihMetni(tarih),
        govde: {'baslik': baslik, 'bolum': ?bolum, 'tahminDk': ?tahminDk},
      );

  // The assistant's one input and the notification marks (M2).

  /// Queues an input for the assistant. [girdi]`.id` is the queue id; [fotografYolu] is the local copy of a photo, uploaded when
  /// the entry is sent (the photo id then goes into the body).
  Future<String> asistanGirdiKuyrugaAl(AsistanGirdisi girdi, {String? fotografYolu}) => _kuyrugaAl(
        id: girdi.id,
        tur: BekleyenTur.asistanGirdi,
        hedefId: girdi.id,
        govde: {'girdi': girdi.toJson(), 'fotografYolu': ?fotografYolu},
      );

  /// Queues the answer to the assistant's question [soruId].
  Future<String> asistanCevapKuyrugaAl(String soruId, String cevap) =>
      _kuyrugaAl(id: _uuid.v7(), tur: BekleyenTur.asistanCevap, hedefId: soruId, govde: {'cevap': cevap});

  Future<String> bildirimOkunduKuyrugaAl(String id) =>
      _kuyrugaAl(id: _uuid.v7(), tur: BekleyenTur.bildirimOkundu, hedefId: id, govde: const {});

  Future<String> bildirimHepsiOkunduKuyrugaAl() =>
      _kuyrugaAl(id: _uuid.v7(), tur: BekleyenTur.bildirimHepsiOkundu, hedefId: 'hepsi', govde: const {});

  /// Sent entries the user should still look at (an unclear answer, a split that stopped half way), oldest first.
  Future<List<BekleyenIslemlerData>> uyarilar() {
    return (_db.select(_db.bekleyenIslemler)
          ..where((t) => t.gonderildi.equals(true) & t.uyari.isNotNull())
          ..orderBy([(t) => OrderingTerm.asc(t.olusturulma)]))
        .get();
  }

  static bool _beyinTuru(BekleyenTur t) => switch (t) {
        BekleyenTur.beyinMaddeEkle ||
        BekleyenTur.beyinMaddeIsaretle ||
        BekleyenTur.beyinMaddeDevret ||
        BekleyenTur.beyinMaddeNot ||
        BekleyenTur.beyinGorevEkle ||
        BekleyenTur.beyinGorevBitir ||
        BekleyenTur.beyinGunlereBol =>
          true,
        _ => false,
      };

  static bool _gelenTuru(BekleyenTur t) => t == BekleyenTur.gelenIsle || t == BekleyenTur.gelenSil;

  /// The writes of the day view: their refusals are ProblemDetails of the new API too.
  static bool _gunTuru(BekleyenTur t) => switch (t) {
        BekleyenTur.gunYaptim ||
        BekleyenTur.gunOgeEkle ||
        BekleyenTur.ogeHatirlaticiYaz ||
        BekleyenTur.ogeHatirlaticiSil ||
        BekleyenTur.dundenBirak ||
        BekleyenTur.ayarGunYaz ||
        BekleyenTur.gunDevret ||
        BekleyenTur.asistanGirdi ||
        BekleyenTur.asistanCevap ||
        BekleyenTur.bildirimOkundu ||
        BekleyenTur.bildirimHepsiOkundu =>
          true,
        _ => false,
      };

  /// The reason in a refusal of the brain API (a ProblemDetails): its `detail`, else its `title`, else the status.
  static String _ayrinti(DioException e) {
    final veri = e.response?.data;
    if (veri is Map) {
      final detay = veri['detail'] ?? veri['title'];
      final alanlar = veri['errors'];
      if (alanlar is Map && alanlar.isNotEmpty) {
        return alanlar.values.expand((m) => m is List ? m : [m]).join(' ');
      }
      if (detay is String && detay.isNotEmpty) return detay;
    }
    return 'Sunucu reddetti (${e.response?.statusCode}).';
  }

  Future<BekleyenIslemlerData?> _satir(String id) =>
      (_db.select(_db.bekleyenIslemler)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Sends one entry. Returns a note for the user when the server accepted it without a clear "done" (see
  /// [BeyinYazmaSonucu.uyari]), else null.
  Future<String?> _gonderTek(BekleyenIslemlerData islem) async {
    final govde = jsonDecode(islem.govde) as Map<String, dynamic>;
    if (_beyinTuru(islem.tur)) return _beyinGonder(islem, govde);
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
      case BekleyenTur.eylemUygula || BekleyenTur.eylemReddet || BekleyenTur.eylemGeriAl:
        try {
          switch (islem.tur) {
            case BekleyenTur.eylemUygula:
              await _api.eylemUygula(islem.hedefId, yuk: govde['yuk'] as Map<String, dynamic>?);
            case BekleyenTur.eylemReddet:
              await _api.eylemReddet(islem.hedefId, birDahaOnerme: govde['birDahaOnerme'] as bool? ?? false);
            default:
              await _api.eylemGeriAl(islem.hedefId);
          }
        } on DioException catch (e) {
          // 409: already decided (on the web, or this entry was sent once before). Nothing left to do. A 404 or 400
          // (the corrected payload broke the rules) or 403 is shown as a refused entry on the profile screen.
          if (e.response?.statusCode != 409) rethrow;
        }
      case BekleyenTur.gelenIsle || BekleyenTur.gelenSil:
        try {
          if (islem.tur == BekleyenTur.gelenIsle) {
            await _api.gelenIsle(islem.hedefId, GelenIsleGirdi.fromJson(govde));
          } else {
            await _api.gelenSil(islem.hedefId);
          }
        } on DioException catch (e) {
          // 404: the card is gone (placed on the web or the laptop, or this entry was sent once before). Nothing left to do.
          // A 400 (the path or a tag broke the rules) or 403 is shown as a refused entry on the profile screen.
          if (e.response?.statusCode != 404) rethrow;
        }
      case BekleyenTur.gunYaptim:
        await _api.gunYaptim(islem.tarih!, islem.hedefId, geri: govde['geri'] == true, anahtar: islem.id);
      case BekleyenTur.gunOgeEkle:
        await _api.gunOgeEkle(islem.tarih!, YeniOgeYaz.fromJson(govde), anahtar: islem.id);
      case BekleyenTur.ogeHatirlaticiYaz:
        await _api.ogeHatirlaticiYaz(
          islem.tarih!,
          islem.hedefId,
          HatirlaticiGovde.fromJson(Map<String, dynamic>.from(govde['istek'] as Map)),
          guncelle: govde['guncelle'] == true,
        );
      case BekleyenTur.ogeHatirlaticiSil:
        try {
          await _api.ogeHatirlaticiSil(islem.tarih!, islem.hedefId);
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) rethrow; // already gone
        }
      case BekleyenTur.dundenBirak:
        try {
          await _api.dundenBirak(islem.tarih!, islem.hedefId);
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) rethrow; // the item is gone from yesterday's list already
        }
      case BekleyenTur.ayarGunYaz:
        await _api.gunAyariYaz(GunAyari.fromJson(govde));
      case BekleyenTur.gunDevret:
        await _api.gunDevret(islem.tarih!, islem.hedefId, anahtar: islem.id);
      case BekleyenTur.asistanGirdi:
        await _asistanGonder(islem, govde);
      case BekleyenTur.asistanCevap:
        try {
          await _api.asistanSoruCevap(islem.hedefId, govde['cevap'] as String);
        } on DioException catch (e) {
          // 404 or 409: the question is gone or was answered elsewhere. Nothing left to do.
          final kod = e.response?.statusCode;
          if (kod != 404 && kod != 409) rethrow;
        }
      case BekleyenTur.bildirimOkundu:
        try {
          await _api.bildirimOkundu(islem.hedefId);
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) rethrow; // gone already
        }
      case BekleyenTur.bildirimHepsiOkundu:
        await _api.bildirimlerinHepsiOkundu();
      case BekleyenTur.beyinMaddeEkle ||
            BekleyenTur.beyinMaddeIsaretle ||
            BekleyenTur.beyinMaddeDevret ||
            BekleyenTur.beyinMaddeNot ||
            BekleyenTur.beyinGorevEkle ||
            BekleyenTur.beyinGorevBitir ||
            BekleyenTur.beyinGunlereBol:
        break; // handled above
    }
    return null;
  }

  /// The brain writes. 200 is done; 202 and 207 are accepted with a note for the user and are never sent again (the
  /// write may have happened). A 4xx the server means (the item is gone, the day is closed, no permission) is a refusal
  /// kept on the entry; 5xx and "being processed right now" stay queued and are tried again with the same key.
  Future<String?> _beyinGonder(BekleyenIslemlerData islem, Map<String, dynamic> govde) async {
    final tarih = islem.tarih;
    final yol = switch (islem.tur) {
      BekleyenTur.beyinMaddeEkle => '/api/beyin/gunler/$tarih/maddeler',
      BekleyenTur.beyinMaddeIsaretle => '/api/beyin/gunler/$tarih/isaretle',
      BekleyenTur.beyinMaddeDevret => '/api/beyin/gunler/$tarih/devret',
      BekleyenTur.beyinMaddeNot => '/api/beyin/gunler/$tarih/not',
      BekleyenTur.beyinGorevEkle => '/api/beyin/gorevler',
      BekleyenTur.beyinGorevBitir => '/api/beyin/gorevler/${Uri.encodeComponent(islem.hedefId)}/bitir',
      _ => '/api/beyin/gorevler/${Uri.encodeComponent(islem.hedefId)}/gunlere-bol',
    };
    final sonuc = await _api.beyinYaz(yol, Map<String, dynamic>.from(govde['istek'] as Map), anahtar: islem.id);
    return sonuc.uyari;
  }

  /// 409 "the capture is being sent to the brain right now": temporary, the same
  /// entry works a moment later. The other 409s (the capture already left
  /// `bekliyor`) stay permanent. The server's message carries the word "gönderiliyor"
  /// (YakalamaIslemleri.GonderiliyorMesaji); a test on both sides keeps them in step.
  static bool _gonderiliyor(DioException e) =>
      e.response?.statusCode == 409 &&
      ('${e.response?.data}'.contains('gönderiliyor') || '${e.response?.data}'.contains(_isleniyor));

  /// The title of the brain API's 409 for "the first request under this Idempotency-Key is still running"
  /// (backend/Beyin/TekrarGuvenligi.cs): the entry works a moment later. A test on the mobile side keeps the words.
  static const _isleniyor = 'İstek işleniyor';

  /// The assistant's input: uploads the photo first (once, its id goes into the queued body), then sends the input. A retry after
  /// a failed send finds the photo id in the body and does not upload again; the input id is the same, so the server answers a
  /// repeated send with the same answer.
  Future<void> _asistanGonder(BekleyenIslemlerData islem, Map<String, dynamic> govde) async {
    final girdi = Map<String, dynamic>.from(govde['girdi'] as Map);
    final yol = govde['fotografYolu'] as String?;
    if (yol != null && girdi['fotografId'] == null) {
      if (!File(yol).existsSync()) throw const _KaliciHata('Fotoğraf dosyası telefonda bulunamadı.');
      final yuklenen = await _api.dosyaYukle(yol);
      girdi['fotografId'] = yuklenen.id;
      await (_db.update(_db.bekleyenIslemler)..where((t) => t.id.equals(islem.id)))
          .write(BekleyenIslemlerCompanion(govde: Value(jsonEncode({...govde, 'girdi': girdi}))));
    }
    await _api.asistanGirdi(AsistanGirdisi.fromJson(girdi));
    yerelDosyaSil(yol); // the server has the photo now
  }

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
