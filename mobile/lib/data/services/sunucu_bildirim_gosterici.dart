import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../utils/bildirim_plani.dart';

/// Shows a notification of the server at once, behind a small interface so the message handler (and its tests) never
/// touch the plugin.
/// One button of a work card's notification: [kod] is the id of the Android action (see `IsBildirimEylemi`), [etiket] its text.
typedef IsBildirimDugmesi = ({String kod, String etiket});

abstract interface class SunucuBildirimGosterici {
  Future<void> goster({required int id, required String baslik, required String govde, required String yuk});

  /// The server's copy of a reminder's moment. [id] is the id of the phone's own notification for that reminder
  /// (`bildirimKimligi(hatirlaticiId)`), so there is only ever one: the scheduled one is taken down when it has not rung
  /// yet, and one that already rang (still in the tray) is updated in place without a new sound.
  Future<void> hatirlaticiGoster({required int id, required String baslik, required String govde, required String hatirlaticiId});

  /// A work card that fell to the person. [dugmeler] (at most three) open the app and write the choice to the server; a tap
  /// opens the card ([yuk] names its route). Without buttons it is a plain notification.
  Future<void> isKartiGoster({
    required int id,
    required String baslik,
    required String govde,
    required String yuk,
    required List<IsBildirimDugmesi> dugmeler,
  });
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

  // The reminders' own channel (see YerelBildirimServisi): one channel, so the user's settings for it hold for both copies.
  static const hatirlaticiKanalKimligi = 'hatirlaticilar';

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

  @override
  Future<void> isKartiGoster({
    required int id,
    required String baslik,
    required String govde,
    required String yuk,
    required List<IsBildirimDugmesi> dugmeler,
  }) async {
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
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            kanalKimligi,
            'Sunucu bildirimleri',
            channelDescription: 'Sunucunun uygulama kapalıyken de gönderdiği anlık bildirimler',
            importance: Importance.high,
            priority: Priority.high,
            // The buttons open the app, like the reminders': the choice is written to the server there, and a failure
            // is told on this same notification ("açıp tekrar dene").
            actions: [
              for (final d in dugmeler.take(3)) AndroidNotificationAction(d.kod, d.etiket, showsUserInterface: true),
            ],
          ),
        ),
        payload: yuk,
      );
    } on Object catch (e) {
      debugPrint('İş kartı bildirimi gösterilemedi ($id): $e');
    }
  }

  @override
  Future<void> hatirlaticiGoster({required int id, required String baslik, required String govde, required String hatirlaticiId}) async {
    try {
      if (eklentiyiBaslat && !_basladi) {
        await _eklenti.initialize(
          settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        );
        _basladi = true;
      }
      final trayda = (await _eklenti.getActiveNotifications()).any((n) => n.id == id);
      // Not rung yet: the scheduled copy is taken down, this one rings. Already in the tray: this only updates it.
      if (!trayda) await _eklenti.cancel(id: id);
      await _eklenti.show(
        id: id,
        title: baslik,
        body: govde,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            hatirlaticiKanalKimligi,
            'Hatırlatıcılar',
            channelDescription: 'Hatırlatıcıların zamanı ve "kaç gün önce" uyarıları',
            importance: Importance.high,
            priority: Priority.high,
            onlyAlertOnce: trayda,
            // The same buttons as the scheduled one. They open the app, which writes the choice to the queue.
            actions: const [
              AndroidNotificationAction(BildirimEylemi.yaptim, 'Yaptım', showsUserInterface: true, cancelNotification: true),
              AndroidNotificationAction(BildirimEylemi.birSaatErtele, '1 saat ertele', showsUserInterface: true),
              AndroidNotificationAction(BildirimEylemi.yarinErtele, 'Yarın', showsUserInterface: true),
            ],
          ),
        ),
        // The payload of a scheduled reminder is the reminder's id: a tap or a button is answered the same way.
        payload: hatirlaticiId,
      );
    } on Object catch (e) {
      debugPrint('Hatırlatıcı bildirimi gösterilemedi ($id): $e');
    }
  }
}
