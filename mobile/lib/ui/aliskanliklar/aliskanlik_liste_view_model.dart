import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/aliskanlik.dart';
import '../../data/models/gun.dart';
import '../../data/repositories/aliskanlik_repository.dart';
import '../../data/repositories/esitleyici.dart';

/// The "Alışkanlıklar" tab: all habits (or the archived ones), each with its quick write: tick, +/-, the reading entry.
///
/// Writes are optimistic, like on the strip of Bugün: they go to the phone queue first, the list is rebuilt from the cache with
/// the queue on top, and the sender runs in the background.
class AliskanlikListeViewModel extends ChangeNotifier {
  AliskanlikListeViewModel({required this._repo, required this._esitleyici}) {
    _repo.addListener(yukle);
  }

  final AliskanlikRepository _repo;
  final Esitleyici _esitleyici;

  List<Aliskanlik>? _liste;
  List<Aliskanlik>? get liste => _liste;

  bool _arsiv = false;
  bool get arsiv => _arsiv;

  bool _yukleniyor = false;
  bool get yukleniyor => _yukleniyor;

  String? _hata;
  String? get hata => _hata;

  Future<void> arsivGoster(bool deger) {
    _arsiv = deger;
    _liste = null;
    return yukle();
  }

  Future<void> yukle() async {
    if (_yukleniyor) return;
    _yukleniyor = true;
    _hata = null;
    notifyListeners();
    try {
      _liste = (await _repo.listele(arsiv: _arsiv)).liste;
    } on DioException catch (e) {
      _hata = e.response != null
          ? 'Liste alınamadı (sunucu hatası ${e.response!.statusCode}). Aşağı çekip tekrar dene.'
          : 'Liste alınamadı. İnternet bağlantını kontrol edip tekrar dene.';
    } finally {
      _yukleniyor = false;
      notifyListeners();
    }
  }

  /// Habits planned today whose value reached 1 (the "1 / 5 bugün" under the title); the archive has none.
  ({int tamam, int planli}) get bugunOzeti {
    final planli = [for (final a in _liste ?? const <Aliskanlik>[]) if (a.bugunPlanli && !a.arsivlendi) a];
    return (tamam: planli.where((a) => (a.bugun?.deger ?? 0) >= 1).length, planli: planli.length);
  }

  /// Toggles a yes/no habit. Returns the previous amount (for "Geri al").
  Future<double> tikDegistir(Aliskanlik a) async {
    final onceki = a.bugun?.miktar ?? 0;
    await miktarYaz(a, onceki >= 1 ? 0 : 1);
    return onceki;
  }

  /// Writes the day's total for a counter (never below zero).
  Future<void> miktarYaz(Aliskanlik a, double miktar, {int? dakika}) async {
    final tarih = _repo.bugun;
    final yeni = miktar < 0 ? 0.0 : miktar;
    if (yeni == 0 && (dakika == null || dakika == 0)) {
      await _esitleyici.gunSilKuyrugaAl(a.id, tarih);
    } else {
      await _esitleyici.gunYazKuyrugaAl(a.id, tarih, GunYaz(miktar: yeni, dakika: dakika));
    }
    if (!_arsiv) {
      _liste = await _repo.yerelListe();
      notifyListeners();
    }
    unawaited(_esitleyici.gonder());
  }

  @override
  void dispose() {
    _repo.removeListener(yukle);
    super.dispose();
  }
}
