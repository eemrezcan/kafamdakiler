import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/gun_gorunum.dart';
import '../../data/models/hatirlatici.dart';
import 'hatirlatici_alanlari.dart';

/// The grey line under a row's title: place, project, "2 günden 1.", "3 gün gecikti", how often it repeats.
String yapilacakAltMetni(Yapilacak o) {
  final parcalar = <String>[
    if (o.yer != null && o.yer!.isNotEmpty) o.yer!,
    if (o.proje != null && o.proje!.isNotEmpty) o.proje!,
    if (o.bolunmus != null) '${o.bolunmus!.toplam} günden ${o.bolunmus!.sira}.',
    if (o.gecikmeGun != null && o.gecikmeGun! > 0) '${o.gecikmeGun} gün gecikti',
    if (o.hatirlatici != null && o.hatirlatici!.tekrar != Tekrar.yok) tekrarMetni(o.hatirlatici!),
    if (o.yerel) 'gönderilecek',
  ];
  return parcalar.join(' · ');
}

/// One row of the one list (plan item, task, reminder, event): the hour, the title, the estimate, the bell or repeat sign
/// and the "yaptım" box. Tapping the row opens the row's sheet; the box is its own tap target (48 dp).
class YapilacakSatiri extends StatelessWidget {
  const YapilacakSatiri({super.key, required this.oge, required this.onAc, this.onYaptim, this.gunGoster = false});

  final Yapilacak oge;
  final VoidCallback onAc;

  /// Null hides the box's action (an event, a row not sent yet, or someone who may not write).
  final VoidCallback? onYaptim;

  /// The first column names the row's day ("18 Kas") instead of its hour: the upcoming list (sözleşme E1).
  final bool gunGoster;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    final alt = yapilacakAltMetni(oge);
    final h = oge.hatirlatici;
    return InkWell(
      onTap: onAc,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            children: [
              SizedBox(
                width: gunGoster ? 62 : 46,
                child: Text(
                  gunGoster && oge.tarih != null ? DateFormat('d MMM', 'tr').format(oge.tarih!) : (oge.saat ?? ''),
                  style: tema.textTheme.labelLarge?.copyWith(color: tema.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        oge.baslik,
                        style: tema.textTheme.bodyLarge?.copyWith(
                          decoration: oge.yapildi ? TextDecoration.lineThrough : null,
                          color: oge.yapildi ? soluk : null,
                        ),
                      ),
                      if (alt.isNotEmpty) Text(alt, style: tema.textTheme.bodySmall?.copyWith(color: soluk)),
                    ],
                  ),
                ),
              ),
              if (oge.tahminDk != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(sureMetni(oge.tahminDk!), style: tema.textTheme.bodySmall?.copyWith(color: soluk)),
                ),
              if (oge.tur == YapilacakTuru.etkinlik)
                Padding(padding: const EdgeInsets.only(left: 8), child: Icon(LucideIcons.calendar, size: 16, color: soluk))
              else if (h != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    h.tekrar == Tekrar.yok ? LucideIcons.bell : LucideIcons.repeat,
                    size: 16,
                    color: tema.colorScheme.primary,
                    semanticLabel: 'Hatırlatıcı var',
                  ),
                ),
              if (oge.yapilabilir)
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Checkbox(
                    key: ValueKey('yaptim-${oge.kimlik}'),
                    value: oge.yapildi,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: onYaptim == null ? null : (_) => onYaptim!(),
                  ),
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// The rows in one card with a hairline between them.
class YapilacakListesi extends StatelessWidget {
  const YapilacakListesi({super.key, required this.ogeler, required this.onAc, this.onYaptim, this.gunGoster = false});

  final List<Yapilacak> ogeler;

  /// See [YapilacakSatiri.gunGoster].
  final bool gunGoster;
  final void Function(Yapilacak) onAc;
  final void Function(Yapilacak)? onYaptim;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < ogeler.length; i++) ...[
            if (i > 0) Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
            YapilacakSatiri(
              oge: ogeler[i],
              gunGoster: gunGoster,
              onAc: () => onAc(ogeler[i]),
              onYaptim: onYaptim == null || !ogeler[i].yapilabilir || ogeler[i].yerel ? null : () => onYaptim!(ogeler[i]),
            ),
          ],
        ],
      ),
    );
  }
}
