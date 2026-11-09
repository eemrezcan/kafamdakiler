import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import '../../config/app_config.dart';
import '../repositories/push_mesaj_isleyici.dart';
import 'api_service.dart';
import 'sunucu_bildirim_gosterici.dart';
import 'token_depo.dart';

/// FCM calls this in a fresh isolate when a message arrives while the app is in the background or closed. It builds its
/// own client from the stored tokens (`flutter_secure_storage`, `dio`), reads the text of the notification from the
/// server and shows it. An expired access token is renewed by the usual interceptor; if the session itself is over
/// there is nothing to do here, so the "session closed" callback is empty.
///
/// A top-level function with the entry-point pragma: the isolate can only start a function it can find by name.
@pragma('vm:entry-point')
Future<void> pushArkaPlanIsleyici(RemoteMessage mesaj) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final api = ApiService(apiDioOlustur(apiUrl: AppConfig.apiUrl, depo: GuvenliTokenDepo(), oturumKapandi: () {}));
  await PushMesajIsleyici(
    getir: api.sunucuBildirimiGetir,
    gosterici: YerelSunucuBildirimGosterici(eklentiyiBaslat: true),
  ).isle(mesaj.data.map((k, v) => MapEntry(k, '$v')));
}
