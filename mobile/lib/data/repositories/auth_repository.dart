import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/giris.dart';
import '../services/api_service.dart';
import '../services/token_depo.dart';

/// The session: whether tokens exist. The router listens to this
/// (`refreshListenable`) and sends signed-out users to the login screen.
class AuthRepository extends ChangeNotifier {
  AuthRepository({required this._api, required this._depo, this.cikistaTemizle});

  final ApiService _api;
  final TokenDepo _depo;

  /// Wiped on an explicit sign-out (cache, queue, role); not when the session
  /// merely expired, so unsent entries survive a re-login.
  final Future<void> Function()? cikistaTemizle;

  bool _girisYapildi = false;
  bool get girisYapildi => _girisYapildi;

  /// Reads the stored tokens. No network call: the app must open offline.
  Future<void> baslat() async {
    _girisYapildi = await _depo.refreshToken() != null;
    notifyListeners();
  }

  /// Throws [DioException] on failure (400/401 = wrong credentials).
  Future<void> girisYap(String email, String sifre) async {
    final tokenlar = await _api.girisYap(GirisIstegi(email: email, password: sifre));
    await _depo.kaydet(accessToken: tokenlar.accessToken, refreshToken: tokenlar.refreshToken);
    _girisYapildi = true;
    notifyListeners();
  }

  Future<void> cikis() async {
    await _depo.temizle();
    await cikistaTemizle?.call();
    _girisYapildi = false;
    notifyListeners();
  }

  /// Called by the token interceptor when the refresh token was refused.
  void oturumKapandi() {
    if (!_girisYapildi) return;
    _girisYapildi = false;
    notifyListeners();
  }
}
