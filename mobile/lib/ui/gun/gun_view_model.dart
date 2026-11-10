import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/gun_gorunum.dart';
import '../../data/repositories/esitleyici.dart';
import '../../data/repositories/gun_repository.dart';

/// One day of the day view, for Bugün and for the day list of Takvim (K-0024, sözleşme §1).
///
/// Writes go to the phone's queue first and the day is shown again from the cache with the queue on top; the sender runs in
/// the background. The first load shows a skeleton, a refresh keeps the day on screen.
class GunViewModel extends ChangeNotifier {
  GunViewModel({required this._repo, required this._esitleyici, DateTime? tarih})
      : _tarih = tarih ?? _repo.bugun,
        _gorulenGonderim = _esitleyici.gonderimSayisi {
    _repo.addListener(_yerelYenile);
    _esitleyici.addListener(_kuyrukDegisti);
  }

  final GunRepository _repo;
  final Esitleyici _esitleyici;
  int _gorulenGonderim;
  var _kapandi = false;

  DateTime _tarih;
  DateTime get tarih => _tarih;

  /// True while the view shows today (the day's own rows and the "left over" band belong to it).
  bool get bugunMu => _tarih == _repo.bugun;

  GunGorunum? _gun;
  GunGorunum? get gun => _gun;

  bool _yukleniyor = false;
  bool get yukleniyor => _yukleniyor;

  bool _cevrimdisi = false;
  bool get cevrimdisi => _cevrimdisi;

  String? _hata;
  String? get hata => _hata;

  /// Which load is the latest: an answer that arrives after the person moved to another day is dropped.
  var _istekNo = 0;

  /// Sends what is queued, then reads the day.
  Future<void> yukle() async {
    final no = ++_istekNo;
    _yukleniyor = true;
    _hata = null;
    notifyListeners();
    try {
      await _esitleyici.gonder();
      final sonuc = await _repo.oku(_tarih);
      if (no == _istekNo) {
        _gun = sonuc.gun;
        _cevrimdisi = sonuc.cevrimdisi;
      }
    } on DioException catch (e) {
      if (no == _istekNo) {
        _hata = e.response != null
            ? 'Gün alınamadı (sunucu hatası ${e.response!.statusCode}). Aşağı çekip tekrar dene.'
            : 'Gün alınamadı. İnternet bağlantını kontrol edip tekrar dene.';
      }
    } finally {
      if (no == _istekNo) _yukleniyor = false;
      if (!_kapandi) notifyListeners();
    }
  }

  /// Shows another day: the cached copy at once when there is one, then the server's.
  Future<void> tarihDegistir(DateTime tarih) async {
    if (tarih == _tarih) return;
    _tarih = tarih;
    _gun = null;
    _hata = null;
    notifyListeners();
    await _yerelYenile();
    await yukle();
  }

  Future<void> _yerelYenile() async {
    final yerel = await _repo.yerel(_tarih);
    if (_kapandi) return;
    if (yerel != null) {
      _gun = yerel;
      notifyListeners();
    }
  }

  void _kuyrukDegisti() {
    if (_esitleyici.gonderimSayisi == _gorulenGonderim) return;
    _gorulenGonderim = _esitleyici.gonderimSayisi;
    yukle();
  }

  // Writes.

  /// "Yaptım" on [oge] (or taking it back). Returns false for a row that has none (an event, a row not sent yet).
  Future<bool> yaptim(Yapilacak oge) async {
    if (!oge.yapilabilir || oge.yerel) return false;
    await _repo.yaptim(_tarih, oge);
    unawaited(_esitleyici.gonder());
    return true;
  }

  /// A new row on [tarih] (the shown day when none is given).
  Future<void> ogeEkle(YeniOgeYaz yaz, {DateTime? tarih}) async {
    await _repo.ogeEkle(tarih ?? _tarih, yaz);
    unawaited(_esitleyici.gonder());
  }

  Future<void> hatirlaticiYaz(Yapilacak oge, HatirlaticiGovde govde) async {
    await _repo.hatirlaticiYaz(_tarih, oge, govde);
    unawaited(_esitleyici.gonder());
  }

  Future<void> hatirlaticiSil(Yapilacak oge) async {
    await _repo.hatirlaticiSil(_tarih, oge);
    unawaited(_esitleyici.gonder());
  }

  Future<void> yarinaDevret(Iterable<Yapilacak> ogeler) async {
    await _repo.yarinaDevret(_tarih, ogeler);
    unawaited(_esitleyici.gonder());
  }

  Future<void> bugunAl(DundenKalan d) async {
    await _repo.bugunAl(_tarih, d);
    unawaited(_esitleyici.gonder());
  }

  Future<void> dundenBirak(DundenKalan d) async {
    await _repo.dundenBirak(_tarih, d);
    unawaited(_esitleyici.gonder());
  }

  Future<void> notEkle(Yapilacak oge, String metin) async {
    await _repo.notEkle(_tarih, oge, metin);
    unawaited(_esitleyici.gonder());
  }

  Future<void> gunlereBol(Yapilacak oge, int gunSayisi) async {
    await _repo.gunlereBol(_tarih, oge, gunSayisi);
    unawaited(_esitleyici.gonder());
  }

  @override
  void dispose() {
    _kapandi = true;
    _repo.removeListener(_yerelYenile);
    _esitleyici.removeListener(_kuyrukDegisti);
    super.dispose();
  }
}
