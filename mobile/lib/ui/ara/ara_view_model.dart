import 'package:flutter/foundation.dart';

import '../../data/models/beyin.dart';
import '../../data/repositories/beyin_repository.dart';
import '../core/beyin_hata.dart';
import '../core/beyin_yukleyici.dart';

/// The "Ara" tab: one search at a time over the brain's notes.
class AraViewModel extends ChangeNotifier {
  AraViewModel({required this._repo});

  /// The server refuses a longer query (400); the field stops at the same length.
  static const enUzunSorgu = 200;

  final BeyinRepository _repo;

  /// The query of the answer on screen (or on its way).
  String _sorgu = '';
  String get sorgu => _sorgu;

  List<AramaSonucu>? _sonuclar;

  /// Null until a search ran.
  List<AramaSonucu>? get sonuclar => _sonuclar;

  BeyinHatasi? _hata;
  BeyinHatasi? get hata => _hata;

  bool _yukleniyor = false;
  bool get yukleniyor => _yukleniyor;

  int _tur = 0;
  bool _atildi = false;

  /// Searches [q] (trimmed). An empty query only clears the screen.
  Future<void> ara(String q) async {
    final temiz = q.trim();
    final tur = ++_tur;
    _sorgu = temiz;
    _hata = null;
    if (temiz.isEmpty) {
      _sonuclar = null;
      _yukleniyor = false;
      notifyListeners();
      return;
    }
    _yukleniyor = true;
    notifyListeners();
    try {
      final liste = await _repo.ara(temiz);
      if (tur != _tur || _atildi) return;
      _sonuclar = liste;
    } on Object catch (e) {
      if (tur != _tur || _atildi) return;
      _sonuclar = null;
      _hata = beyinHatasi(e);
    } finally {
      if (tur == _tur && !_atildi) {
        _yukleniyor = false;
        notifyListeners();
      }
    }
  }

  /// Search again with the same query (the retry button).
  Future<void> tekrar() => ara(_sorgu);

  @override
  void dispose() {
    _atildi = true;
    super.dispose();
  }
}

/// One note, read from the brain.
class NotViewModel extends BeyinYukleyici<BeyinNotu> {
  NotViewModel({required this._repo, required this.yol});

  final BeyinRepository _repo;
  final String yol;

  @override
  Future<BeyinNotu> getir() => _repo.notuOku(yol);
}
