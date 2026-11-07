import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the phone has a connection right now, and when that changes. Behind an interface so tests can switch it.
abstract class BaglantiServisi {
  Future<bool> varMi();

  Stream<bool> get degisim;
}

class ConnectivityBaglantiServisi implements BaglantiServisi {
  final _baglanti = Connectivity();

  static bool _var(List<ConnectivityResult> sonuclar) => sonuclar.any((s) => s != ConnectivityResult.none);

  @override
  Future<bool> varMi() async => _var(await _baglanti.checkConnectivity());

  @override
  Stream<bool> get degisim => _baglanti.onConnectivityChanged.map(_var);
}
