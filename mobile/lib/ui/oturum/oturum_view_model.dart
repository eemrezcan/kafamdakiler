import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/oge.dart';
import '../../data/models/oturum.dart';
import '../../data/repositories/aliskanlik_repository.dart';
import '../../data/repositories/esitleyici.dart';
import 'kronometre_view_model.dart';

/// "Nereye kadar geldin?" for one shelf item, with or without the stopwatch.
/// The session is queued on the phone first (works offline) and sent later.
class OturumViewModel extends ChangeNotifier {
  OturumViewModel({
    required this._repo,
    required this._esitleyici,
    required this.kronometre,
    required this.ogeId,
    DateTime Function()? simdi,
  }) : _simdi = simdi ?? DateTime.now;

  final AliskanlikRepository _repo;
  final Esitleyici _esitleyici;
  final DateTime Function() _simdi;
  final KronometreViewModel kronometre;
  final String ogeId;

  Oge? _oge;
  Oge? get oge => _oge;

  bool _yukleniyor = true;
  bool get yukleniyor => _yukleniyor;

  String? _hata;
  String? get hata => _hata;

  Future<void> yukle() async {
    _yukleniyor = true;
    _hata = null;
    notifyListeners();
    try {
      await kronometre.yukle();
      _oge = await _repo.oge(ogeId);
    } on Object {
      _hata = 'Öğe yüklenemedi. İnternet bağlantını kontrol edip tekrar dene.';
    } finally {
      _yukleniyor = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    kronometre.dispose();
    super.dispose();
  }

  /// Queues the session. [baslangicAni] is the stopwatch start, or now for a
  /// manual entry. The start position is the item's current position (queued
  /// sessions included), which the server verifies.
  Future<void> kaydet(double bitisKonum, {int? dakika}) async {
    final o = _oge!;
    await _esitleyici.oturumKuyrugaAl(
      ogeId,
      OturumEkle(
        bitisKonum: bitisKonum,
        dakika: dakika == null || dakika <= 0 ? null : dakika,
        baslangicKonum: o.guncelKonum,
        baslangicAni: kronometre.baslangic ?? _simdi(),
      ),
    );
    await kronometre.sifirla();
    unawaited(_esitleyici.gonder());
  }
}
