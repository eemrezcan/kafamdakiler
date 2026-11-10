import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/gun_gorunum.dart';
import '../core/renkler.dart';

/// The card at the top of Bugün (K-0024): the assistant's short summary and the day's load, the open work against the
/// capacity. Too much: "devret"; very little: the free time and a way to look at tomorrow.
class GunOzetiKarti extends StatelessWidget {
  const GunOzetiKarti({super.key, required this.gun, this.onDevret, this.onYarinaBak});

  final GunGorunum gun;

  /// "Bir kısmını devret"; null (nothing to carry, or someone who may not write) leaves the sentence plain.
  final VoidCallback? onDevret;

  /// "Yarına bak": opens the calendar.
  final VoidCallback? onYarinaBak;

  /// Under this share of the capacity left free the day counts as "az iş" (little to do).
  static const azIsOrani = 0.5;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final yuk = gun.yuk;
    final ozet = gun.ozet ?? (gun.acikSayi == 0 ? 'Bugün açık iş yok.' : 'Bugün ${gun.acikSayi} iş var.');
    final zemin = Color.lerp(tema.colorScheme.surface, tema.colorScheme.primary, tema.brightness == Brightness.dark ? 0.12 : 0.08)!;
    return Card(
      color: zemin,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.sparkles, size: 14, color: tema.colorScheme.primary),
                const SizedBox(width: 6),
                Text('Asistan', style: tema.textTheme.labelMedium?.copyWith(color: tema.colorScheme.primary, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Text(ozet, key: const ValueKey('gun-ozet'), style: tema.textTheme.bodyMedium),
            if (yuk.kapasiteDk > 0) ...[
              const Divider(height: 20),
              _Yuk(yuk: yuk, onDevret: onDevret, onYarinaBak: onYarinaBak),
            ],
            if (gun.kaynaklar.planOkunamadi)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Beyindeki plan okunamadı; plan işleri görünmüyor olabilir.', style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.error)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Yuk extends StatelessWidget {
  const _Yuk({required this.yuk, this.onDevret, this.onYarinaBak});

  final GunYuku yuk;
  final VoidCallback? onDevret;
  final VoidCallback? onYarinaBak;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final asiyor = yuk.asimDk > 0;
    final az = !asiyor && yuk.bosDk >= yuk.kapasiteDk * GunOzetiKarti.azIsOrani;
    final renk = asiyor ? tema.colorScheme.error : (az ? tamamRengi(context) : tema.colorScheme.onSurface);
    final mesaj = asiyor
        ? '${sureMetni(yuk.asimDk)} fazla.'
        : az
            ? 'Bugün az iş var, ${sureMetni(yuk.bosDk)} boşluk.'
            : 'Sığıyor. ${sureMetni(yuk.bosDk)} boşluk kaldı.';
    final eylem = asiyor ? ('Bir kısmını devret', onDevret) : (az ? ('Yarına bak', onYarinaBak) : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Gün yükü', style: tema.textTheme.bodySmall),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${sureMetni(yuk.toplamDk)} / ${sureMetni(yuk.kapasiteDk)}',
                key: const ValueKey('gun-yuku'),
                textAlign: TextAlign.end,
                style: tema.textTheme.labelLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _Cubuk(yuk: yuk, asiyor: asiyor),
        const SizedBox(height: 2),
        // The sentence on the left, the one action at the end of the same line.
        Row(
          children: [
            Expanded(child: Text(mesaj, key: const ValueKey('gun-yuk-mesaj'), style: tema.textTheme.bodyMedium?.copyWith(color: renk))),
            if (eylem != null && eylem.$2 != null)
              TextButton(
                key: const ValueKey('gun-yuk-eylem'),
                onPressed: eylem.$2,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 40),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: renk,
                ),
                child: Text(eylem.$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
          ],
        ),
        if (yuk.tahminsizSayi > 0)
          Text('${yuk.tahminsizSayi} işin süre tahmini yok.', style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

/// The bar: the work as a filled part, the overflow in red past the thin line that marks the capacity.
class _Cubuk extends StatelessWidget {
  const _Cubuk({required this.yuk, required this.asiyor});

  final GunYuku yuk;
  final bool asiyor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final tavan = yuk.toplamDk > yuk.kapasiteDk ? yuk.toplamDk : yuk.kapasiteDk;
    final dolu = (yuk.toplamDk > yuk.kapasiteDk ? yuk.kapasiteDk : yuk.toplamDk) / tavan;
    final kapasite = yuk.kapasiteDk / tavan;
    return Semantics(
      label: 'Gün yükü ${sureMetni(yuk.toplamDk)}, kapasite ${sureMetni(yuk.kapasiteDk)}',
      child: SizedBox(
        height: 8,
        child: LayoutBuilder(
          builder: (context, kisit) {
            final g = kisit.maxWidth;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: tema.colorScheme.surface, borderRadius: BorderRadius.circular(99)),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: g * dolu,
                  child: DecoratedBox(decoration: BoxDecoration(color: tema.colorScheme.primary, borderRadius: BorderRadius.circular(99))),
                ),
                if (asiyor)
                  Positioned(
                    left: g * kapasite,
                    top: 0,
                    bottom: 0,
                    right: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: tema.colorScheme.error, borderRadius: const BorderRadius.horizontal(right: Radius.circular(99))),
                    ),
                  ),
                Positioned(left: g * kapasite - 0.5, top: -1, bottom: -1, width: 1.5, child: ColoredBox(color: tema.colorScheme.onSurface)),
              ],
            );
          },
        ),
      ),
    );
  }
}
