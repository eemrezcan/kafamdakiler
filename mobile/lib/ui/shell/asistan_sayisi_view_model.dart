import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/repositories/asistan_repository.dart';
import '../../data/repositories/esitleyici.dart';

/// The badge on the Asistan tab: how many things wait on the person (`GET /api/asistan/sayi`). Read when the shell opens and
/// again when a queued write reached the server; without an answer the last number stays.
class AsistanSayisiViewModel extends ChangeNotifier {
  AsistanSayisiViewModel({required this._repo, required this._esitleyici}) : _gorulenGonderim = _esitleyici.gonderimSayisi {
    _esitleyici.addListener(_kuyrukDegisti);
  }

  final AsistanRepository _repo;
  final Esitleyici _esitleyici;
  int _gorulenGonderim;

  int _bekleyen = 0;

  /// Zero means no badge.
  int get bekleyen => _bekleyen;

  Future<void> yukle() async {
    try {
      final sayi = await _repo.bekleyenSayisi();
      if (sayi == _bekleyen) return;
      _bekleyen = sayi;
      notifyListeners();
    } on DioException {
      // Offline or not served yet: the badge keeps what it showed.
    }
  }

  void _kuyrukDegisti() {
    if (_esitleyici.gonderimSayisi == _gorulenGonderim) return;
    _gorulenGonderim = _esitleyici.gonderimSayisi;
    yukle();
  }

  @override
  void dispose() {
    _esitleyici.removeListener(_kuyrukDegisti);
    super.dispose();
  }
}
