import 'package:flutter/material.dart';

import '../../data/models/aliskanlik.dart';
import '../../data/models/enums.dart';
import '../../utils/dogrulama.dart';
import '../core/ikonlar.dart';
import '../core/renkler.dart';

/// "5 / 8 bardak", "tamam", for the label under a habit's ring on the strip.
String seritEtiketi(Aliskanlik a) {
  final b = a.bugun;
  if (a.tur == AliskanlikTuru.raf) return a.devamEdenler.isEmpty ? 'Oku' : '${sayiMetni((a.devamEdenler.first.ilerleme ?? 0) * 100)}%';
  if (a.olcu == Olcu.evetHayir) return (b?.deger ?? 0) >= 1 ? 'tamam' : 'bekliyor';
  final miktar = sayiMetni(b?.miktar ?? 0);
  return a.gunlukHedef == null ? miktar : '$miktar / ${sayiMetni(a.gunlukHedef!)}';
}

/// Today's habits as a row of rings (K-0024): a tap ticks a yes/no habit, adds one to a counter, and for a shelf habit opens
/// the reading entry; a long press on a counter types the total. [yazabilir] false (the Asistan) makes the rings plain.
class AliskanlikSeridi extends StatelessWidget {
  const AliskanlikSeridi({
    super.key,
    required this.aliskanliklar,
    required this.onTik,
    required this.onArti,
    required this.onSayiGir,
    required this.onRafAc,
    this.yazabilir = true,
  });

  final List<Aliskanlik> aliskanliklar;
  final void Function(Aliskanlik) onTik;
  final void Function(Aliskanlik) onArti;
  final void Function(Aliskanlik) onSayiGir;
  final void Function(Aliskanlik) onRafAc;
  final bool yazabilir;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: aliskanliklar.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final a = aliskanliklar[i];
          return _Halka(
            aliskanlik: a,
            onTap: !yazabilir
                ? null
                : () {
                    if (a.tur == AliskanlikTuru.raf) {
                      onRafAc(a);
                    } else if (a.olcu == Olcu.evetHayir) {
                      onTik(a);
                    } else {
                      onArti(a);
                    }
                  },
            onLongPress: yazabilir && a.tur == AliskanlikTuru.sayac && a.olcu == Olcu.sayili ? () => onSayiGir(a) : null,
          );
        },
      ),
    );
  }
}

class _Halka extends StatelessWidget {
  const _Halka({required this.aliskanlik, this.onTap, this.onLongPress});

  final Aliskanlik aliskanlik;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final renk = aliskanlikRengi(context, aliskanlik.renk);
    final oran = (aliskanlik.bugun?.deger ?? 0).clamp(0, 1).toDouble();
    final tamam = oran >= 1;
    final etiket = seritEtiketi(aliskanlik);
    return Semantics(
      button: onTap != null,
      label: '${aliskanlik.ad}, $etiket',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('serit-${aliskanlik.id}'),
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: oran,
                          strokeWidth: 5,
                          color: renk,
                          backgroundColor: tema.colorScheme.outlineVariant,
                        ),
                      ),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: tamam ? renk : Colors.transparent),
                        child: Icon(lucideIkonu(aliskanlik.ikon), size: 22, color: tamam ? tema.colorScheme.surface : renk),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(aliskanlik.ad, maxLines: 1, overflow: TextOverflow.ellipsis, style: tema.textTheme.labelMedium),
                Text(
                  etiket,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tema.textTheme.labelSmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
