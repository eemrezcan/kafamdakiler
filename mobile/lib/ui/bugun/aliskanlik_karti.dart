import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../data/models/aliskanlik.dart';
import '../../data/models/enums.dart';
import '../../data/models/gun.dart';
import '../../data/models/oge.dart';
import '../../data/repositories/kullanici_repository.dart';
import '../../utils/aliskanlik_gunu.dart';
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
    this.sonGunler,
  });

  final Aliskanlik aliskanlik;
  final VoidCallback onTik;
  final MiktarDegisti onMiktar;
  final VoidCallback onSayiGir;

  /// The last 7 days, oldest first, for the strip at the bottom; null hides it.
  final List<Gun>? sonGunler;

  @override
  Widget build(BuildContext context) {
    final a = aliskanlik;
    final renk = aliskanlikRengi(context, a.renk);
    // The chosen colour tints the card's surface and border; text keeps the theme colours (K-0022 addendum).
    return Card(
      clipBehavior: Clip.antiAlias,
      color: kartZemini(context, renk),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: kartCercevesi(context, renk)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            switch (a) {
              Aliskanlik(tur: AliskanlikTuru.raf) => _RafIcerik(aliskanlik: a),
              Aliskanlik(olcu: Olcu.evetHayir) => _TikIcerik(aliskanlik: a, onTik: onTik),
              _ => _SayiIcerik(aliskanlik: a, onMiktar: onMiktar, onSayiGir: onSayiGir),
            },
            if (sonGunler case final gunler? when gunler.isNotEmpty) _GunSeridi(aliskanlik: a, gunler: gunler, renk: renk),
          ],
        ),
      ),
    );
  }
}

/// The last 7 days as dots with short day names, like the web card's footer
/// (`.kd-strip`): full = goal reached, half = partly, ring = missed, faint ring
/// = not planned or before the habit existed. Today comes from the card's own
/// value, so a tap shows at once, before the server answers.
class _GunSeridi extends StatelessWidget {
  const _GunSeridi({required this.aliskanlik, required this.gunler, required this.renk});

  final Aliskanlik aliskanlik;
  final List<Gun> gunler;
  final Color renk;

