import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../utils/aliskanlik_gunu.dart';
import '../models/asistan.dart';
import '../models/eylem.dart';
import '../services/api_service.dart';
import '../services/database/app_database.dart';
import '../services/fotograf_deposu.dart';
import 'bekleyen_uygula.dart';
import 'esitleyici.dart';

/// The assistant's single feed (K-0024, sözleşme §7): reading it, the one input, the answer to a question, the decisions and the
/// "Geri al" of a result.
///
/// The newest page is kept on the phone, so the feed shows offline. Every write is queued on the phone first ([Esitleyici]) and
/// laid on the feed at once: an input appears as the person's own message marked "gönderilecek", an answered question and a
/// decided action leave the list, an undone result is marked. Listeners are told after every local write.
class AsistanRepository extends ChangeNotifier {
  AsistanRepository({
    required this._api,
    required this._db,
    required this._esitleyici,
    FotografDeposu? fotograflar,
    DateTime Function()? simdi,
  })  : _fotograflar = fotograflar ?? FotografDeposu(),
        _simdi = simdi ?? DateTime.now;

  static const _uuid = Uuid();

  /// The size of a page, and so how many items the newest page keeps.
  static const sayfaBoyu = 40;

  final ApiService _api;
  final AppDatabase _db;
  final Esitleyici _esitleyici;
  final FotografDeposu _fotograflar;
  final DateTime Function() _simdi;

  /// The newest page for [suzgec]; the unfiltered page is the one kept. Without an answer (offline) the kept page is filtered on
  /// the phone and `cevrimdisi` is true; with none kept the error is thrown, and so is any answer that is an error (403, 5xx).
  Future<({List<AkisOgesi> liste, bool cevrimdisi})> ilkSayfa({String suzgec = AkisSuzgeci.hepsi}) async {
    try {
      final liste = await _api.asistanAkis(limit: sayfaBoyu, suzgec: suzgec);
      if (suzgec == AkisSuzgeci.hepsi) await _sakla(liste);
      return (liste: await _bekleyenlerleBirlestir(liste, suzgec), cevrimdisi: false);
    } on DioException catch (e) {
      if (e.response != null) rethrow;
      final kayitli = await _kayitli();
      if (kayitli == null) rethrow;
      return (liste: await _bekleyenlerleBirlestir([for (final o in kayitli) if (_uygun(o, suzgec)) o], suzgec), cevrimdisi: true);
    }
  }

  /// The kept page with the queue on top, no network; null when no page was ever read.
  Future<List<AkisOgesi>?> yerel({String suzgec = AkisSuzgeci.hepsi}) async {
    final kayitli = await _kayitli();
    if (kayitli == null) return null;
    return _bekleyenlerleBirlestir([for (final o in kayitli) if (_uygun(o, suzgec)) o], suzgec);
  }

  /// The page older than [once] (the time of the oldest server item shown); server only.
  Future<List<AkisOgesi>> dahaEski(DateTime once, {String suzgec = AkisSuzgeci.hepsi}) async {
    final sayfa = await _api.asistanAkis(once: once, limit: sayfaBoyu, suzgec: suzgec);
    return _bekleyenlerleBirlestir(sayfa, suzgec, yerelEkle: false);
  }

  /// How many things wait on the person (the badge of the tab).
  Future<int> bekleyenSayisi() => _api.asistanSayi();

  static bool _uygun(AkisOgesi o, String suzgec) => switch (suzgec) {
        AkisSuzgeci.bekleyen => o.bekleyenMi,
        AkisSuzgeci.isler => o.tur == AkisTuru.isKarti,
        AkisSuzgeci.notlar => o.tur == AkisTuru.not,
        _ => true,
      };

  /// The kept page; null when no page was ever read (an empty feed that was read is an empty page, not "nothing kept").
  Future<List<AkisOgesi>?> _kayitli() async {
    final satirlar = await (_db.select(_db.asistanAkisOnbellek)..orderBy([(t) => OrderingTerm.asc(t.sira)])).get();
    if (satirlar.isEmpty) {
      final okunmus = await (_db.select(_db.ayarKayitlari)..where((t) => t.anahtar.equals(_okunduAnahtari))).getSingleOrNull();
      return okunmus == null ? null : const [];
    }
    return [for (final s in satirlar) AkisOgesi.fromJson(jsonDecode(s.govde) as Map<String, dynamic>)];
  }

  static const _okunduAnahtari = 'asistan.akis.okundu';

  Future<void> _sakla(List<AkisOgesi> liste) {
    return _db.transaction(() async {
      await _db.into(_db.ayarKayitlari).insertOnConflictUpdate(AyarKayitlariCompanion.insert(anahtar: _okunduAnahtari, deger: '1'));
      await _db.delete(_db.asistanAkisOnbellek).go();
      await _db.batch((b) {
        b.insertAll(_db.asistanAkisOnbellek, [
          for (var i = 0; i < liste.length; i++)
            AsistanAkisOnbellekCompanion.insert(id: liste[i].id, sira: i, govde: jsonEncode(liste[i].toJson())),
        ]);
      });
    });
  }

