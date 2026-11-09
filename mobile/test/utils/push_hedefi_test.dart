import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafamdakiler/data/services/bildirim_servisi.dart';
import 'package:kafamdakiler/utils/push_hedefi.dart';

// Where a tap on a notification of the server goes: the route the server named, or Bugün; never an address.

void main() {
  group('hedefRotasi', () {
    test('no target is the Bugün screen', () {
      expect(hedefRotasi(null, null), '/');
      expect(hedefRotasi('', '42'), '/');
    });

    test('a plain in-app path is kept', () {
      expect(hedefRotasi('/hatirlaticilar', null), '/hatirlaticilar');
      expect(hedefRotasi('/eylemler', '7'), '/eylemler');
    });

    test('{id} is filled with the target id', () {
      expect(hedefRotasi('/eylem/{id}', 'a b'), '/eylem/a%20b');
    });

    test('{id} without an id falls back to Bugün', () {
      expect(hedefRotasi('/eylem/{id}', null), '/');
      expect(hedefRotasi('/eylem/{id}', ''), '/');
    });

    test('anything that is not a plain in-app path falls back to Bugün', () {
      for (final kotu in ['https://evil.example', '//evil.example', 'hatirlaticilar', '/a/../b', '/a?x=1', '/a#b', 'javascript:1']) {
        expect(hedefRotasi(kotu, '1'), '/', reason: kotu);
      }
    });
  });

  group('payload', () {
    test('a server payload carries the route and is read back', () {
      expect(sunucuBildirimYuku('/hatirlaticilar', null), 'rota:/hatirlaticilar');
      expect(sunucuBildirimRotasi('rota:/hatirlaticilar'), '/hatirlaticilar');
      expect(sunucuBildirimYuku(null, null), 'rota:/');
    });

    test('other payloads (a reminder id, the briefing, an action) are not server payloads', () {
      expect(sunucuBildirimRotasi('3f2a'), isNull);
      expect(sunucuBildirimRotasi('eylem:abc'), isNull);
      expect(sunucuBildirimRotasi(null), isNull);
    });

    test('a tap on a server notification becomes a response with the route', () {
      final yanit = YerelBildirimServisi.yanittan(const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: 'rota:/hatirlaticilar',
      ));
      expect(yanit?.rota, '/hatirlaticilar');
      expect(yanit?.hatirlaticiId, isNull);
    });
  });
}
