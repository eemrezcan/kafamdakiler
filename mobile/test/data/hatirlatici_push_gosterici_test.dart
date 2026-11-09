import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/services/sunucu_bildirim_gosterici.dart';
import 'package:kafamdakiler/utils/bildirim_plani.dart';

// What the phone does with the server's copy of a reminder's moment, on a fake notification plugin: the scheduled copy with the same
// id is taken down when it has not rung, and one that already rang in the tray is only updated, without ringing again.

class _SahteEklenti extends Fake implements FlutterLocalNotificationsPlugin {
  /// Ids scheduled for later, and ids showing in the tray.
  final planli = <int>{};
  final trayda = <int>{};
  final olaylar = <String>[];
  AndroidNotificationDetails? sonAyrinti;
  String? sonPayload;
  String? sonBaslik;

  @override
  Future<List<ActiveNotification>> getActiveNotifications() async => [for (final id in trayda) ActiveNotification(id: id)];

  // Like the real plugin, cancelling an id takes down both the scheduled copy and the one in the tray.
  @override
  Future<void> cancel({required int id, String? tag}) async {
    olaylar.add('cancel:$id');
    planli.remove(id);
    trayda.remove(id);
  }

  @override
  Future<void> show({required int id, String? title, String? body, NotificationDetails? notificationDetails, String? payload}) async {
    olaylar.add('show:$id');
    trayda.add(id);
    sonAyrinti = notificationDetails?.android;
    sonPayload = payload;
    sonBaslik = title;
  }
}

void main() {
  late _SahteEklenti eklenti;
  late YerelSunucuBildirimGosterici gosterici;
  final id = bildirimKimligi('h-1');

  setUp(() {
    eklenti = _SahteEklenti();
    gosterici = YerelSunucuBildirimGosterici(eklenti: eklenti);
  });

  Future<void> goster() => gosterici.hatirlaticiGoster(id: id, baslik: 'İlaç al', govde: 'bugün', hatirlaticiId: 'h-1');

  test('the scheduled copy has not rung: it is taken down and the push rings in its place', () async {
    eklenti.planli.add(id);

    await goster();

    expect(eklenti.olaylar, ['cancel:$id', 'show:$id']);
    expect(eklenti.planli, isEmpty);
    expect(eklenti.trayda, {id});
    expect(eklenti.sonAyrinti!.onlyAlertOnce, isFalse);
  });

  test('the scheduled copy already rang and is in the tray: the push updates it in place, without ringing again', () async {
    eklenti.trayda.add(id);

    await goster();

    expect(eklenti.olaylar, ['show:$id']);
    expect(eklenti.trayda, {id});
    expect(eklenti.sonAyrinti!.onlyAlertOnce, isTrue);
  });

  test('the same push twice leaves one notification in the tray, and the second one does not ring', () async {
    await goster();
    await goster();

    expect(eklenti.trayda, {id});
    expect(eklenti.sonAyrinti!.onlyAlertOnce, isTrue);
  });

  test('a notification of another id in the tray is left alone', () async {
    final baska = bildirimKimligi('h-2');
    eklenti.trayda.add(baska);
    eklenti.planli.add(baska);

    await goster();

    expect(eklenti.trayda, {baska, id});
    expect(eklenti.planli, {baska});
  });

  test('it carries the reminder id as its payload and the same buttons as the scheduled one, on the reminders channel', () async {
    await goster();

    expect(eklenti.sonPayload, 'h-1');
    expect(eklenti.sonBaslik, 'İlaç al');
    final android = eklenti.sonAyrinti!;
    expect(android.channelId, 'hatirlaticilar');
    expect(android.actions!.map((a) => a.id), [BildirimEylemi.yaptim, BildirimEylemi.birSaatErtele, BildirimEylemi.yarinErtele]);
  });
}
