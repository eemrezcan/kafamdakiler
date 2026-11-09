import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/push_kaynagi.dart';
import 'push_mesaj_isleyici.dart';

/// Keeps this phone's FCM token on the server while a user is signed in, and shows the messages that arrive while the
/// app is open. (Messages that arrive while it is closed go to `pushArkaPlanIsleyici`.)
///
/// The token is sent at start, after a sign-in, when the sync runs again ([kaydet] is cheap: it does nothing while the
/// token already went to the server in this run) and whenever Firebase renews it. A failed send (offline) is tried again
/// by the next call. Sign-out deletes the token from the server first, while the session still works.
class PushYoneticisi {
  PushYoneticisi({
    required this._api,
    required this._kaynak,
    required this._isleyici,
    required this._girisYapildi,
    this.cihazAdi,
    this.silmeZamanAsimi = const Duration(seconds: 5),
  });

  final ApiService _api;
  final PushKaynagi _kaynak;
  final PushMesajIsleyici _isleyici;
  final bool Function() _girisYapildi;

  /// Shown to the Sahip next to the device in the management screen.
  final String? cihazAdi;
  final Duration silmeZamanAsimi;

  String? _kayitliToken;
  StreamSubscription<String>? _yenilenme;
  StreamSubscription<Map<String, String>>? _mesajlar;

  /// Starts listening to token renewals and to messages that arrive while the app is open.
  void baslat() {
    _yenilenme ??= _kaynak.tokenYenilendi.listen((token) => unawaited(_gonder(token)));
    _mesajlar ??= _kaynak.onPlanMesajlari.listen((veri) => unawaited(_isleyici.isle(veri)));
  }

  void durdur() {
    _yenilenme?.cancel();
    _mesajlar?.cancel();
    _yenilenme = null;
    _mesajlar = null;
  }

  /// Sends the current token to the server when signed in and not yet sent in this run. Never throws.
  Future<void> kaydet() async {
    if (!_girisYapildi()) return;
    final token = await _kaynak.token();
    if (token != null) await _gonder(token);
  }

  Future<void> _gonder(String token) async {
    if (!_girisYapildi() || token == _kayitliToken) return;
    try {
      await _api.bildirimCihazKaydet(token: token, cihazAdi: cihazAdi);
      _kayitliToken = token;
    } on DioException catch (e) {
      // Offline or the server is down: the next call tries again.
      debugPrint('FCM token sunucuya yazılamadı: ${e.message}');
    }
  }

  /// Sign-out: takes this phone off the server's list, so the next user of the phone is not woken for this account.
  /// Best effort and quick: an offline phone must still be able to sign out (the server drops a dead token on its own).
  Future<void> cikisOncesiSil() async {
    final token = _kayitliToken ?? await _kaynak.token();
    _kayitliToken = null;
    if (token == null) return;
    try {
      await _api.bildirimCihazSil(token).timeout(silmeZamanAsimi);
    } on Object catch (e) {
      debugPrint('FCM token sunucudan silinemedi: $e');
    }
  }
}
