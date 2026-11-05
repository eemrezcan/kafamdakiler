import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'hata_metni.dart';
import 'widgets.dart';

/// Why a brain read failed, in the terms a screen shows (Kat 1, karar 3: these
/// screens need the network).
enum BeyinHataTuru {
  /// No answer from the server: offline or a timeout.
  cevrimdisi,

  /// 503: the server has no brain set up.
  kapali,

  /// 403: this account may not read the brain (`beyin.oku`).
  izinYok,

  /// 404: the project or note is not there (hidden ones look the same).
  yok,

  /// Anything else.
  diger,
}

class BeyinHatasi {
  const BeyinHatasi(this.tur, this.metin);

  /// No answer from the server.
  static const cevrimdisi = BeyinHatasi(
    BeyinHataTuru.cevrimdisi,
    'Çevrimdışısın. Bu ekran internet ister; bağlantı gelince tekrar dene.',
  );

  final BeyinHataTuru tur;
  final String metin;

  IconData get ikon => switch (tur) {
        BeyinHataTuru.cevrimdisi => LucideIcons.cloudOff,
        BeyinHataTuru.kapali => LucideIcons.brain,
        BeyinHataTuru.izinYok => LucideIcons.lock,
        BeyinHataTuru.yok => LucideIcons.fileQuestionMark,
        BeyinHataTuru.diger => LucideIcons.triangleAlert,
      };
}

/// Turns a failed read into a message that says what to do next.
BeyinHatasi beyinHatasi(Object hata) {
  if (hata is DioException) {
    switch (hata.response?.statusCode) {
      case null:
        return BeyinHatasi.cevrimdisi;
      case 503:
        return const BeyinHatasi(
          BeyinHataTuru.kapali,
          'Beyin bağlı değil. Sunucuda beyin ayarlanmamış ya da kapalı.',
        );
      case 403:
        return const BeyinHatasi(BeyinHataTuru.izinYok, 'Beyni okuma iznin yok.');
      case 404:
        return const BeyinHatasi(BeyinHataTuru.yok, 'Bulunamadı; silinmiş ya da erişime kapalı olabilir.');
    }
  }
  return BeyinHatasi(BeyinHataTuru.diger, hataMetni(hata, islem: 'Beyin okunamadı'));
}

/// The state shown where a brain read failed: the reason and a retry button
/// (permissions can change on the server, and the brain can be set up while the app is open).
class BeyinHataDurumu extends StatelessWidget {
  const BeyinHataDurumu({super.key, required this.hata, required this.onTekrar});

  final BeyinHatasi hata;
  final VoidCallback onTekrar;

  @override
  Widget build(BuildContext context) => BosDurum(
        ikon: hata.ikon,
        metin: hata.metin,
        dugme: 'Tekrar dene',
        onPressed: onTekrar,
      );
}