  static const _kisaAdlar = ['PZT', 'SAL', 'ÇAR', 'PER', 'CUM', 'CMT', 'PAZ'];

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ilkGun = aliskanlikGunu(aliskanlik.olusturulma);
    final bugun = aliskanlik.bugun;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: tema.colorScheme.outlineVariant))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final g in gunler.take(7))
            Builder(builder: (context) {
              final bugunMu = bugun != null && DateUtils.isSameDay(g.tarih, bugun.tarih);
              final deger = bugunMu ? bugun.deger : g.deger;
              final planli = bugunMu ? bugun.planli : g.planli;
              final durum = g.tarih.isBefore(ilkGun) || !planli
                  ? _Nokta.yok
                  : deger >= 1
                      ? _Nokta.tamam
                      : deger > 0
                          ? _Nokta.kismen
                          : _Nokta.yapilmadi;
              return Tooltip(
                message: '${DateFormat('d MMMM', 'tr').format(g.tarih)}: ${sayiMetni(bugunMu ? bugun.miktar : g.miktar)} ${aliskanlik.birim ?? ''}',
                child: Column(
                  children: [
                    _NoktaCiz(durum: durum, renk: renk),
                    const SizedBox(height: 4),
                    Text(
                      _kisaAdlar[g.tarih.weekday - 1],
                      style: tema.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        letterSpacing: 0.5,
                        fontWeight: bugunMu ? FontWeight.w700 : FontWeight.w500,
                        color: bugunMu ? tema.colorScheme.onSurface : tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

enum _Nokta { tamam, kismen, yapilmadi, yok }

class _NoktaCiz extends StatelessWidget {
  const _NoktaCiz({required this.durum, required this.renk});

  final _Nokta durum;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).colorScheme;
    final (dolgu, cerceve) = switch (durum) {
      _Nokta.tamam => (renk, renk),
      _Nokta.kismen => (null, renk),
      _Nokta.yapilmadi => (null, tema.outline),
      _Nokta.yok => (null, tema.outlineVariant),
    };
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dolgu,
        border: Border.all(color: cerceve, width: 1.5),
        // Half-filled from the left for a partly done day.
        gradient: durum == _Nokta.kismen
            ? LinearGradient(colors: [renk, renk, Colors.transparent, Colors.transparent], stops: const [0, 0.5, 0.5, 1])
            : null,
      ),
    );
  }
}

/// "Her gün", "Haftada 3 gün" or "Pzt, Cum", as on the web card.
String siklikMetni(Aliskanlik a) => switch (a.siklik) {
      Siklik.herGun => 'Her gün',
      Siklik.haftadaN => 'Haftada ${a.haftalikSayi} gün',
      Siklik.belirliGunler => (a.gunler ?? const <HaftaGunu>[])
          .map((g) => '${g.name[0].toUpperCase()}${g.name.substring(1)}')
          .join(', '),
    };

/// The card's progress bar: the habit colour, green once the goal is reached,
/// red when a limit is passed (web `.kd-bar`, `is-ok`, `is-over`).
class _Cubuk extends StatelessWidget {
  const _Cubuk({required this.oran, required this.renk, this.asildi = false});

  final double oran;
  final Color renk;
  final bool asildi;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return LinearProgressIndicator(
      value: oran.clamp(0, 1).toDouble(),
      minHeight: 8,
      borderRadius: BorderRadius.circular(4),
      color: asildi
          ? tema.colorScheme.error
          : oran >= 1
              ? tamamRengi(context)
              : renk,
    );
  }
}

/// Icon, name (opens the detail), "Her gün · Güç %5 · Seri 1" and the edit
/// pencil for the Sahip, like the web card's header.
class _Baslik extends StatelessWidget {
  const _Baslik({required this.aliskanlik, this.sonda});

  final Aliskanlik aliskanlik;
  final Widget? sonda;

  @override
  Widget build(BuildContext context) {
    final a = aliskanlik;
    final tema = Theme.of(context);
    final renk = aliskanlikRengi(context, a.renk);
    final rakam = KdYazi.of(context).sayi.copyWith(fontSize: 12, color: tema.colorScheme.onSurfaceVariant);
    // Nullable lookup: widget tests render the card without the user repository.
    final sahip = context.watch<KullaniciRepository?>()?.sahip ?? false;
    final seri = a.seri > 0 ? ' · Seri ${a.seri}' : '';
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: renk.withValues(alpha: 0.16),
          child: Icon(lucideIkonu(a.ikon), color: renk, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () => context.push('/aliskanlik/${a.id}'),
            borderRadius: BorderRadius.circular(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.ad,
                  style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${siklikMetni(a)} · Güç ${yuzdeMetni(a.guc)}$seri',
                  style: rakam,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        ?sonda,
        if (sahip)
          IconButton(
            tooltip: '${a.ad} alışkanlığını düzenle',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(LucideIcons.pencil, size: 20, color: tema.colorScheme.onSurfaceVariant),
            onPressed: () => context.push('/aliskanlik/${a.id}/duzenle'),
          ),
      ],
    );
  }
}

/// Yes/no habit: one full-width button in the habit colour, filled once done
/// (web `.kd-tick`).
class _TikIcerik extends StatelessWidget {
  const _TikIcerik({required this.aliskanlik, required this.onTik});

  final Aliskanlik aliskanlik;
  final VoidCallback onTik;

  @override
  Widget build(BuildContext context) {
    final yapildi = (aliskanlik.bugun?.miktar ?? 0) >= 1;
    final renk = aliskanlikRengi(context, aliskanlik.renk);
    final tema = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Baslik(aliskanlik: aliskanlik),
        const SizedBox(height: 12),
        Tooltip(
          message: yapildi ? 'Yapıldı; geri almak için dokun' : 'Yapıldı olarak işaretle',
          child: yapildi
              ? FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: renk, foregroundColor: tema.onPrimary),
                  onPressed: onTik,
                  icon: const Icon(LucideIcons.check, size: 20),
                  label: const Text('Yapıldı · geri al'),
                )
              : OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: renk, side: BorderSide(color: renk)),
                  onPressed: onTik,
                  icon: const Icon(LucideIcons.check, size: 20),
                  label: const Text('Yaptım'),
                ),
        ),
      ],
    );
  }
}

/// Counter habit: bar and "6 / 8 bardak", then − [today's amount] +, square
/// controls as on the web (`.kd-step-btn`); + is filled with the habit colour.
class _SayiIcerik extends StatelessWidget {
  const _SayiIcerik({required this.aliskanlik, required this.onMiktar, required this.onSayiGir});

  final Aliskanlik aliskanlik;
  final MiktarDegisti onMiktar;
  final VoidCallback onSayiGir;

