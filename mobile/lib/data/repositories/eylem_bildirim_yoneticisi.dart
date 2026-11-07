import 'dart:async';

import 'package:dio/dio.dart';

import '../../utils/bildirim_plani.dart';
import '../services/bildirim_servisi.dart';
import 'esitleyici.dart';
import 'eylem_repository.dart';

/// Announces new waiting actions of the approval queue with a local notification, and answers its buttons: a button
/// writes the decision to the queue and asks the sender to send it (so it works offline too).
///
/// It does not start the plugin: the notification responses reach [HatirlaticiBildirimYoneticisi], which owns the
/// one callback and hands the approval queue ones over to [yanitla].
class EylemBildirimYoneticisi {
  EylemBildirimYoneticisi({
    required this._repo,
    required this._esitleyici,
    required this._servis,
    required this._yazabilir,
  });

  final EylemRepository _repo;
  final Esitleyici _esitleyici;
  final BildirimServisi _servis;

  /// Whether the user may decide (the Sahip); the buttons are offered only then.
  final bool Function() _yazabilir;
  bool _calisiyor = false;
  bool _tekrar = false;

  /// After a sync (and at start): refreshes the cache from the server when it can be reached, then announces what is
  /// new. Offline, or not allowed (403): the cache stays as it is.
  Future<void> esitleVeBildir() async {
    try {
      await _repo.listele();
    } on DioException {
      // The phone's copy is what we have.
    }
    await bildir();
  }

  /// Shows a notification for every waiting action that has none yet. A call made while one is running makes it run
  /// once more afterwards.
  Future<void> bildir() async {
    if (_calisiyor) {
      _tekrar = true;
      return;
    }
    _calisiyor = true;
    try {
      do {
        _tekrar = false;
        final yeniler = await _repo.bildirilmemisBekleyenler();
        if (yeniler.isEmpty) continue;
        for (final b in eylemBildirimleriPlanla(yeniler, eylemler: _yazabilir())) {
          await _servis.eylemBildir(b);
        }
        await _repo.bildirildiIsaretle(yeniler.map((e) => e.id));
      } while (_tekrar);
    } finally {
      _calisiyor = false;
    }
  }

  /// A button on an approval queue notification (or a tap, [BildirimYaniti.eylem] null). Returns true when the queue
  /// screen should open.
  Future<bool> yanitla(BildirimYaniti yanit) async {
    final id = yanit.eylemId;
    final secim = yanit.eylem;
    if (id == null || id.isEmpty || secim == null || !_yazabilir()) return true;
    switch (secim) {
      case BildirimEylemi.eylemOnayla:
        await _repo.uygula(id);
      case BildirimEylemi.eylemReddet:
        await _repo.reddet(id);
      default:
        return true;
    }
    await _servis.bildirimiKapat(eylemBildirimKimligi(id));
    unawaited(_esitleyici.gonder());
    return false;
  }
}
