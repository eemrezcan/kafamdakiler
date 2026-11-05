import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/yakalama.dart';
import '../../data/repositories/esitleyici.dart';
import '../../data/repositories/yakalama_repository.dart';
import '../core/hata_metni.dart';

/// The "Yakalamalar" tab: captures newest first, with a mark for where each one is.
class YakalamaListeViewModel extends ChangeNotifier {
  YakalamaListeViewModel({required this._repo, required this._esitleyici}) {
    _repo.addListener(_yerelYenile);
    _esitleyici.addListener(_kuyrukDegisti);
    _gorulenGonderim = _esitleyici.gonderimSayisi;
  }

  final YakalamaRepository _repo;
  final Esitleyici _esitleyici;
  late int _gorulenGonderim;
  bool _atildi = false;

  List<YakalamaSatiri>? _liste;
  List<YakalamaSatiri>? get liste => _liste;

  bool _yukleniyor = false;
  bool get yukleniyor => _yukleniyor;

  /// Why the server list could not be refreshed (the list still shows the phone's copy).
  String? _hata;
  String? get hata => _hata;

  bool _cevrimdisi = false;
  bool get cevrimdisi => _cevrimdisi;

  /// Fetches the server's list; offline, the cached list is shown.
  Future<void> yukle() async {
    if (_yukleniyor) return;
    _yukleniyor = true;
    _hata = null;
    notifyListeners();
    try {
      final sonuc = await _repo.listele();
      _liste = sonuc.liste;
      _cevrimdisi = sonuc.cevrimdisi;
    } on DioException catch (e) {
      _hata = hataMetni(e, islem: 'Liste alınamadı');
      _liste ??= await _repo.yerelListe();
    } finally {
      _yukleniyor = false;
      if (!_atildi) notifyListeners();
    }
  }

  /// A queue change on the phone: re-lay the queue, no network. A send that
  /// reached the server also refreshes the server list.
  void _kuyrukDegisti() {
    if (_esitleyici.gonderimSayisi != _gorulenGonderim) {
      _gorulenGonderim = _esitleyici.gonderimSayisi;
      unawaited(yukle());
    } else {
      unawaited(_yerelYenile());
    }
  }

  Future<void> _yerelYenile() async {
    final liste = await _repo.yerelListe();
    if (_atildi) return;
    _liste = liste;
    notifyListeners();
  }

  /// Deletes a capture that waits (on the phone or on the server).
  Future<void> sil(String id) async {
    await _repo.sil(id);
    unawaited(_esitleyici.gonder());
  }

  Future<void> simdiGonder() => _esitleyici.gonder();

  @override
  void dispose() {
    _atildi = true;
    _repo.removeListener(_yerelYenile);
    _esitleyici.removeListener(_kuyrukDegisti);
    super.dispose();
  }
}
