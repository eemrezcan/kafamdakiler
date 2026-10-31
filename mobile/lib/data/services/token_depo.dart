import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the access and refresh tokens live (K-0019: Keystore-backed storage).
abstract interface class TokenDepo {
  Future<String?> accessToken();
  Future<String?> refreshToken();
  Future<void> kaydet({required String accessToken, required String refreshToken});
  Future<void> temizle();
}

class GuvenliTokenDepo implements TokenDepo {
  GuvenliTokenDepo([FlutterSecureStorage? depo]) : _depo = depo ?? const FlutterSecureStorage();

  static const _accessAnahtari = 'accessToken';
  static const _refreshAnahtari = 'refreshToken';

  final FlutterSecureStorage _depo;

  @override
  Future<String?> accessToken() => _depo.read(key: _accessAnahtari);

  @override
  Future<String?> refreshToken() => _depo.read(key: _refreshAnahtari);

  @override
  Future<void> kaydet({required String accessToken, required String refreshToken}) async {
    await _depo.write(key: _accessAnahtari, value: accessToken);
    await _depo.write(key: _refreshAnahtari, value: refreshToken);
  }

  @override
  Future<void> temizle() async {
    await _depo.delete(key: _accessAnahtari);
    await _depo.delete(key: _refreshAnahtari);
  }
}
