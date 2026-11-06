import 'package:quick_actions/quick_actions.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../models/yakala_girdisi.dart';
import '../repositories/yakala_yonlendirici.dart';

/// The only place that talks to the platform plugins: Android's share menu
/// (`receive_sharing_intent`) and the app shortcut and home screen widget (`quick_actions`). What comes
/// in is converted by [paylasimdanGirdi] / [kisayolGirdisi] and parked in [BekleyenYakala].
/// Not covered by unit tests (platform channels); tried by hand with `adb`.
class PaylasimKaynagi {
  PaylasimKaynagi(this._bekleyen);

  final BekleyenYakala _bekleyen;

  /// Each step catches its own failure, so one broken step does not skip the others.
  Future<void> baslat() async {
    try {
      final paylasim = ReceiveSharingIntent.instance;
      // Warm start: the app was already open.
      paylasim.getMediaStream().listen(_geldi, onError: (Object _) {});
      // Cold start: the app was opened by the share.
      _geldi(await paylasim.getInitialMedia());
      await paylasim.reset();
    } on Object {
      // No share menu this run.
    }

    try {
      // The "Yakala" app shortcut and the home screen widget (YakalaWidget.kt) both arrive here.
      const eylemler = QuickActions();
      await eylemler.initialize((tur) {
        final girdi = kisayolGirdisi(tur);
        if (girdi != null) _bekleyen.bekle(girdi);
      });
      await eylemler.setShortcutItems(const [
        ShortcutItem(type: yakalaKisayoluTuru, localizedTitle: 'Yakala'),
      ]);
    } on Object {
      // No shortcut this run.
    }
  }

  void _geldi(List<SharedMediaFile> dosyalar) {
    final girdi = paylasimdanGirdi([
      for (final d in dosyalar)
        PaylasimOgesi(
          switch (d.type) {
            SharedMediaType.text || SharedMediaType.url => PaylasimTuru.metin,
            SharedMediaType.image => PaylasimTuru.gorsel,
            _ => PaylasimTuru.diger,
          },
          d.path,
        ),
    ]);
    if (girdi != null) _bekleyen.bekle(girdi);
  }
}
