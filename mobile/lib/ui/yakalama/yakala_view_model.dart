import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/yakalama.dart';
import '../../data/repositories/esitleyici.dart';
import '../../data/repositories/yakalama_repository.dart';

/// The capture form: a new capture, or (with [duzenlenenId]) an edit of one
/// that still waits. Saving never needs the network: it writes to the phone's
/// queue and only then asks the sender to try. Opening the screen makes no API
/// call either; an edit reads the local copy of the capture.
class YakalaViewModel extends ChangeNotifier {
  YakalaViewModel({required this._repo, required this._esitleyici, this.duzenlenenId});

  final YakalamaRepository _repo;
  final Esitleyici _esitleyici;

  /// Capture being edited (null for a new one).
  final String? duzenlenenId;
  bool get duzenleme => duzenlenenId != null;

  YakalamaSatiri? _mevcut;
  YakalamaSatiri? get mevcut => _mevcut;

  bool _yukleniyor = false;
  bool get yukleniyor => _yukleniyor;

  bool _kaydediliyor = false;
  bool get kaydediliyor => _kaydediliyor;

  String? _hata;
  String? get hata => _hata;

  /// Edit mode: finds the capture on the phone.
  Future<void> yukle() async {
    _yukleniyor = true;
    notifyListeners();
    try {
      _mevcut = await _repo.getir(duzenlenenId!);
      if (_mevcut == null) {
        _hata = 'Kayıt bulunamadı; silinmiş olabilir.';
      } else if (!_mevcut!.degistirilebilir) {
        _hata = 'Bu yakalama beyne gitti, artık değiştirilemez.';
        _mevcut = null;
      }
    } finally {
      _yukleniyor = false;
      notifyListeners();
    }
  }

  /// Saves on the phone. Returns true when saved; otherwise [hata] says why.
  ///
  /// [fotografKaynagi] is a newly picked photo; [fotografKaldir] drops the
  /// photo the edited capture had.
  Future<bool> kaydet({String? metin, String? fotografKaynagi, bool fotografKaldir = false}) async {
    final fotografVar = fotografKaynagi != null ||
        (!fotografKaldir && (_mevcut?.fotografId != null || _mevcut?.fotografYolu != null));
    if ((metin ?? '').trim().isEmpty && !fotografVar) {
      _hata = 'Metin yaz ya da fotoğraf ekle.';
      notifyListeners();
      return false;
    }
    _kaydediliyor = true;
    _hata = null;
    notifyListeners();
    try {
      if (duzenleme) {
        await _repo.guncelle(_mevcut!, metin: metin, yeniFotografKaynagi: fotografKaynagi, fotografKaldir: fotografKaldir);
      } else {
        await _repo.yakala(metin: metin, fotografKaynagi: fotografKaynagi);
      }
      unawaited(_esitleyici.gonder());
      return true;
    } on Object {
      _hata = 'Telefona kaydedilemedi. Depolama alanını kontrol edip tekrar dene.';
      return false;
    } finally {
      _kaydediliyor = false;
      notifyListeners();
    }
  }

  void hatayiTemizle() {
    if (_hata == null) return;
    _hata = null;
    notifyListeners();
  }
}
