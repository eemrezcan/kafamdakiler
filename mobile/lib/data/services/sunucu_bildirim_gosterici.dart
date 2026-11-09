import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows a notification of the server at once, behind a small interface so the message handler (and its tests) never
/// touch the plugin.
abstract interface class SunucuBildirimGosterici {
  Future<void> goster({required int id, required String baslik, required String govde, required String yuk});
}

/// [SunucuBildirimGosterici] on `flutter_local_notifications`, in its own channel. Not covered by unit tests (platform
/// channels); tried by hand on the phone.
///
/// In the app's own isolate the plugin is already started by `YerelBildirimServisi` (with the tap callback), so
/// [eklentiyiBaslat] is false there. The background isolate that FCM starts for a closed app has no start yet: it passes
/// true, and a tap on the notification is then answered by the app when it opens (`acilisYaniti`).
class YerelSunucuBildirimGosterici implements SunucuBildirimGosterici {
  YerelSunucuBildirimGosterici({this.eklentiyiBaslat = false, FlutterLocalNotificationsPlugin? eklenti})
      : _eklenti = eklenti ?? FlutterLocalNotificationsPlugin();

  final bool eklentiyiBaslat;
  final FlutterLocalNotificationsPlugin _eklenti;
  bool _basladi = false;

  static const kanalKimligi = 'sunucu';

  @override
  Future<void> goster({required int id, required String baslik, required String govde, required String yuk}) async {
    try {
      if (eklentiyiBaslat && !_basladi) {
        await _eklenti.initialize(
          settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        );
        _basladi = true;
      }
      await _eklenti.show(
        id: id,
        title: baslik,
        body: govde,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            kanalKimligi,
            'Sunucu bildirimleri',
            channelDescription: 'Sunucunun uygulama kapalıyken de gönderdiği anlık bildirimler',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: yuk,
      );
    } on Object catch (e) {
      debugPrint('Sunucu bildirimi gösterilemedi ($id): $e');
    }
  }
}
