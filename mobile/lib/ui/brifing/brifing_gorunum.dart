import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/brifing.dart';
import '../core/hata_metni.dart';

// Words and icons of the morning briefing, shared by its card in the assistant feed.

/// The icon of a kind of card.
IconData brifingTurIkonu(String tur) => switch (tur) {
      BrifingTuru.plan => LucideIcons.calendarCheck,
      BrifingTuru.kalan => LucideIcons.history,
      BrifingTuru.hatirlatici => LucideIcons.bell,
      BrifingTuru.onay => LucideIcons.listChecks,
      BrifingTuru.takvim => LucideIcons.calendarClock,
      BrifingTuru.kapasite => LucideIcons.gauge,
      _ => LucideIcons.sun,
    };

/// The cards the feed shows: the leftovers card is left out, because Bugün lists what is left from yesterday itself.
List<BrifingKarti> brifingKartlari(Brifing brifing) => [
      for (final k in brifing.kartlar)
        if (k.tur != BrifingTuru.kalan) k,
    ];

/// A Turkish message for a failed briefing call.
String brifingHataMetni(Object hata, {String islem = 'Brifing alınamadı'}) {
  if (hata is DioException) {
    switch (hata.response?.statusCode) {
      case 404:
        return 'Brifing henüz hazır değil. Ayarlanan saatten sonra tekrar dene.';
      case 429:
        return 'Bugünlük yenileme sınırı doldu.';
      case 503:
        return 'Brifing şu an hazırlanamıyor. Biraz sonra tekrar dene.';
      case 403:
        return 'Brifingi okuma iznin yok.';
    }
    if (cevrimdisiHata(hata)) return 'Çevrimdışısın: oy gönderilmedi. Bağlantı gelince tekrar dene.';
  }
  return hataMetni(hata, islem: islem);
}
