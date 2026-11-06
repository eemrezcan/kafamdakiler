import 'package:flutter/foundation.dart';

import '../models/yakala_girdisi.dart';

/// Holds the one incoming share (or shortcut request) that waits for the app to
/// be ready. A newer one replaces the older.
class BekleyenYakala extends ChangeNotifier {
  YakalaGirdisi? _bekleyen;
  YakalaGirdisi? get bekleyen => _bekleyen;

  void bekle(YakalaGirdisi girdi) {
    _bekleyen = girdi;
    notifyListeners();
  }

  /// Takes the waiting item (it is gone afterwards).
  YakalaGirdisi? tuket() {
    final girdi = _bekleyen;
    _bekleyen = null;
    return girdi;
  }
}

/// Opens Yakala with the waiting item once that is possible:
/// - signed out, or the role not known yet, or the router still on the login screen: keep waiting;
/// - Sahip: open Yakala with it (an empty request is ignored when Yakala is already on top);
/// - Asistan (may not capture): drop it and say so.
class YakalaYonlendirici {
  YakalaYonlendirici({
    required this.bekleyen,
    required this._degisim,
    required this.girisYapildi,
    required this.rolBilinir,
    required this.sahip,
    required this.hazir,
    required this.yakalaAcik,
    required this.ac,
    required this.mesaj,
  }) {
    _degisim.addListener(degerlendir);
  }

  final BekleyenYakala bekleyen;
  final Listenable _degisim;
  final bool Function() girisYapildi;
  final bool Function() rolBilinir;
  final bool Function() sahip;

  /// False while the router is still on the login screen.
  final bool Function() hazir;
  /// True when Yakala is already the screen on top.
  final bool Function() yakalaAcik;
  final void Function(YakalaGirdisi girdi) ac;
  final void Function(String mesaj) mesaj;

  void degerlendir() {
    if (bekleyen.bekleyen == null) return;
    if (!girisYapildi() || !rolBilinir() || !hazir()) return;
    final girdi = bekleyen.tuket()!;
    if (sahip()) {
      // A plain "open Yakala" request while Yakala is showing changes nothing; shared content still opens a new one.
      if (girdi.bos && yakalaAcik()) return;
      ac(girdi);
    } else {
      mesaj('Yakalama yalnız Sahip hesabıyla yapılır; paylaşılan içerik alınmadı.');
    }
  }

  void durdur() => _degisim.removeListener(degerlendir);
}