  @override
  Widget build(BuildContext context) {
    final a = aliskanlik;
    final tema = Theme.of(context);
    final renk = aliskanlikRengi(context, a.renk);
    final miktar = a.bugun?.miktar ?? 0;
    final deger = a.bugun?.deger ?? 0;
    final enCok = a.hedefYonu == HedefYonu.enCok;
    final asildi = enCok && miktar > (a.gunlukHedef ?? 0);
    final rakam = KdYazi.of(context).sayi;
    final birim = a.birim ?? '';
    final hedefMetni = '${enCok ? 'en çok ' : ''}${sayiMetni(a.gunlukHedef)} $birim';
    final cizgi = tema.inputDecorationTheme.enabledBorder?.borderSide.color ?? tema.colorScheme.outline;
    const kare = Size(48, 48);

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
        _Cubuk(oran: deger, renk: renk, asildi: asildi),
        const SizedBox(height: 6),
        Text(
          '${sayiMetni(miktar)} / $hedefMetni',
          style: rakam.copyWith(fontSize: 13, color: asildi ? tema.colorScheme.error : null),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton.outlined(
              tooltip: 'Bir azalt',
              style: IconButton.styleFrom(minimumSize: kare, side: BorderSide(color: cizgi)),
              icon: const Icon(LucideIcons.minus),
              onPressed: miktar > 0 ? () => onMiktar(a, miktar - 1) : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Bugünkü miktarı yaz',
                child: InkWell(
                  onTap: onSayiGir,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tema.inputDecorationTheme.fillColor,
                      border: Border.all(color: cizgi),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      sayiMetni(miktar),
                      style: rakam.copyWith(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Bir artır',
              style: IconButton.styleFrom(minimumSize: kare, backgroundColor: renk, foregroundColor: tema.colorScheme.onPrimary),
              icon: const Icon(LucideIcons.plus),
              onPressed: () => onMiktar(a, miktar + 1),
            ),
          ],
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
    final rakam = KdYazi.of(context).sayi.copyWith(fontSize: 12, color: tema.colorScheme.onSurfaceVariant);
    final renk = aliskanlikRengi(context, a.renk);
    final bugun = a.bugun;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Baslik(aliskanlik: a),
        if (bugun != null) ...[
          const SizedBox(height: 12),
          _Cubuk(oran: bugun.deger, renk: renk),
          const SizedBox(height: 6),
          Text(
            '${sayiMetni(bugun.miktar)}${a.gunlukHedef != null ? ' / ${sayiMetni(a.gunlukHedef)}' : ''} ${a.birim ?? ''}',
            style: rakam.copyWith(fontSize: 13, color: tema.colorScheme.onSurface),
          ),
        ],
        const SizedBox(height: 12),
        if (a.devamEdenler.isEmpty)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Devam eden ${(a.ogeEtiketi ?? 'öğe').toLowerCase()} yok.',
                  style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
                ),
              ),
              OutlinedButton(onPressed: () => context.push('/aliskanlik/${a.id}/raf'), child: const Text('Rafa git')),
            ],
          )
        else if (a.devamEdenler.length == 1)
          _DevamEdenOge(oge: a.devamEdenler.first, birim: a.birim ?? '', renk: renk)
        else
          _DevamEdenSecici(aliskanlik: a, renk: renk),
      ],
    );
  }
}

/// Several items in progress: a row of small covers to pick from, and the
/// chosen item below. The API sends the most recently read item first, so the
/// card opens on it. More than [_enCokKapak] items: the rest are on the shelf tab.
class _DevamEdenSecici extends StatefulWidget {
  const _DevamEdenSecici({required this.aliskanlik, required this.renk});

  final Aliskanlik aliskanlik;
  final Color renk;

  @override
  State<_DevamEdenSecici> createState() => _DevamEdenSeciciState();
}

const _enCokKapak = 5;

class _DevamEdenSeciciState extends State<_DevamEdenSecici> {
  String? _seciliId;

  @override
  Widget build(BuildContext context) {
    final a = widget.aliskanlik;
    final tema = Theme.of(context);
    final gorunen = a.devamEdenler.take(_enCokKapak).toList();
    final kalan = a.devamEdenler.length - gorunen.length;
    // The chosen item may have left the list (finished elsewhere): fall back to the first.
    final secili = gorunen.firstWhere((o) => o.id == _seciliId, orElse: () => gorunen.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in gorunen)
              Semantics(
                label: o.ad,
                selected: o.id == secili.id,
                button: true,
                child: Tooltip(
                  message: o.ad,
                  child: InkWell(
                    onTap: () => setState(() => _seciliId = o.id),
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: o.id == secili.id ? 1 : 0.55,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: o.id == secili.id ? widget.renk : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: SizedBox(
                            width: 40,
                            height: 56,
                            child: ApiResim(dosyaId: dosyaIdUrlden(o.fotografUrl), yedekIkon: lucideIkonu(a.ikon)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (kalan > 0)
              Semantics(
                label: '$kalan tane daha, rafa git',
                button: true,
                child: InkWell(
                  onTap: () => context.push('/aliskanlik/${a.id}/raf'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 44,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tema.colorScheme.outline),
                    ),
                    child: Text('+$kalan', style: TextStyle(color: tema.colorScheme.onSurfaceVariant)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _DevamEdenOge(oge: secili, birim: a.birim ?? '', renk: widget.renk, kapakGoster: false),
      ],
    );
  }
}

class _DevamEdenOge extends StatelessWidget {
  const _DevamEdenOge({required this.oge, required this.birim, required this.renk, this.kapakGoster = true});

  final OgeOzet oge;
  final String birim;
  final Color renk;

  /// False when the cover is already shown in the picker row above.
  final bool kapakGoster;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final rakam = KdYazi.of(context).sayi.copyWith(fontSize: 12, color: tema.colorScheme.onSurfaceVariant);
    final konum = sayiMetni(oge.guncelKonum);
    final toplam = oge.toplam != null ? ' / ${sayiMetni(oge.toplam)}' : '';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kapakGoster) ...[
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
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => context.push('/oge/${oge.id}'),
                  child: Text(oge.ad, style: tema.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                if (oge.altBaslik != null)
                  Text(oge.altBaslik!, style: tema.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                if (oge.ilerleme != null)
                  LinearProgressIndicator(
                    value: oge.ilerleme!.clamp(0, 1).toDouble(),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                    color: renk,
                  ),
                const SizedBox(height: 4),
                Text('$konum$toplam $birim', style: rakam),
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
