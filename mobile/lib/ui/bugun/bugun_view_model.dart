import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/aliskanlik.dart';
import '../../data/models/gun.dart';
import '../../data/repositories/aliskanlik_repository.dart';
import '../../data/repositories/esitleyici.dart';

/// The "Today" tab: habits planned for today, and the quick writes.
///
/// Writes are optimistic: they go to the phone queue first, the list is
/// rebuilt from cache + queue at once, and the sender runs in the background.
class BugunViewModel extends ChangeNotifier {
  BugunViewModel({required this._repo, required this._esitleyici})
      : _gorulenGonderim = _esitleyici.gonderimSayisi {
    _repo.addListener(_dishaDegisti);
    _esitleyici.addListener(_kuyrukDegisti);
  }

  final AliskanlikRepository _repo;
  final Esitleyici _esitleyici;
  int _gorulenGonderim;

  List<Aliskanlik>? _liste;
  List<Aliskanlik>? get liste => _liste;

  /// Habits planned for today, in the server's order.
  List<Aliskanlik> get planli => [for (final a in _liste ?? const <Aliskanlik>[]) if (a.bugunPlanli) a];

  /// Habits not planned today; shown faded at the bottom.
  List<Aliskanlik> get plansiz => [for (final a in _liste ?? const <Aliskanlik>[]) if (!a.bugunPlanli) a];

  bool _yukleniyor = false;
  bool get yukleniyor => _yukleniyor;

  bool _cevrimdisi = false;
  bool get cevrimdisi => _cevrimdisi;

  String? _hata;
  String? get hata => _hata;

  /// Sends what is queued, then reloads. The first load shows a skeleton; a
  /// refresh keeps the list on screen.
  Future<void> yukle() async {
    if (_yukleniyor) return;
    _yukleniyor = true;
    _hata = null;
    notifyListeners();
    try {
      await _esitleyici.gonder();
      final sonuc = await _repo.listele();
      _liste = sonuc.liste;
      _cevrimdisi = sonuc.cevrimdisi;
    } on DioException catch (e) {
      _hata = e.response != null
          ? 'Alışkanlıklar alınamadı (sunucu hatası ${e.response!.statusCode}). Aşağı çekip tekrar dene.'
          : 'Alışkanlıklar alınamadı. İnternet bağlantını kontrol edip tekrar dene.';
    } finally {
      _yukleniyor = false;
      notifyListeners();
    }
  }

  /// Toggles a yes/no habit. Returns the previous amount (for "Geri al").
  Future<double> tikDegistir(Aliskanlik a) async {
    final onceki = a.bugun?.miktar ?? 0;
    await miktarYaz(a, onceki >= 1 ? 0 : 1);
    return onceki;
  }

  /// Writes the day's total for a Sayac habit (never below zero).
  Future<void> miktarYaz(Aliskanlik a, double miktar, {int? dakika}) async {
    final tarih = _repo.bugun;
    final yeni = miktar < 0 ? 0.0 : miktar;
    if (yeni == 0 && (dakika == null || dakika == 0)) {
      await _esitleyici.gunSilKuyrugaAl(a.id, tarih);
    } else {
      await _esitleyici.gunYazKuyrugaAl(a.id, tarih, GunYaz(miktar: yeni, dakika: dakika));
    }
    await _yerelYenile();
    unawaited(_esitleyici.gonder());
  }

  /// Adds minutes from the stopwatch to the day of a minute-based counter.
  Future<void> dakikaEkle(Aliskanlik a, int dakika) => miktarYaz(a, (a.bugun?.miktar ?? 0) + dakika);

  Future<void> _yerelYenile() async {
    _liste = await _repo.yerelListe();
    notifyListeners();
  }

  void _dishaDegisti() => yukle();

  void _kuyrukDegisti() {
    if (_esitleyici.gonderimSayisi == _gorulenGonderim) return;
    _gorulenGonderim = _esitleyici.gonderimSayisi;
    yukle();
  }

  @override
  void dispose() {
    _repo.removeListener(_dishaDegisti);
    _esitleyici.removeListener(_kuyrukDegisti);
    super.dispose();
  }
}
