import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/zaman_cizelgesi.dart';
import '../../utils/aliskanlik_gunu.dart';
import '../core/beyin_gorunum.dart';
import '../core/widgets.dart';
import 'zaman_cizelgesi_view_model.dart';

/// Today's timeline (K2.3c): what has an hour (calendar events, timed reminders) on a time strip in the order of the clock,
/// and under it all-day events and reminders without an hour. Plan items are not repeated here: the plan card lists them.
/// Tapping an item shows its detail. Hidden until the first answer, when the read failed, and when nothing has an hour (unless
/// the day does not fit, which is worth saying); offline it shows the phone's last copy and says so.
class ZamanCizelgesiKarti extends StatelessWidget {
  const ZamanCizelgesiKarti({super.key, required this.viewModel});

  final ZamanCizelgesiViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final cizelge = viewModel.cizelge;
        if (cizelge == null || _gizli(cizelge)) return const SizedBox.shrink();
        final saatsiz = [for (final o in cizelge.saatsiz) if (o.tur != ZamanCizelgesiTuru.plan) o];
        final tema = Theme.of(context);
        final soluk = tema.colorScheme.onSurfaceVariant;
        return Padding(
          padding: const EdgeInsets.only(bottom: kartAraligi),
          child: Card(
            key: const Key('zaman-cizelgesi'),
            child: Padding(
              padding: kartIcBosluk,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const KartBasligi('Zaman çizelgesi'),
                  if (viewModel.cevrimdisi)
                    _Not(
                      ikon: LucideIcons.cloudOff,
                      metin: 'Çevrimdışısın; son eşitlenen çizelge gösteriliyor.',
                      anahtar: const Key('zaman-cevrimdisi'),
                    ),
                  if (_googleNotu(cizelge) case final not?)
                    _Not(ikon: LucideIcons.calendarX, metin: not, anahtar: const Key('zaman-google')),
                  if (cizelge.plan == 'okunamadi')
                    const _Not(ikon: LucideIcons.brain, metin: 'Plan okunamadı; plan maddeleri bu çizelgede yok.'),
                  if (cizelge.kapasite case final k?)
                    Container(
                      key: const Key('zaman-kapasite'),
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: tema.colorScheme.error),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.triangleAlert, size: 18, color: tema.colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Bugün sığmıyor: açık işler ${dakikaMetni(k.planDk)} ve etkinlikler ${dakikaMetni(k.etkinlikDk)}, '
                              'günlük kapasite ${dakikaMetni(k.kapasiteDk)}; ${dakikaMetni(k.asimDk)} fazla.',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (cizelge.saatli.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (var i = 0; i < cizelge.saatli.length; i++)
                      _SaatliSatir(
                        oge: cizelge.saatli[i],
                        ilk: i == 0,
                        son: i == cizelge.saatli.length - 1,
                        onTap: () => _ayrinti(context, cizelge.saatli[i]),
                      ),
                  ],
                  if (saatsiz.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 2),
                      child: Text('Saatsiz', style: tema.textTheme.labelLarge?.copyWith(color: soluk)),
                    ),
                    for (final o in saatsiz) _SaatsizSatir(oge: o, onTap: () => _ayrinti(context, o)),
                  ],
                  if (cizelge.sonEsitleme case final an?)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Takvim son eşitleme: ${_saatMetni(an)}',
                        style: TextStyle(fontSize: 11, color: soluk),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Without an item that has an hour the card takes no room on Bugün (the plan card lists the hourless plan items); only the
  /// "does not fit" warning keeps it.
  static bool _gizli(ZamanCizelgesi c) => c.saatli.isEmpty && c.kapasite == null;

  /// What to tell about the Google link; null when it is fine or the module is simply off (nothing to say).
  static String? _googleNotu(ZamanCizelgesi c) => switch (c.google) {
    GoogleDurumu.bagliDegil => 'Google Takvim bağlı değil; yalnız hatırlatıcılar ve plan görünüyor.',
    GoogleDurumu.yenidenBaglan => 'Google Takvim bağlantısı koptu; yönetimden yeniden bağlanmalı.',
    _ => null,
  };

  /// "14:05" in Istanbul time (a fixed UTC+3).
  static String _saatMetni(DateTime an) => DateFormat('d MMM HH:mm', 'tr').format(an.toUtc().add(istanbulFarki));

  static Future<void> _ayrinti(BuildContext context, ZamanCizelgesiOgesi oge) => showModalBottomSheet<void>(
    context: context,
    // Above the shell's "Yakala" button, which would otherwise cover the sheet's lower part.
    useRootNavigator: true,
    showDragHandle: true,
    builder: (_) => _Ayrinti(oge: oge),
  );
}

class _Not extends StatelessWidget {
  const _Not({required this.ikon, required this.metin, this.anahtar});