  /// Lays the queue on [liste] (newest first): the phone's own inputs and answers as messages, decided actions gone, undone
  /// results marked. [yerelEkle] false leaves the phone's own messages out (an older page has none of them).
  Future<List<AkisOgesi>> _bekleyenlerleBirlestir(List<AkisOgesi> liste, String suzgec, {bool yerelEkle = true}) async {
    final bekleyen = await _esitleyici.bekleyenler(reddedilenler: true);
    final yolda = [for (final b in bekleyen) if (b.hata == null) b];
    final geriAlinanEylemler = {for (final b in yolda) if (b.tur == BekleyenTur.eylemGeriAl) b.hedefId};
    final silinenYakalamalar = {for (final b in yolda) if (b.tur == BekleyenTur.yakalamaSil) b.hedefId};
    final cevaplar = {for (final b in yolda) if (b.tur == BekleyenTur.asistanCevap) b.hedefId: (jsonDecode(b.govde) as Map)['cevap'] as String};

    final sonuc = <AkisOgesi>[];
    for (final o in liste) {
      switch (o.tur) {
        case AkisTuru.soru when o.soru != null && cevaplar.containsKey(o.soru!.id):
          continue; // answered here; the answer shows as a message of the person
        case AkisTuru.onay when o.eylem != null:
          // A decision queued here moves the action out of "waiting": it leaves the list.
          final e = eylemlereBekleyenleriUygula([o.eylem!], yolda).single;
          if (e.durum != EylemDurumu.bekliyor) continue;
          sonuc.add(o);
        case AkisTuru.not when o.yakalama != null && silinenYakalamalar.contains(o.yakalama!.id):
          continue;
        case AkisTuru.sonuc:
          sonuc.add(o.sonuclar.any((s) => _geriAlindiMi(s, geriAlinanEylemler, silinenYakalamalar))
              ? o.kopya(sonuclar: [for (final s in o.sonuclar) _geriAlindiMi(s, geriAlinanEylemler, silinenYakalamalar) ? s.geriAlindi() : s])
              : o);
        default:
          sonuc.add(o);
      }
    }
    if (yerelEkle) {
      for (final b in bekleyen) {
        final govde = jsonDecode(b.govde) as Map<String, dynamic>;
        if (b.tur == BekleyenTur.asistanGirdi) {
          final girdi = AsistanGirdisi.fromJson(Map<String, dynamic>.from(govde['girdi'] as Map));
          sonuc.add(AkisOgesi(
            id: 'yerel:${b.id}',
            zaman: b.olusturulma.toUtc(),
            tur: AkisTuru.kullanici,
            metin: girdi.metin,
            yerelFotograf: govde['fotografYolu'] as String?,
            bekliyor: b.hata == null,
            gonderilemedi: b.hata,
          ));
        } else if (b.tur == BekleyenTur.asistanCevap && b.hata == null) {
          sonuc.add(AkisOgesi(
            id: 'yerel:${b.id}',
            zaman: b.olusturulma.toUtc(),
            tur: AkisTuru.kullanici,
            metin: govde['cevap'] as String?,
            bekliyor: true,
          ));
        }
      }
    }
    // The filters of the server do not know the phone's own messages: an unsent input waits on the server, so "Bekleyen" has it.
    final sirali = [
      for (final o in sonuc)
        if (!o.id.startsWith('yerel:') || suzgec == AkisSuzgeci.hepsi || suzgec == AkisSuzgeci.bekleyen) o,
    ]..sort((a, b) => b.zaman.compareTo(a.zaman));
    return sirali;
  }

  static bool _geriAlindiMi(AsistanSonucu s, Set<String> eylemler, Set<String> yakalamalar) =>
      (s.eylemId != null && eylemler.contains(s.eylemId)) || (s.tur == sonucTuruNot && s.hedefKimlik != null && yakalamalar.contains(s.hedefKimlik));

  // Writes. Each goes to the phone's queue and returns; the caller asks [Esitleyici.gonder] to send.

  /// The one input. [fotografKaynagi] is the picked file: a copy goes to the app's folder and is uploaded when the entry is sent.
  Future<void> girdiGonder({String? metin, String? fotografKaynagi, String kaynak = AsistanKaynagi.yazi}) async {
    final temiz = metin?.trim();
    final yol = fotografKaynagi == null ? null : await _fotograflar.kopyala(fotografKaynagi);
    await _esitleyici.asistanGirdiKuyrugaAl(
      AsistanGirdisi(
        id: _uuid.v7(),
        metin: temiz == null || temiz.isEmpty ? null : temiz,
        kaynak: kaynak,
        bugun: tarihMetni(aliskanlikGunu(_simdi())),
      ),
      fotografYolu: yol,
    );
    notifyListeners();
  }

  /// The answer to the assistant's question.
  Future<void> cevapla(String soruId, String cevap) async {
    await _esitleyici.asistanCevapKuyrugaAl(soruId, cevap.trim());
    notifyListeners();
  }

  /// "Uygula" / "Reddet" on an action waiting for approval.
  Future<void> onayla(Eylem eylem) async {
    await _esitleyici.eylemUygulaKuyrugaAl(eylem.id);
    notifyListeners();
  }

  Future<void> reddet(Eylem eylem) async {
    await _esitleyici.eylemReddetKuyrugaAl(eylem.id);
    notifyListeners();
  }

  /// "Geri al" on a result: an applied action is undone; a capture that is still waiting is deleted.
  Future<void> geriAl(AsistanSonucu sonuc) async {
    if (sonuc.tur == sonucTuruNot && sonuc.hedefKimlik != null) {
      final dosyalar = await _esitleyici.yakalamaSilKuyrugaAl(sonuc.hedefKimlik!);
      dosyalar.forEach(yerelDosyaSil);
    } else if (sonuc.eylemId != null) {
      await _esitleyici.eylemGeriAlKuyrugaAl(sonuc.eylemId!);
    }
    notifyListeners();
  }

  /// An input the server refused for good: taken off the feed.
  Future<void> girdiyiSil(String kuyrukId) async {
    final satir = (await _esitleyici.reddedilenler()).where((b) => b.id == kuyrukId).firstOrNull;
    if (satir != null) {
      final yol = (jsonDecode(satir.govde) as Map<String, dynamic>)['fotografYolu'] as String?;
      yerelDosyaSil(yol);
    }
    await _esitleyici.sil(kuyrukId);
    notifyListeners();
  }
}
