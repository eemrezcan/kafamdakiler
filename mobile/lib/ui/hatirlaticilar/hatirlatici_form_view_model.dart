import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/hatirlatici.dart';
import '../../data/repositories/esitleyici.dart';
import '../../data/repositories/hatirlatici_bildirim_yoneticisi.dart';
import '../../data/repositories/hatirlatici_repository.dart';

/// The reminder form: a new reminder, or (with [duzenlenenId]) an edit. Saving never needs the network: it writes to
/// the phone's queue and only then asks the sender to try. An edit reads the phone's copy.
class HatirlaticiFormViewModel extends ChangeNotifier {
  HatirlaticiFormViewModel({
    required this._repo,
    required this._esitleyici,
    this._bildirim,
    this.duzenlenenId,
  });

  final HatirlaticiRepository _repo;
  final Esitleyici _esitleyici;

  /// Asked for the notification permission when the first reminder is created.
  final HatirlaticiBildirimYoneticisi? _bildirim;

  /// Reminder being edited (null for a new one).
  final String? duzenlenenId;
  bool get duzenleme => duzenlenenId != null;

  Hatirlatici? _mevcut;
  Hatirlatici? get mevcut => _mevcut;

  bool _yukleniyor = false;
  bool get yukleniyor => _yukleniyor;

  bool _kaydediliyor = false;
  bool get kaydediliyor => _kaydediliyor;

  String? _hata;
  String? get hata => _hata;

  /// Edit mode: finds the reminder on the phone.
  Future<void> yukle() async {
    _yukleniyor = true;
    notifyListeners();
    try {
      _mevcut = await _repo.getir(duzenlenenId!);
      if (_mevcut == null) _hata = 'Kayıt bulunamadı; silinmiş olabilir.';
    } finally {
      _yukleniyor = false;
      notifyListeners();
    }
  }

  /// Saves on the phone. Returns true when saved; otherwise [hata] says why.
  Future<bool> kaydet(HatirlaticiYaz yaz) async {
    _kaydediliyor = true;
    _hata = null;
    notifyListeners();
    try {
      if (duzenleme) {
        await _repo.guncelle(duzenlenenId!, yaz);
      } else {
        await _repo.ekle(yaz);
        // The permission is asked when the first reminder is made, not at app start; the reminder is saved either way.
        unawaited(_bildirim?.izinIste());
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

  /// Deletes the reminder (edit mode).
  Future<bool> sil() async {
    try {
      await _repo.sil(duzenlenenId!);
      unawaited(_esitleyici.gonder());
      return true;
    } on Object {
      _hata = 'Silinemedi. Tekrar dene.';
      notifyListeners();
      return false;
    }
  }
}