  final IconData ikon;
  final String metin;
  final Key? anahtar;

  @override
  Widget build(BuildContext context) {
    final soluk = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      key: anahtar,
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(ikon, size: 16, color: soluk),
          const SizedBox(width: 6),
          Expanded(
            child: Text(metin, style: TextStyle(fontSize: 12, color: soluk)),
          ),
        ],
      ),
    );
  }
}

IconData _ikon(ZamanCizelgesiOgesi o) => switch (o.tur) {
  ZamanCizelgesiTuru.etkinlik => LucideIcons.calendar,
  ZamanCizelgesiTuru.hatirlatici => LucideIcons.bell,
  _ => o.durum == 'yapildi' ? LucideIcons.circleCheck : LucideIcons.circle,
};

/// One row of the time strip: the hour on the left, a line with a dot, the item on the right.
class _SaatliSatir extends StatelessWidget {
  const _SaatliSatir({required this.oge, required this.ilk, required this.son, required this.onTap});

  final ZamanCizelgesiOgesi oge;
  final bool ilk;
  final bool son;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    final cizgi = tema.colorScheme.outlineVariant;
    final etkinlik = oge.etkinlikMi;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    oge.saat ?? '',
                    style: tema.textTheme.labelLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ),
              ),
              SizedBox(
                width: 20,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: ilk ? 20 : 0,
                      bottom: son ? 20 : 0,
                      child: Container(width: 2, color: cizgi),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: etkinlik ? tema.colorScheme.primary : tema.colorScheme.surface,
                        border: Border.all(color: etkinlik ? tema.colorScheme.primary : soluk, width: 2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(oge.baslik, style: const TextStyle(fontWeight: FontWeight.w500)),
                      if (etkinlik)
                        Text(
                          [
                            if (oge.saatAraligi != null) oge.saatAraligi!,
                            if (oge.sureDk != null && oge.sureDk! > 0) dakikaMetni(oge.sureDk!),
                            if (oge.yer != null && oge.yer!.isNotEmpty) oge.yer!,
                          ].join(' · '),
                          style: TextStyle(fontSize: 12, color: soluk),
                        )
                      else
                        Text('Hatırlatıcı', style: TextStyle(fontSize: 12, color: soluk)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaatsizSatir extends StatelessWidget {
  const _SaatsizSatir({required this.oge, required this.onTap});

  final ZamanCizelgesiOgesi oge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final soluk = Theme.of(context).colorScheme.onSurfaceVariant;
    final yapildi = oge.durum == 'yapildi';
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Icon(_ikon(oge), size: 18, color: soluk),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                oge.baslik,
                style: yapildi ? TextStyle(color: soluk, decoration: TextDecoration.lineThrough) : null,
              ),
            ),
            if (oge.tumGun) Text('tüm gün', style: TextStyle(fontSize: 11, color: soluk)),
            if (oge.tahminDk != null) ...[
              const SizedBox(width: 8),
              Text(dakikaMetni(oge.tahminDk!), style: TextStyle(fontSize: 12, color: soluk)),
            ],
          ],
        ),
      ),
    );
  }
}

/// The detail sheet of one item.
class _Ayrinti extends StatelessWidget {
  const _Ayrinti({required this.oge});

  final ZamanCizelgesiOgesi oge;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    Widget satir(IconData ikon, String metin) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 18, color: soluk),
          const SizedBox(width: 10),
          Expanded(child: Text(metin)),
        ],
      ),
    );
    final tur = switch (oge.tur) {
      ZamanCizelgesiTuru.etkinlik => 'Takvim etkinliği',
      ZamanCizelgesiTuru.hatirlatici => 'Hatırlatıcı',
      _ => 'Plan maddesi',
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          key: const Key('zaman-ayrinti'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tur, style: TextStyle(fontSize: 12, color: soluk)),
            Text(oge.baslik, style: tema.textTheme.titleLarge),
            if (oge.tumGun) satir(LucideIcons.clock, 'Tüm gün'),
            if (oge.saatAraligi case final a?) satir(LucideIcons.clock, a),
            if (oge.sureDk != null && oge.sureDk! > 0) satir(LucideIcons.hourglass, dakikaMetni(oge.sureDk!)),
            if (oge.yer != null && oge.yer!.isNotEmpty) satir(LucideIcons.mapPin, oge.yer!),
            if (oge.bolum != null) satir(LucideIcons.listTodo, oge.bolum!),
            if (oge.tahminDk != null) satir(LucideIcons.hourglass, 'Tahmin: ${dakikaMetni(oge.tahminDk!)}'),
            if (oge.durum != null) satir(LucideIcons.circleCheck, oge.durum == 'yapildi' ? 'Yapıldı' : 'Açık'),
          ],
        ),
      ),
    );
  }
}
