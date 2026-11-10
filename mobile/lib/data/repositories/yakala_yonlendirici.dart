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

/// Opens the Asistan tab with the waiting item (the input starts with it) once that is possible:
/// - signed out, or the role not known yet, or the router still on the login screen: keep waiting;
/// - someone who may use the assistant: open it with the item (an empty request just puts the cursor in the input, even when the
///   tab is open already);
/// - someone who may not: drop it and say so.
class YakalaYonlendirici {
  YakalaYonlendirici({
    required this.bekleyen,
    required this._degisim,
    required this.girisYapildi,
    required this.rolBilinir,
    required this.kullanabilir,
    required this.hazir,
    required this.ac,
    required this.mesaj,
  }) {
    _degisim.addListener(degerlendir);
  }

  final BekleyenYakala bekleyen;
  final Listenable _degisim;
  final bool Function() girisYapildi;
  final bool Function() rolBilinir;
  final bool Function() kullanabilir;

  /// False while the router is still on the login screen.
  final bool Function() hazir;
  final void Function(YakalaGirdisi girdi) ac;
  final void Function(String mesaj) mesaj;

  void degerlendir() {
    if (bekleyen.bekleyen == null) return;
    if (!girisYapildi() || !rolBilinir() || !hazir()) return;
    final girdi = bekleyen.tuket()!;
    if (kullanabilir()) {
      ac(girdi);
    } else {
      mesaj('Asistanı kullanma iznin yok; paylaşılan içerik alınmadı.');
    }
  }

  void durdur() => _degisim.removeListener(degerlendir);
}
