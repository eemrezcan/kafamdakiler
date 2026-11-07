import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../utils/bildirim_plani.dart';

/// What the user did with a notification: [eylem] is a [BildirimEylemi] id, or null for a tap on the notification.
class BildirimYaniti {
  const BildirimYaniti({this.eylem, this.hatirlaticiId, this.eylemId});

  final String? eylem;
  final String? hatirlaticiId;

  /// Set for an approval queue notification: the action it announced ('' for the summary of many).
  final String? eylemId;
}

/// The phone's notification scheduler, behind a small interface so the rest of the app (and the tests) never touch
/// the plugin.
abstract class BildirimServisi {
  /// Starts the plugin. [yanit] hears the taps and buttons while the app is running.
  Future<void> baslat({required void Function(BildirimYaniti) yanit});

  /// The response that opened the app from a closed state, once; null otherwise.
  Future<BildirimYaniti?> acilisYaniti();

  /// Asks for the notification permission (Android 13+) and, once per run, the exact alarm permission. True when
  /// notifications are allowed.
  Future<bool> izinIste();

  /// Cancels every scheduled notification and sets [plan] up again.
  Future<void> kur(List<PlanliBildirim> plan);

  /// Shows an approval queue notification at once.
  Future<void> eylemBildir(EylemBildirimi bildirim);

  /// Takes the notification with [id] down (the action was decided).
  Future<void> bildirimiKapat(int id);
}

/// [BildirimServisi] on `flutter_local_notifications`. Not covered by unit tests (platform channels); tried by hand
/// on the emulator. Every call catches the platform failing, so a broken notification setup never stops the app.
class YerelBildirimServisi implements BildirimServisi {
  YerelBildirimServisi([FlutterLocalNotificationsPlugin? eklenti]) : _eklenti = eklenti ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _eklenti;
  bool _kesinIstendi = false;

  static const _kanalKimligi = 'hatirlaticilar';
  static const _eylemKanalKimligi = 'eylemler';

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _eklenti.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static BildirimYaniti? _yanittan(NotificationResponse? y) {
    if (y == null) return null;
    final eylem = y.actionId;
    final secilen = eylem == null || eylem.isEmpty ? null : eylem;
    final yuk = y.payload;
    if (yuk != null && yuk.startsWith(eylemBildirimOneki)) {
      return BildirimYaniti(eylem: secilen, eylemId: yuk.substring(eylemBildirimOneki.length));
    }
    return BildirimYaniti(eylem: secilen, hatirlaticiId: yuk);
  }

  @override
  Future<void> baslat({required void Function(BildirimYaniti) yanit}) async {
    try {
      await _eklenti.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (y) {
          final b = _yanittan(y);
          if (b != null) yanit(b);
        },
      );
    } on Object catch (e) {
      debugPrint('Bildirimler başlatılamadı: $e');
    }
  }

  @override
  Future<BildirimYaniti?> acilisYaniti() async {
    try {
      final ayrinti = await _eklenti.getNotificationAppLaunchDetails();
      if (ayrinti == null || !ayrinti.didNotificationLaunchApp) return null;
      return _yanittan(ayrinti.notificationResponse);
    } on Object {
      return null;
    }
  }

  @override
  Future<bool> izinIste() async {
    try {
      final android = _android;
      if (android == null) return false;
      final izin = await android.requestNotificationsPermission() ?? false;
      // The exact alarm permission opens a system settings page; asking once per run is enough. Without it the
      // notifications are still set up, with an approximate time ([kur]).
      if (izin && !_kesinIstendi && !(await android.canScheduleExactNotifications() ?? false)) {
        _kesinIstendi = true;
        await android.requestExactAlarmsPermission();
      }
      return izin;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> kur(List<PlanliBildirim> plan) async {
    try {
      await _eklenti.cancelAllPendingNotifications();
      if (plan.isEmpty) return;
      final kesin = await _android?.canScheduleExactNotifications() ?? false;
      for (final b in plan) {
        try {
          await _eklenti.zonedSchedule(
            id: b.id,
            title: b.baslik,
            body: b.govde,
            scheduledDate: tz.TZDateTime.from(b.an, tz.UTC),
            notificationDetails: NotificationDetails(android: _ayrinti(b)),
            // Without the exact alarm permission an approximate alarm is used instead of failing.
            androidScheduleMode: kesin ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
            payload: b.hatirlaticiId,
          );
        } on Object catch (e) {
          debugPrint('Bildirim kurulamadı (${b.id}): $e');
        }
      }
    } on Object catch (e) {
      debugPrint('Bildirimler kurulamadı: $e');
    }
  }

  @override
  Future<void> eylemBildir(EylemBildirimi b) async {
    try {
      await _eklenti.show(
        id: b.id,
        title: b.baslik,
        body: b.govde,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _eylemKanalKimligi,
            'Onay kuyruğu',
            channelDescription: 'Onayını bekleyen eylem önerileri',
            importance: Importance.high,
            priority: Priority.high,
            // The buttons open the app: the decision is written to the queue there, with the app's own database.
            actions: b.eylemler
                ? const [
                    AndroidNotificationAction(BildirimEylemi.eylemOnayla, 'Onayla', showsUserInterface: true, cancelNotification: true),
                    AndroidNotificationAction(BildirimEylemi.eylemReddet, 'Reddet', showsUserInterface: true, cancelNotification: true),
                  ]
                : null,
          ),
        ),
        payload: '$eylemBildirimOneki${b.eylemId ?? ''}',
      );
    } on Object catch (e) {
      debugPrint('Eylem bildirimi gösterilemedi (${b.id}): $e');
    }
  }

  @override
  Future<void> bildirimiKapat(int id) async {
    try {
      await _eklenti.cancel(id: id);
    } on Object catch (e) {
      debugPrint('Bildirim kapatılamadı ($id): $e');
    }
  }

  AndroidNotificationDetails _ayrinti(PlanliBildirim b) => AndroidNotificationDetails(
        _kanalKimligi,
        'Hatırlatıcılar',
        channelDescription: 'Hatırlatıcıların zamanı ve "kaç gün önce" uyarıları',
        importance: Importance.high,
        priority: Priority.high,
        // The buttons open the app: the action is written to the queue there, with the app's own database.
        actions: b.eylemler
            ? const [
                AndroidNotificationAction(BildirimEylemi.yaptim, 'Yaptım', showsUserInterface: true, cancelNotification: true),
                AndroidNotificationAction(BildirimEylemi.birSaatErtele, '1 saat ertele', showsUserInterface: true),
                AndroidNotificationAction(BildirimEylemi.yarinErtele, 'Yarın', showsUserInterface: true),
              ]
            : null,
      );
}
