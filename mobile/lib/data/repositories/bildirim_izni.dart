import 'package:flutter/foundation.dart';

import '../services/bildirim_servisi.dart';

/// Whether the phone may show notifications, for the "Bildirimler kapalı" warning on Bugün. The first real run showed why: the
/// permission stayed off without a word and no notification ever appeared.
enum BildirimIzniDurumu { bilinmiyor, acik, kapali }

class BildirimIzni extends ChangeNotifier {
  BildirimIzni({required this._servis});

  final BildirimServisi _servis;
  BildirimIzniDurumu _durum = BildirimIzniDurumu.bilinmiyor;
  bool _soruldu = false;
  bool _calisiyor = false;

  BildirimIzniDurumu get durum => _durum;

  /// True only when the permission is known to be off (not while it is still unknown).
  bool get kapali => _durum == BildirimIzniDurumu.kapali;

  /// Looks at the permission; when it is off, asks for it, once for each run of the app (a second question in the same run would
  /// only annoy: Android does not show its dialog again after a "no" anyway). Called after sign-in and every time the app comes back
  /// to the foreground, so turning it on in the settings clears the warning. Never throws.
  Future<void> denetle() async {
    if (_calisiyor) return;
    _calisiyor = true;
    try {
      var acik = await _servis.izinVarMi();
      if (!acik && !_soruldu) {
        _soruldu = true;
        acik = await _servis.izinIste();
      }
      _guncelle(acik ? BildirimIzniDurumu.acik : BildirimIzniDurumu.kapali);
    } finally {
      _calisiyor = false;
    }
  }

  Future<void> ayarlariAc() => _servis.ayarlariAc();

  /// Sign-out: the next person is asked again, and nothing is claimed about the permission until then.
  void sifirla() {
    _soruldu = false;
    _guncelle(BildirimIzniDurumu.bilinmiyor);
  }

  void _guncelle(BildirimIzniDurumu yeni) {
    if (yeni == _durum) return;
    _durum = yeni;
    notifyListeners();
  }
}
