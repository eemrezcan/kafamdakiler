import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/zaman_cizelgesi.dart';
import '../../data/repositories/zaman_cizelgesi_repository.dart';

/// The one timeline of today on the "Bugün" tab. A failed read (not allowed, offline with nothing kept) hides the card; it
/// never blocks the tab. A later [yukle] wins over an earlier one still on the way.
class ZamanCizelgesiViewModel extends ChangeNotifier {
  ZamanCizelgesiViewModel({required this._repo});

  final ZamanCizelgesiRepository _repo;

  ZamanCizelgesi? _cizelge;

  /// Null until the first answer; the card is hidden while it is null.
  ZamanCizelgesi? get cizelge => _cizelge;

  /// The timeline on screen is the phone's last copy (no answer from the server).
  bool _cevrimdisi = false;
  bool get cevrimdisi => _cevrimdisi;

  int _tur = 0;
  bool _atildi = false;

  Future<void> yukle() async {
    final tur = ++_tur;
    try {
      final sonuc = await _repo.oku(_repo.bugun);
      if (tur != _tur || _atildi) return;
      _cizelge = sonuc.cizelge;
      _cevrimdisi = !sonuc.guncel;
    } on DioException {
      // Not allowed (403) or the server failed: keep what is shown, or stay hidden.
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _atildi = true;
    super.dispose();
  }
}
