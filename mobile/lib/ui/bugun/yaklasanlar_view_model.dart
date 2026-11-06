import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/hatirlatici.dart';
import '../../data/repositories/esitleyici.dart';
import '../../data/repositories/hatirlatici_repository.dart';

/// The "Yaklaşanlar" card of the Today tab: open reminders that are overdue or due within the next 7 days.
/// A failed read (not allowed, offline with nothing cached) hides the card; it never blocks the tab.
class YaklasanlarViewModel extends ChangeNotifier {
  YaklasanlarViewModel({required this._repo, required this._esitleyici, DateTime Function()? simdi})
      : _simdi = simdi ?? DateTime.now {
    _repo.addListener(_yerelYenile);
    _esitleyici.addListener(_kuyrukDegisti);
    _gorulenGonderim = _esitleyici.gonderimSayisi;
  }

  /// How many days ahead the card looks.
  static const gunSayisi = 7;

  /// How many rows the card shows; the rest is behind "Tümü".
  static const enCok = 5;

  final HatirlaticiRepository _repo;
  final Esitleyici _esitleyici;
  final DateTime Function() _simdi;
  late int _gorulenGonderim;
  bool _atildi = false;

  DateTime get simdi => _simdi();

  List<Hatirlatici>? _liste;

  /// Null until the first answer; the card is hidden while it is null.
  List<Hatirlatici>? get liste => _liste?.take(enCok).toList();

  /// How many more there are than the card shows.
  int get fazla => _liste == null || _liste!.length <= enCok ? 0 : _liste!.length - enCok;

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

  void _ayarla(List<Hatirlatici> hepsi) {
    final simdi = _simdi();
    _liste = [
      for (final h in hepsi)
        if (h.durum == HatirlaticiDurumu.acik && h.kalanGun(simdi) <= gunSayisi) h,
    ];
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
    if (_liste == null) return;
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
