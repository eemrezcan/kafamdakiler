import 'package:flutter/foundation.dart';

import 'beyin_hata.dart';

/// A view model that reads one thing from the brain: [yukle] fetches it, and the
/// screen shows [veri], the loading skeleton or the failure ([hata]).
///
/// A later call wins: if [yukle] is called again (the user moved to another day,
/// pulled to refresh) while the first one is still on the way, the first answer is
/// dropped when it arrives.
abstract class BeyinYukleyici<T> extends ChangeNotifier {
  /// The read itself; throws what the repository throws.
  Future<T> getir();

  T? _veri;
  T? get veri => _veri;

  BeyinHatasi? _hata;
  BeyinHatasi? get hata => _hata;

  bool _yukleniyor = false;
  bool get yukleniyor => _yukleniyor;

  int _tur = 0;
  bool _atildi = false;

  Future<void> yukle() async {
    final tur = ++_tur;
    _yukleniyor = true;
    _hata = null;
    notifyListeners();
    try {
      final sonuc = await getir();
      if (tur != _tur || _atildi) return;
      _veri = sonuc;
    } on Object catch (e) {
      if (tur != _tur || _atildi) return;
      _veri = null;
      _hata = beyinHatasi(e);
    } finally {
      if (tur == _tur && !_atildi) {
        _yukleniyor = false;
        notifyListeners();
      }
    }
  }

  /// Forgets the shown data (before loading something else, so an old answer is not shown for the new request).
  void temizle() {
    _veri = null;
    _hata = null;
  }

  @override
  void dispose() {
    _atildi = true;
    super.dispose();
  }
}
