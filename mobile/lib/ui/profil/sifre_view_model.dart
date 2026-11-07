import 'package:flutter/foundation.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/services/api_service.dart';
import '../core/hata_metni.dart';

/// The signed-in user changes their own password. Needs the network: nothing
/// is queued, because the server must know the new password first.
class SifreViewModel extends ChangeNotifier {
  SifreViewModel({required this._api, required this._auth, required this._email});

  final ApiService _api;
  final AuthRepository _auth;

  /// The e-mail of the signed-in user, for the sign-in that follows the change.
  final String? Function() _email;

  bool _gonderiliyor = false;
  bool get gonderiliyor => _gonderiliyor;

  /// Why the last try failed (null when it worked or nothing was tried yet).
  String? _hata;
  String? get hata => _hata;

  bool _atildi = false;

  /// True when the password changed. The server renews the security stamp, which
  /// ends the refresh token this phone holds; signing in again with the new
  /// password hands out fresh tokens, so the user is not thrown out within the hour.
  Future<bool> degistir({required String mevcut, required String yeni}) async {
    if (_gonderiliyor) return false;
    _gonderiliyor = true;
    _hata = null;
    notifyListeners();
    try {
      await _api.sifreDegistir(mevcutSifre: mevcut, yeniSifre: yeni);
    } on Object catch (e) {
      _hata = sifreHataMetni(e);
      return false;
    } finally {
      _gonderiliyor = false;
      if (!_atildi) notifyListeners();
    }

    final email = _email();
    if (email != null) {
      try {
        await _auth.girisYap(email, yeni);
      } on Object {
        // The password did change. If this sign-in fails (a lost connection),
        // the user is asked to sign in once the old access token runs out.
      }
    }
    return true;
  }

  @override
  void dispose() {
    _atildi = true;
    super.dispose();
  }
}
