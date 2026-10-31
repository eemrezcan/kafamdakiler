import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

/// Runs [gonder] when connectivity comes back and when the app returns to the
/// foreground (and once at start).
class EsitlemeTetikleyici with WidgetsBindingObserver {
  EsitlemeTetikleyici({required this.gonder, Stream<List<ConnectivityResult>>? baglanti})
      : _baglanti = baglanti ?? Connectivity().onConnectivityChanged;

  final Future<void> Function() gonder;
  final Stream<List<ConnectivityResult>> _baglanti;
  StreamSubscription<List<ConnectivityResult>>? _abonelik;

  void baslat() {
    WidgetsBinding.instance.addObserver(this);
    _abonelik = _baglanti.listen((sonuclar) {
      if (sonuclar.any((s) => s != ConnectivityResult.none)) gonder();
    });
    gonder();
  }

  void durdur() {
    WidgetsBinding.instance.removeObserver(this);
    _abonelik?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) gonder();
  }
}
