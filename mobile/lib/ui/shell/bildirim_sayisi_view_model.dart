import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/repositories/bildirim_repository.dart';
import '../../data/repositories/esitleyici.dart';

/// The number on the bell in the top bar of the tabs: notifications not read yet (`GET /api/bildirimler/sayi`).
///
/// Read when the shell opens, again when a queued write reached the server, when a read mark is made and on [yukle]. Without an answer (offline, an
/// older server) the last number stays and, before any, the bell has no badge.
class BildirimSayisiViewModel extends ChangeNotifier {
  BildirimSayisiViewModel({required this._repo, required this._esitleyici}) : _gorulenGonderim = _esitleyici.gonderimSayisi {
    _esitleyici.addListener(_kuyrukDegisti);
    _repo.addListener(yukle);
  }

  final BildirimRepository _repo;
  final Esitleyici _esitleyici;
  int _gorulenGonderim;

  int _okunmamis = 0;

  /// Zero means no badge.
  int get okunmamis => _okunmamis;

  Future<void> yukle() async {
    try {
      final sayi = await _repo.okunmamisSayi();
      if (sayi == _okunmamis) return;
      _okunmamis = sayi;
      notifyListeners();
    } on DioException {
      // Offline or not served yet: the bell keeps what it showed.
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
    _repo.removeListener(yukle);
    super.dispose();
  }
}
