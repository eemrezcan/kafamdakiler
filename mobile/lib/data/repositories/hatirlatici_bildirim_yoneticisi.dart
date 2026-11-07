import 'dart:async';

import 'package:dio/dio.dart';

import '../../utils/bildirim_plani.dart';
import '../models/hatirlatici.dart';
import '../services/bildirim_servisi.dart';
import 'brifing_repository.dart';
import 'esitleyici.dart';
import 'eylem_bildirim_yoneticisi.dart';
import 'hatirlatici_repository.dart';

/// Keeps the phone's scheduled notifications in step with the reminders: after every sync, at app start and after
/// every local write the whole plan is cancelled and set up again ([bildirimleriPlanla]). Also answers the notification
/// buttons: a button writes to the queue and asks the sender to send it.
class HatirlaticiBildirimYoneticisi {
  HatirlaticiBildirimYoneticisi({
    required this._repo,
    required this._esitleyici,
    required this._servis,
    required this._yazabilir,
    this.eylemler,
    this.brifing,
    bool Function()? brifingOkuyabilir,
    DateTime Function()? simdi,
  })  : _brifingOkuyabilir = brifingOkuyabilir ?? (() => false),
        _simdi = simdi ?? DateTime.now;

  final HatirlaticiRepository _repo;
  final Esitleyici _esitleyici;
  final BildirimServisi _servis;

  /// The approval queue's notifications share the plugin and its one response callback; its responses go here.
  final EylemBildirimYoneticisi? eylemler;

  /// The morning briefing's setting lives here; without it (or when the user may not read the briefing) no briefing
  /// notification is planned. It joins the reminders in the one plan, because setting a plan up cancels every other.
  final BrifingRepository? brifing;
  final bool Function() _brifingOkuyabilir;

  /// Whether the user may change reminders (the Sahip); the buttons are offered only then.
  final bool Function() _yazabilir;
  final DateTime Function() _simdi;
  bool _calisiyor = false;
  bool _tekrar = false;

  /// Starts the plugin, listens to local changes and answers the notification that opened the app, if any.
  /// [listeyiAc] is called when a tap (not a button) should show the reminders list, [kuyruguAc] for the approval queue,
  /// [brifingiAc] for the morning briefing.
  Future<void> baslat({required void Function() listeyiAc, void Function()? kuyruguAc, void Function()? brifingiAc}) async {
    _repo.addListener(_yerelDegisti);
    Future<void> yanitla(BildirimYaniti y) async {
      if (y.brifing) {
        brifingiAc?.call();
        return;
      }
      if (y.eylemId != null) {
        if (await (eylemler?.yanitla(y) ?? Future.value(true))) kuyruguAc?.call();
        return;
      }
      if (await this.yanitla(y)) listeyiAc();
    }

    await _servis.baslat(yanit: (y) => unawaited(yanitla(y)));
    final acilis = await _servis.acilisYaniti();
    if (acilis != null) await yanitla(acilis);
  }

  void durdur() => _repo.removeListener(_yerelDegisti);

  void _yerelDegisti() => unawaited(kur());

  /// Sets the notifications up from the phone's copy (cache plus queue). No network. A call made while one is running
  /// makes it run once more afterwards.
  Future<void> kur() async {
    if (_calisiyor) {
      _tekrar = true;
      return;
    }
    _calisiyor = true;
    try {
      do {
        _tekrar = false;
        final liste = await _repo.yerelListe();
        final plan = bildirimleriPlanla(liste, _simdi(), eylemler: _yazabilir());
        final sabah = brifing == null
            ? null
            : brifingBildirimiPlanla(await brifing!.ayar(), _simdi(), okuyabilir: _brifingOkuyabilir());
        await _servis.kur(sabah == null ? plan : (plan..add(sabah)..sort((a, b) => a.an.compareTo(b.an))));
      } while (_tekrar);
    } finally {
      _calisiyor = false;
    }
  }

  /// After a sync (and at start): refreshes the cache from the server when it can be reached, then plans again.
  Future<void> esitleVeKur() async {
    try {
      await _repo.listele();
    } on DioException {
      // Offline, or not allowed (403): the cache stays as it is.
    }
    await kur();
  }

  /// Sign-out: nothing may fire for the account that left.
  Future<void> temizle() => _servis.kur(const []);

  /// Asks for the notification permission; called when a reminder is created.
  Future<bool> izinIste() => _servis.izinIste();

  /// A button on a notification (or a tap, [BildirimYaniti.eylem] null). Returns true when a tap or a button should
  /// open the reminders list.
  Future<bool> yanitla(BildirimYaniti yanit) async {
    final id = yanit.hatirlaticiId;
    final eylem = yanit.eylem;
    if (id == null || eylem == null || !_yazabilir()) return true;
    switch (eylem) {
      case BildirimEylemi.yaptim:
        await _repo.yaptim(id);
      case BildirimEylemi.birSaatErtele:
        await _repo.ertele(id, ErteleSuresi.birSaat);
      case BildirimEylemi.yarinErtele:
        await _repo.ertele(id, ErteleSuresi.yarin);
      default:
        return true;
    }
    unawaited(_esitleyici.gonder());
    return false;
  }
}
