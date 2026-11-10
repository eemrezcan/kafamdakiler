import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/aliskanlik.dart';
import '../../data/models/enums.dart';
import '../../data/models/oge.dart';
import '../../data/models/oturum.dart';
import '../../data/repositories/aliskanlik_repository.dart';
import '../../data/repositories/esitleyici.dart';
import '../../utils/dogrulama.dart';

/// How a save went: the session is always kept on the phone; "Kitabı bitirdim" needs the server.
enum OkumaKaydiSonucu {
  kaydedildi,

  /// The session is queued, but the item could not be marked finished (no connection, or the server refused).
  bitirilemedi,
}

/// The reading entry sheet (K-0024): which book, how far, how long, "Kitabı bitirdim". The session is queued on the phone first
/// (works offline) and sent in the background, like the one of the stopwatch page.
class OkumaKaydiViewModel extends ChangeNotifier {
  OkumaKaydiViewModel({
    required this._repo,
    required this._esitleyici,
    required this.aliskanlik,
    String? ogeId,
    DateTime Function()? simdi,
  }) : _simdi = simdi ?? DateTime.now {
    final kitaplar = aliskanlik.devamEdenler;
    _secili = kitaplar.where((o) => o.id == ogeId).firstOrNull ?? kitaplar.firstOrNull;
    _konum = _baslangicKonumu(_secili);
  }

  /// How many pages the sheet adds to the position when there is no daily goal.
  static const varsayilanAdim = 10;

  /// The sheet opens with the field filled in: the position plus what is left of today's goal (plus [varsayilanAdim] when
  /// there is no goal), so one tap on "Kaydet" records the day's reading. The total of the item is the ceiling.
  double _baslangicKonumu(OgeOzet? o) {
    if (o == null) return 0;
    final hedef = aliskanlik.gunlukHedef;
    final ekle = hedef == null ? varsayilanAdim.toDouble() : math.max(0.0, hedef - (aliskanlik.bugun?.miktar ?? 0));
    final konum = o.guncelKonum + ekle;
    final tavan = o.toplam;
    return tavan != null && konum > tavan ? math.max(tavan, o.guncelKonum) : konum;
  }

  final AliskanlikRepository _repo;
  final Esitleyici _esitleyici;
  final DateTime Function() _simdi;
  final Aliskanlik aliskanlik;

  /// The minutes the quick chips offer.
  static const sureSecenekleri = [10, 20, 30, 45];

  List<OgeOzet> get kitaplar => aliskanlik.devamEdenler;

  OgeOzet? _secili;
  OgeOzet? get secili => _secili;

  late double _konum;

  /// "How far did you get": the position after the session.
  double get konum => _konum;

  int? _dakika;
  int? get dakika => _dakika;

  bool _bitti = false;
  bool get bitti => _bitti;

  bool _kaydediliyor = false;
  bool get kaydediliyor => _kaydediliyor;

  /// Pages (or minutes...) read in this session.
  double get fark => _secili == null ? 0 : _konum - _secili!.guncelKonum;

  /// What the habit counted today, with this session on top.
  double get bugunToplam => (aliskanlik.bugun?.miktar ?? 0) + (fark > 0 ? fark : 0);

  /// How much of the day's goal is left after this session; null when the habit has no goal, 0 when it is reached.
  double? get hedefKalan {
    final hedef = aliskanlik.gunlukHedef;
    if (hedef == null) return null;
    final kalan = hedef - bugunToplam;
    return kalan > 0 ? kalan : 0;
  }

  /// Why the entry cannot be saved yet, or null.
  String? get hata {
    final o = _secili;
    if (o == null) return 'Önce bir ${(aliskanlik.ogeEtiketi ?? 'öğe').toLowerCase()} seç.';
    return konumDogrula(sayiMetni(_konum), baslangic: o.guncelKonum, toplam: o.toplam);
  }

  /// Saving is offered as soon as there is something to save; a wrong position is told when "Kaydet" is pressed.
  bool get kaydedilebilir => _secili != null && !_kaydediliyor;

  bool _hataGoster = false;

  /// [hata] once the person has changed the field or pressed "Kaydet"; null before that, so the sheet opens without a complaint.
  String? get gorunenHata => _hataGoster ? hata : null;

  /// "Kaydet" with a wrong position: show why instead of saving. True when the entry is fine.
  bool kaydetmeyeHazir() {
    if (hata == null) return true;
    _hataGoster = true;
    notifyListeners();
    return false;
  }

  void sec(String ogeId) {
    final o = kitaplar.where((k) => k.id == ogeId).firstOrNull;
    if (o == null || o.id == _secili?.id) return;
    _secili = o;
    _konum = _baslangicKonumu(o);
    _hataGoster = false;
    _bitti = false;
    notifyListeners();
  }

  void konumYaz(double yeni) {
    _konum = yeni < 0 ? 0 : yeni;
    _hataGoster = true;
    notifyListeners();
  }

  void konumArttir(double adim) => konumYaz(_konum + adim);

  /// [dakika] null clears the choice.
  void sureYaz(int? dakika) {
    _dakika = dakika;
    notifyListeners();
  }

  void bittiYaz(bool deger) {
    _bitti = deger;
    notifyListeners();
  }

  Future<OkumaKaydiSonucu> kaydet() async {
    final o = _secili!;
    _kaydediliyor = true;
    notifyListeners();
    await _esitleyici.oturumKuyrugaAl(
      o.id,
      OturumEkle(
        bitisKonum: _konum,
        dakika: _dakika == null || _dakika! <= 0 ? null : _dakika,
        baslangicKonum: o.guncelKonum,
        baslangicAni: _simdi(),
      ),
    );
    var sonuc = OkumaKaydiSonucu.kaydedildi;
    if (_bitti) {
      // The finished mark is a write on the item itself: the session must reach the server first.
      await _esitleyici.gonder();
      try {
        final oge = await _repo.oge(o.id);
        await _repo.ogeGuncelle(
          o.id,
          OgeYaz(
            id: oge.id,
            ad: oge.ad,
            altBaslik: oge.altBaslik,
            toplam: oge.toplam,
            baslangicKonumu: oge.baslangicKonumu,
            fotografId: oge.fotografId,
            durum: OgeDurumu.bitti,
            puan: oge.puan,
            not: oge.not,
          ),
        );
      } on DioException {
        sonuc = OkumaKaydiSonucu.bitirilemedi;
      }
    } else {
      unawaited(_esitleyici.gonder());
    }
    _kaydediliyor = false;
    notifyListeners();
    return sonuc;
  }
}
