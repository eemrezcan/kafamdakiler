import 'dart:async';

import 'package:dio/dio.dart';

import '../../utils/bildirim_plani.dart';
import '../../utils/push_hedefi.dart';
import '../models/sunucu_bildirimi.dart';
import '../services/sunucu_bildirim_gosterici.dart';

/// Turns the "wake up" message of the server into a notification on the phone. FCM carries only the id
/// (`data: {bildirimId}`); the title and text are read from the server's own API, so Google never sees them.
/// The same code runs in the app's isolate (app open) and in the background isolate (app closed).
class PushMesajIsleyici {
  PushMesajIsleyici({
    required this._getir,
    required this._gosterici,
    this.zamanAsimi = const Duration(seconds: 8),
  });

  static const yedekBaslik = 'Kafamdakiler';

  /// Shown when the text cannot be fetched (the tailnet is down, the phone is offline).
  static const yedekMetin = 'Yeni bildirim var';

  final Future<SunucuBildirimi> Function(String id) _getir;
  final SunucuBildirimGosterici _gosterici;

  /// A message that wakes a closed app has only a short time to do its work.
  final Duration zamanAsimi;

  /// Handles the `data` of one message. A message without `bildirimId` is not the server's and is ignored. A 404 means
  /// the notification is not this user's (or is gone): nothing is shown. Any other failure shows [yedekMetin].
  Future<void> isle(Map<String, String> veri) async {
    final id = veri['bildirimId'];
    if (id == null || id.isEmpty) return;

    SunucuBildirimi? bildirim;
    try {
      bildirim = await _getir(id).timeout(zamanAsimi);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return;
    } on Object {
      // Offline, timed out, a server error: the fallback text below.
    }

    // A reminder's moment is the same notification as the one the phone schedules for it: the same id, so the two meet. The
    // shower takes the scheduled one down (or, when it already rang, updates it without ringing again).
    if (bildirim != null && bildirim.hatirlaticiZamaniMi) {
      await _gosterici.hatirlaticiGoster(
        id: bildirimKimligi(bildirim.hedefKimligi!),
        baslik: bildirim.baslik,
        govde: bildirim.metin,
        hatirlaticiId: bildirim.hedefKimligi!,
      );
      return;
    }

    await _gosterici.goster(
      id: bildirimKimligi('sunucu:$id'),
      baslik: bildirim?.baslik ?? yedekBaslik,
      govde: bildirim?.metin ?? yedekMetin,
      yuk: sunucuBildirimYuku(bildirim?.rota, bildirim?.hedefKimligi),
    );
  }
}
