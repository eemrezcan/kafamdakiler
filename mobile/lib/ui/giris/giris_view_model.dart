import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/repositories/auth_repository.dart';

class GirisViewModel extends ChangeNotifier {
  GirisViewModel(this._auth);

  final AuthRepository _auth;

  bool _yukleniyor = false;
  bool get yukleniyor => _yukleniyor;

  String? _hata;
  String? get hata => _hata;

  /// Returns true on success; the router then leaves the login screen.
  Future<bool> girisYap(String email, String sifre) async {
    _yukleniyor = true;
    _hata = null;
    notifyListeners();
    try {
      await _auth.girisYap(email.trim(), sifre);
      return true;
    } on DioException catch (e) {
      _hata = _hataMetni(e);
      return false;
    } finally {
      _yukleniyor = false;
      notifyListeners();
    }
  }

  String _hataMetni(DioException e) {
    final kod = e.response?.statusCode;
    if (kod == 400 || kod == 401) return 'E-posta ya da şifre hatalı.';
    if (kod == 403 || kod == 423) return 'Bu hesapla giriş yapılamıyor.';
    if (kod != null) return 'Sunucu bir hata verdi ($kod). Biraz sonra tekrar dene.';
    return 'Sunucuya ulaşılamadı. İnternet bağlantını ve API adresini kontrol et.';
  }
}
