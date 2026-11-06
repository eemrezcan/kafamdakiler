import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

/// Compares the app's build number with the lowest one the API accepts
/// (`GET /api/surum`). Any failure (offline, timeout, server error) leaves the
/// app usable: only a clear "older than required" answer blocks it.
class SurumDenetcisi extends ChangeNotifier {
  SurumDenetcisi({required this.api, required this.derlemeNumarasi});

  final ApiService api;
  final int derlemeNumarasi;

  bool _guncellemeGerekli = false;
  bool get guncellemeGerekli => _guncellemeGerekli;

  Future<void> kontrolEt() async {
    try {
      final enAz = await api.enAzMobilSurumKodu();
      final gerekli = derlemeNumarasi < enAz;
      if (gerekli != _guncellemeGerekli) {
        _guncellemeGerekli = gerekli;
        notifyListeners();
      }
    } catch (_) {
      // Keep the last known state; offline use must keep working.
    }
  }
}
