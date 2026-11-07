import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/eylem.dart';
import '../../data/repositories/esitleyici.dart';
import '../../data/repositories/eylem_repository.dart';

/// The "Onay bekleyen" card of the Today tab: how many actions wait for a decision. A failed read (not allowed,
/// offline with nothing cached) hides the card; it never blocks the tab.
class OnayBekleyenViewModel extends ChangeNotifier {
  OnayBekleyenViewModel({required this._repo, required this._esitleyici}) {
    _repo.addListener(_yerelYenile);
    _esitleyici.addListener(_kuyrukDegisti);
    _gorulenGonderim = _esitleyici.gonderimSayisi;
  }

  final EylemRepository _repo;
  final Esitleyici _esitleyici;
  late int _gorulenGonderim;
  bool _atildi = false;

  int? _sayi;

  /// Null until the first answer; the card is hidden while it is null or zero.
  int? get sayi => _sayi;

  Future<void> yukle() async {
    try {
      final sonuc = await _repo.listele();
      _ayarla(sonuc.liste);
    } on DioException {
      // Not allowed (403) or the server failed: use what the phone has, or hide the card.
      final yerel = await _repo.yerelListe();
      if (yerel.isNotEmpty) _ayarla(yerel);
    }
  }

  void _ayarla(List<Eylem> hepsi) {
    _sayi = hepsi.where((e) => e.durum == EylemDurumu.bekliyor).length;
    if (!_atildi) notifyListeners();
  }

  void _kuyrukDegisti() {
    if (_esitleyici.gonderimSayisi != _gorulenGonderim) {
      _gorulenGonderim = _esitleyici.gonderimSayisi;
      unawaited(yukle());
    } else {
      unawaited(_yerelYenile());
    }
  }

  Future<void> _yerelYenile() async {
    if (_sayi == null) return;
    _ayarla(await _repo.yerelListe());
  }

  @override
  void dispose() {
    _atildi = true;
    _repo.removeListener(_yerelYenile);
    _esitleyici.removeListener(_kuyrukDegisti);
    super.dispose();
  }
}
