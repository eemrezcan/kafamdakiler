import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// The phone's side of FCM, behind a small interface so the rest of the app (and the tests) never touch Firebase.
abstract interface class PushKaynagi {
  /// This phone's FCM token; null when Firebase is not available.
  Future<String?> token();

  /// A new token, when Firebase renews it.
  Stream<String> get tokenYenilendi;

  /// The `data` of a message that arrives while the app is open.
  Stream<Map<String, String>> get onPlanMesajlari;
}

/// Firebase did not start (no `google-services.json` in the build, or no Google services on the device): push is
/// simply off and the rest of the app works.
class KapaliPushKaynagi implements PushKaynagi {
  const KapaliPushKaynagi();

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get tokenYenilendi => const Stream.empty();

  @override
  Stream<Map<String, String>> get onPlanMesajlari => const Stream.empty();
}

/// [PushKaynagi] on `firebase_messaging`, with the registration token. The plugin marks `getToken` / `onTokenRefresh`
/// deprecated in favour of `register()` / `onRegistered` (a Firebase installation id, sent with `Message.Fid` on the
/// server); both ways work. The backend sends to the token (`FirebasePushGondericisi`), so the phone gives the token;
/// move the two together when the installation id way is wanted. Not covered by unit tests (platform channels); tried by hand on the phone.
class FirebasePushKaynagi implements PushKaynagi {
  FirebasePushKaynagi([FirebaseMessaging? mesajlasma]) : _mesajlasma = mesajlasma ?? FirebaseMessaging.instance;

  final FirebaseMessaging _mesajlasma;

  @override
  Future<String?> token() async {
    try {
      // ignore: deprecated_member_use
      return await _mesajlasma.getToken();
    } on Object catch (e) {
      debugPrint('FCM token alınamadı: $e');
      return null;
    }
  }

  @override
  // ignore: deprecated_member_use
  Stream<String> get tokenYenilendi => _mesajlasma.onTokenRefresh;

  @override
  Stream<Map<String, String>> get onPlanMesajlari =>
      FirebaseMessaging.onMessage.map((m) => m.data.map((k, v) => MapEntry(k, '$v')));
}

/// Starts Firebase and the background handler. A failure (no config, no Google services) is not fatal: the app goes
/// on with push off.
Future<PushKaynagi> pushKaynaginiHazirla(Future<void> Function(RemoteMessage) arkaPlanIsleyici) async {
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(arkaPlanIsleyici);
    return FirebasePushKaynagi();
  } on Object catch (e) {
    debugPrint('Firebase başlatılamadı, push kapalı: $e');
    return const KapaliPushKaynagi();
  }
}
