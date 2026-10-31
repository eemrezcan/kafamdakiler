import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/app_theme.dart';
import '../../data/models/aliskanlik.dart';
import '../../data/models/enums.dart';
import '../../data/models/oge.dart';
import '../../utils/dogrulama.dart';
import '../core/ikonlar.dart';
import '../core/renkler.dart';
import '../core/widgets.dart';

typedef MiktarDegisti = void Function(Aliskanlik aliskanlik, double yeniMiktar);

String yuzdeMetni(double oran) => NumberFormat.percentPattern('tr').format(oran);

/// One habit on the Today tab. Chooses the layout by type.
class AliskanlikKarti extends StatelessWidget {
  const AliskanlikKarti({
    super.key,
    required this.aliskanlik,
    required this.onTik,
    required this.onMiktar,
    required this.onSayiGir,
  });

  final Aliskanlik aliskanlik;
  final VoidCallback onTik;
  final MiktarDegisti onMiktar;
  final VoidCallback onSayiGir;

  @override
  Widget build(BuildContext context) {
    final a = aliskanlik;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: switch (a) {
          Aliskanlik(tur: AliskanlikTuru.raf) => _RafIcerik(aliskanlik: a),
          Aliskanlik(olcu: Olcu.evetHayir) => _TikIcerik(aliskanlik: a, onTik: onTik),
          _ => _SayiIcerik(aliskanlik: a, onMiktar: onMiktar, onSayiGir: onSayiGir),
        },
      ),
    );
  }
}

/// Icon, name, and the small "güç / seri" line shared by all layouts.
class _Baslik extends StatelessWidget {
  const _Baslik({required this.aliskanlik, this.sonda});

  final Aliskanlik aliskanlik;
  final Widget? sonda;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final renk = aliskanlikRengi(context, aliskanlik.renk);
    final mono = KdYazi.of(context).mono.copyWith(fontSize: 12, color: tema.colorScheme.onSurfaceVariant);
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: renk.withValues(alpha: 0.16),
          child: Icon(lucideIkonu(aliskanlik.ikon), color: renk, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(aliskanlik.ad, style: tema.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                'güç ${yuzdeMetni(aliskanlik.guc)} · seri ${aliskanlik.seri}',
                style: mono,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        ?sonda,
      ],
    );
  }
}

class _TikIcerik extends StatelessWidget {
  const _TikIcerik({required this.aliskanlik, required this.onTik});

  final Aliskanlik aliskanlik;
  final VoidCallback onTik;

  @override
  Widget build(BuildContext context) {
    final yapildi = (aliskanlik.bugun?.miktar ?? 0) >= 1;
    final tema = Theme.of(context).colorScheme;
    return _Baslik(
      aliskanlik: aliskanlik,
      sonda: IconButton.filledTonal(
        tooltip: yapildi ? 'Yapıldı; geri almak için dokun' : 'Yapıldı olarak işaretle',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        style: yapildi ? IconButton.styleFrom(backgroundColor: tema.primary, foregroundColor: tema.onPrimary) : null,
        icon: Icon(yapildi ? LucideIcons.check : LucideIcons.circle),
        onPressed: onTik,
      ),
    );
  }
}

class _SayiIcerik extends StatelessWidget {
  const _SayiIcerik({required this.aliskanlik, required this.onMiktar, required this.onSayiGir});

  final Aliskanlik aliskanlik;
  final MiktarDegisti onMiktar;
  final VoidCallback onSayiGir;

  @override
  Widget build(BuildContext context) {
    final a = aliskanlik;
    final tema = Theme.of(context);
    final miktar = a.bugun?.miktar ?? 0;
    final deger = a.bugun?.deger ?? 0;
    final enCok = a.hedefYonu == HedefYonu.enCok;
    final asildi = enCok && miktar > (a.gunlukHedef ?? 0);
    final mono = KdYazi.of(context).mono;
    final birim = a.birim ?? '';
    final hedefMetni = '${enCok ? 'en çok ' : ''}${sayiMetni(a.gunlukHedef)} $birim';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Baslik(
          aliskanlik: a,
          sonda: a.dakikaliSayac
              ? IconButton(
                  tooltip: 'Kronometre',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: const Icon(LucideIcons.timer),
                  onPressed: () => context.push('/aliskanlik/${a.id}/kronometre'),
                )
              : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton.outlined(
              tooltip: 'Bir azalt',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(LucideIcons.minus),
              onPressed: miktar > 0 ? () => onMiktar(a, miktar - 1) : null,
            ),
            Expanded(
              child: InkWell(
                onTap: onSayiGir,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sayiMetni(miktar),
                          style: mono.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: asildi ? tema.colorScheme.error : null,
                          ),
                        ),
                        Text(
                          '/ $hedefMetni',
                          style: mono.copyWith(fontSize: 12, color: tema.colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            IconButton.filled(
              tooltip: 'Bir artır',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(LucideIcons.plus),
              onPressed: () => onMiktar(a, miktar + 1),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: deger.clamp(0, 1).toDouble(),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
          color: asildi ? tema.colorScheme.error : null,
        ),
      ],
    );
  }
}

class _RafIcerik extends StatelessWidget {
  const _RafIcerik({required this.aliskanlik});

  final Aliskanlik aliskanlik;

  @override
  Widget build(BuildContext context) {
    final a = aliskanlik;
    final tema = Theme.of(context);
    final mono = KdYazi.of(context).mono.copyWith(fontSize: 12, color: tema.colorScheme.onSurfaceVariant);
    final bugun = a.bugun;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Baslik(aliskanlik: a),
        if (bugun != null) ...[
          const SizedBox(height: 8),
          Text('bugün ${sayiMetni(bugun.miktar)} ${a.birim ?? ''}'
              '${a.gunlukHedef != null ? ' / ${sayiMetni(a.gunlukHedef)}' : ''}', style: mono),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: bugun.deger.clamp(0, 1).toDouble(),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
        const SizedBox(height: 12),
        if (a.devamEdenler.isEmpty)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Devam eden ${(a.ogeEtiketi ?? 'öğe').toLowerCase()} yok. Raf sekmesinden bir tane başlat.',
                  style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
                ),
              ),
              TextButton(onPressed: () => context.go('/raf'), child: const Text('Rafa git')),
            ],
          )
        else
          for (final oge in a.devamEdenler) _DevamEdenOge(oge: oge, birim: a.birim ?? ''),
      ],
    );
  }
}

class _DevamEdenOge extends StatelessWidget {
  const _DevamEdenOge({required this.oge, required this.birim});

  final OgeOzet oge;
  final String birim;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final mono = KdYazi.of(context).mono.copyWith(fontSize: 12, color: tema.colorScheme.onSurfaceVariant);
    final konum = sayiMetni(oge.guncelKonum);
    final toplam = oge.toplam != null ? ' / ${sayiMetni(oge.toplam)}' : '';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => context.push('/oge/${oge.id}'),
            borderRadius: BorderRadius.circular(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 92,
                child: ApiResim(dosyaId: dosyaIdUrlden(oge.fotografUrl), yedekIkon: LucideIcons.bookOpen),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(oge.ad, style: tema.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (oge.altBaslik != null)
                  Text(oge.altBaslik!, style: tema.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                if (oge.ilerleme != null)
                  LinearProgressIndicator(
                    value: oge.ilerleme!.clamp(0, 1).toDouble(),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                const SizedBox(height: 4),
                Text('$konum$toplam $birim', style: mono),
                const SizedBox(height: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => context.push('/oge/${oge.id}/oturum'),
                  icon: const Icon(LucideIcons.play, size: 18),
                  label: const Text('Okumaya başla'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
