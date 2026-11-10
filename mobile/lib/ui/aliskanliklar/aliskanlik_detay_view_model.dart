import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/aliskanlik.dart';
import '../../data/models/enums.dart';
import '../../data/models/gun.dart';
import '../../data/models/oturum.dart';
import '../../data/repositories/aliskanlik_repository.dart';
import '../core/hata_metni.dart';

/// One session of a shelf habit with the name of its item, for "Son oturumlar".
class OturumSatiri {
  const OturumSatiri({required this.ogeAd, required this.oturum});

  final String ogeAd;
  final Oturum oturum;
}

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

  /// The latest sessions of the items in progress of a shelf habit, newest first; empty for a counter, offline or when none.
  List<OturumSatiri> _oturumlar = const [];
  List<OturumSatiri> get oturumlar => _oturumlar;

  static const _enCokOturum = 5;
  static const _enCokKitap = 3;

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
      _oturumlar = await _oturumlariGetir(_aliskanlik!);
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

  /// The sessions are online only, like the grid: a failing read leaves the list empty and the rest of the screen as it is.
  Future<List<OturumSatiri>> _oturumlariGetir(Aliskanlik a) async {
    if (a.tur != AliskanlikTuru.raf) return const [];
    final satirlar = <OturumSatiri>[];
    for (final o in a.devamEdenler.take(_enCokKitap)) {
      try {
        satirlar.addAll([for (final t in await _repo.oturumlar(o.id)) OturumSatiri(ogeAd: o.ad, oturum: t)]);
      } on DioException {
        return const [];
      }
    }
    satirlar.sort((x, y) => y.oturum.olusturulma.compareTo(x.oturum.olusturulma));
    return satirlar.take(_enCokOturum).toList();
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
