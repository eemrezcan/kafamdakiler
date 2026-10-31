import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/aliskanlik.dart';
import '../../data/models/gun.dart';
import '../../data/repositories/aliskanlik_repository.dart';
import '../core/hata_metni.dart';

class AliskanlikDetayViewModel extends ChangeNotifier {
  AliskanlikDetayViewModel({required this._repo, required this.id}) {
    _repo.addListener(yukle);
  }

  final AliskanlikRepository _repo;
  final String id;

  Aliskanlik? _aliskanlik;
  Aliskanlik? get aliskanlik => _aliskanlik;

  /// The last 30 days, oldest first; null while loading or when offline.
  List<Gun>? _gunler;
  List<Gun>? get gunler => _gunler;

  bool _yukleniyor = true;
  bool get yukleniyor => _yukleniyor;

  String? _hata;
  String? get hata => _hata;

  Future<void> yukle() async {
    _hata = null;
    try {
      _aliskanlik = await _repo.aliskanlikGetir(id);
      try {
        _gunler = await _repo.sonGunler(id);
      } on DioException {
        _gunler = null; // the grid is online only; the rest still shows
      }
    } on DioException catch (e) {
      // Offline: fall back to the cached list entry.
      final onbellek = cevrimdisiHata(e) ? (await _repo.yerelListe()).where((a) => a.id == id) : <Aliskanlik>[];
      if (onbellek.isNotEmpty) {
        _aliskanlik = onbellek.first;
      } else {
        _hata = hataMetni(e, islem: 'Alışkanlık yüklenemedi');
      }
    } finally {
      _yukleniyor = false;
      notifyListeners();
    }
  }

  /// Archive / unarchive. Returns an error message, or null on success.
  Future<String?> arsivDegistir() async {
    final a = _aliskanlik!;
    try {
      await _repo.aliskanlikGuncelle(id, a.yazDto(arsivlendi: !a.arsivlendi));
      return null;
    } on DioException catch (e) {
      return hataMetni(e, islem: 'Arşivleme yapılamadı');
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> sil() async {
    try {
      await _repo.aliskanlikSil(id);
      return null;
    } on DioException catch (e) {
      return hataMetni(e, islem: 'Silinemedi');
    }
  }

  @override
  void dispose() {
    _repo.removeListener(yukle);
    super.dispose();
  }
}
