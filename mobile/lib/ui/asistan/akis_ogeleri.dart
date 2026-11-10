import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/asistan.dart';
import '../../data/models/brifing.dart';
import '../../data/models/eylem.dart';
import '../../data/models/is_karti.dart';
import '../../data/models/yakalama.dart';
import '../../utils/hatirlatici_hesap.dart';
import '../../utils/is_gorunum.dart';
import '../../utils/metin.dart';
import '../brifing/brifing_gorunum.dart';
import '../core/renkler.dart';
import '../core/widgets.dart';
import 'asistan_view_model.dart';

/// "14:00" in Istanbul time, under an item of the feed.
String akisSaati(DateTime zaman) => istanbulSaati(zaman).kisa;

/// A card of the feed: white-ish surface, a coloured edge on the left that says what kind it is (green: done, orange: asks,
/// accent: a work card).
class _Kart extends StatelessWidget {
  const _Kart({required this.renk, required this.child, this.onTap});

  final Color renk;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.92,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(border: Border(left: BorderSide(color: renk, width: 4))),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: DefaultTextStyle.merge(style: tema.textTheme.bodyMedium, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _Etiket extends StatelessWidget {
  const _Etiket(this.metin, this.renk);

  final String metin;
  final Color renk;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          trBuyuk(metin),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: renk, fontWeight: FontWeight.w700, letterSpacing: 0.6),
        ),
      );
}

class _Saat extends StatelessWidget {
  const _Saat(this.zaman);

  final DateTime zaman;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(akisSaati(zaman), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

/// The person's own message: a bubble on the right, with its photo, "gönderilecek" while it waits on the phone, and the
/// server's reason when it refused it.
class KullaniciBalonu extends StatelessWidget {
  const KullaniciBalonu({super.key, required this.oge, this.onSil});

  final AkisOgesi oge;

  /// Takes a refused input off the feed.
  final VoidCallback? onSil;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final yerel = oge.yerelFotograf;
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.84,
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: tema.colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (yerel != null || oge.fotografUrl != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: oge.metin == null ? 0 : 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 160,
                          height: 120,
                          child: yerel != null && File(yerel).existsSync()
                              ? Image.file(File(yerel), fit: BoxFit.cover)
                              : ApiResim(dosyaId: dosyaIdUrlden(oge.fotografUrl)),
                        ),
                      ),
                    ),
                  if (oge.metin != null) Text(oge.metin!, style: TextStyle(color: tema.colorScheme.onPrimary)),
                ],
              ),
            ),
            if (oge.bekliyor)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.clock, size: 12, color: tema.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('gönderilecek', key: const ValueKey('akis-gonderilecek'), style: tema.textTheme.labelSmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
                  ],
                ),
              )
            else if (oge.gonderilemedi != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text('Gönderilemedi: ${oge.gonderilemedi}', style: tema.textTheme.labelSmall?.copyWith(color: tema.colorScheme.error)),
                    ),
                    if (onSil != null)
                      TextButton(
                        key: const ValueKey('akis-girdi-sil'),
                        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                        onPressed: onSil,
                        child: const Text('Sil'),
                      ),
                  ],
                ),
              )
            else
              _Saat(oge.zaman),
          ],
        ),
      ),
    );
  }
}

/// What the assistant did for an input: one row per result, each with its own "Geri al" and "Düzelt".
class SonucKarti extends StatelessWidget {
  const SonucKarti({super.key, required this.oge, required this.viewModel, this.yazabilir = true});

  final AkisOgesi oge;
  final AsistanViewModel viewModel;

  /// False hides the approval buttons of a result that waits (the account may not decide).
  final bool yazabilir;

  /// Where "Düzelt" goes: the route the result names; a capture opens its edit page.
  static String? duzeltRotasi(AsistanSonucu s) {
    if (s.onayda) return null; // nothing was made yet; there is nothing to fix
    if (s.hedefRota != null && s.hedefRota!.startsWith('/') && !s.hedefRota!.contains('://')) return s.hedefRota;
    if (s.tur == sonucTuruNot && s.hedefKimlik != null) return '/yakalama/${Uri.encodeComponent(s.hedefKimlik!)}/duzenle';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final tamam = tamamRengi(context);
    final sorunlu = oge.sonuclar.any((s) => s.sorunlu);
    // What waits for approval is not a failure: the label says so and the card is not red.
    final onayda = !sorunlu && oge.sonuclar.any((s) => s.onayda);
    final renk = sorunlu ? tema.colorScheme.error : (onayda ? tema.colorScheme.secondary : tamam);
    return _Kart(
      renk: renk,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Etiket(sorunlu ? 'Yapamadım' : (onayda ? 'Onayını bekliyor' : '✓ Yaptım'), renk),
          for (final s in oge.sonuclar)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.baslik, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (s.ozet.isNotEmpty) Text(s.ozet, style: TextStyle(color: tema.colorScheme.onSurfaceVariant)),
                  if (s.mesaj != null) Text(s.mesaj!, style: TextStyle(color: s.sorunlu ? tema.colorScheme.error : tema.colorScheme.onSurfaceVariant)),
                  if (yazabilir && s.onayda && s.eylemId != null)
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          key: ValueKey('sonuc-onay-uygula-${s.eylemId}'),
                          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                          onPressed: () => viewModel.sonucuOnayla(s),
                          child: const Text('Ekle'),
                        ),
                        OutlinedButton(
                          key: ValueKey('sonuc-onay-gec-${s.eylemId}'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                          onPressed: () => viewModel.sonucuGec(s),
                          child: const Text('Geç'),
                        ),
                      ],
                    ),
                  if (s.durum == SonucDurumu.izinYok) Text('Bu işe iznin yok.', style: TextStyle(color: tema.colorScheme.error)),
                  if (s.geriAlinabilir || duzeltRotasi(s) != null)
                    Wrap(
                      spacing: 8,
                      children: [
                        if (s.geriAlinabilir)
                          OutlinedButton(
                            key: ValueKey('sonuc-geri-al-${s.eylemId ?? s.hedefKimlik}'),
                            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                            onPressed: () => viewModel.geriAl(s),
                            child: const Text('Geri al'),
                          ),
                        if (duzeltRotasi(s) case final rota?)
                          OutlinedButton(
                            key: ValueKey('sonuc-duzelt-${s.eylemId ?? s.hedefKimlik}'),
                            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                            onPressed: () => rotayaGitAkis(context, rota),
                            child: const Text('Düzelt'),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          _Saat(oge.zaman),
        ],
      ),
    );
  }
}

/// Opens [rota] from a feed item: a tab is switched to (`/gun/{tarih}` is Takvim on that day), a page is put on top.
void rotayaGitAkis(BuildContext context, String rota) {
  const sekmeler = ['/', '/takvim', '/asistan', '/aliskanliklar', '/beyin'];
  if (sekmeler.contains(rota) || rota.startsWith('/gun/')) {
    context.go(rota);
  } else {
    context.push(rota);
  }
}

/// The one question the assistant asks when it is not sure: at most three short answers as buttons.
class SoruKarti extends StatelessWidget {
  const SoruKarti({super.key, required this.oge, required this.viewModel, this.yazabilir = true});

  final AkisOgesi oge;
  final AsistanViewModel viewModel;
  final bool yazabilir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soru = oge.soru!;
    return _Kart(
      renk: tema.colorScheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Etiket('Bir soru', tema.colorScheme.secondary),
          Text(soru.metin),
          if (yazabilir && soru.secenekler.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < soru.secenekler.length; i++)
                    i == 0
                        ? FilledButton(
                            key: ValueKey('soru-cevap-$i'),
                            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                            onPressed: () => viewModel.cevapla(soru, soru.secenekler[i]),
                            child: Text(soru.secenekler[i]),
                          )
                        : OutlinedButton(
                            key: ValueKey('soru-cevap-$i'),
                            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                            onPressed: () => viewModel.cevapla(soru, soru.secenekler[i]),
                            child: Text(soru.secenekler[i]),
                          ),
                ],
              ),
            ),
          _Saat(oge.zaman),
        ],
      ),
    );
  }
}

/// An action waiting for the person's approval (from outside, or in "sor" mode): what it would do, and "Uygula" / "Reddet".
class OnayKarti extends StatelessWidget {
  const OnayKarti({super.key, required this.oge, required this.viewModel, this.yazabilir = true});

  final AkisOgesi oge;
  final AsistanViewModel viewModel;
  final bool yazabilir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final Eylem e = oge.eylem!;
    return _Kart(
      renk: tema.colorScheme.secondary,
      onTap: () => context.push('/eylem/${Uri.encodeComponent(e.id)}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Etiket(e.disKaynak ? 'Onayını bekliyor · dış kaynak' : 'Onayını bekliyor', tema.colorScheme.secondary),
          Text(e.ozet),
          if (e.gerekce != null && e.gerekce!.isNotEmpty)
            Text(e.gerekce!, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
          if (yazabilir)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilledButton(
                    key: ValueKey('onay-uygula-${e.id}'),
                    style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                    onPressed: () => viewModel.onayla(e),
                    child: const Text('Ekle'),
                  ),
                  OutlinedButton(
                    key: ValueKey('onay-reddet-${e.id}'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                    onPressed: () => viewModel.reddet(e),
                    child: const Text('Geç'),
                  ),
                ],
              ),
            ),
          _Saat(oge.zaman),
        ],
      ),
    );
  }
}

/// A work card in the feed: its stage and who holds it; a tap opens the card.
class IsKartiOgesi extends StatelessWidget {
  const IsKartiOgesi({super.key, required this.oge});

  final AkisOgesi oge;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final IsKarti k = oge.isKarti!;
    final bitti = k.asama == 'bitti';
    final renk = bitti ? tamamRengi(context) : tema.colorScheme.primary;
    return _Kart(
      renk: renk,
      onTap: () => context.push('/asistan/${Uri.encodeComponent(k.kimlik)}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Etiket('İş · ${bitti ? 'bitti' : sahipEtiketi(k.sahip)}', renk),
          Text(k.baslik, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
            [if (k.yer.isNotEmpty) k.yer, k.tip, asamaEtiketi(k.asama), if (k.bekleyenSoru > 0) '${k.bekleyenSoru} cevapsız soru'].join(' · '),
            style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
          _Saat(oge.zaman),
        ],
      ),
    );
  }
}

/// A capture the assistant filed as a note: what it says, where it went, "Geri al" while it still waits and "Başka yere".
class NotKarti extends StatelessWidget {
  const NotKarti({super.key, required this.oge, required this.viewModel, this.yazabilir = true});

  final AkisOgesi oge;
  final AsistanViewModel viewModel;
  final bool yazabilir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final Yakalama y = oge.yakalama!;
    final renk = tamamRengi(context);
    final bekliyor = y.durum == YakalamaDurumu.bekliyor;
    return _Kart(
      renk: renk,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Etiket(bekliyor ? '✓ Not olarak kaydettim' : '✓ Beyne gitti', renk),
          if (y.fotografUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(width: 120, height: 90, child: ApiResim(dosyaId: dosyaIdUrlden(y.fotografUrl))),
              ),
            ),
          if (y.metin != null && y.metin!.isNotEmpty) Text(y.metin!, maxLines: 4, overflow: TextOverflow.ellipsis),
          if (y.hedef != null) Text(y.hedef!, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
          if (yazabilir && bekliyor)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton(
                    key: ValueKey('not-geri-al-${y.id}'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                    onPressed: () => viewModel.geriAl(AsistanSonucu(tur: sonucTuruNot, baslik: y.metin ?? '', hedefKimlik: y.id, geriAlinabilir: true)),
                    child: const Text('Geri al'),
                  ),
                  OutlinedButton(
                    key: ValueKey('not-baska-${y.id}'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                    onPressed: () => context.push('/yakalama/${Uri.encodeComponent(y.id)}/duzenle'),
                    child: const Text('Başka yere'),
                  ),
                ],
              ),
            ),
          _Saat(oge.zaman),
        ],
      ),
    );
  }
}

/// The morning briefing in the feed: its cards, a thumb on each (a vote goes to the server and needs a connection).
class BrifingOgesi extends StatelessWidget {
  const BrifingOgesi({super.key, required this.oge, required this.viewModel, this.yazabilir = true});

  final AkisOgesi oge;
  final AsistanViewModel viewModel;
  final bool yazabilir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final b = oge.brifing;
    final kartlar = b == null ? const <BrifingKarti>[] : brifingKartlari(b);
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.92,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: tema.colorScheme.surface,
            border: Border.all(color: tema.colorScheme.outlineVariant),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Etiket('✦ Sabah özeti', tema.colorScheme.primary),
              if (oge.metin != null && oge.metin!.isNotEmpty) Text(oge.metin!),
              for (final k in kartlar)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(brifingTurIkonu(k.tur), size: 16, color: tema.colorScheme.primary),
                          const SizedBox(width: 6),
                          Expanded(child: Text(k.baslik, style: const TextStyle(fontWeight: FontWeight.w600))),
                        ],
                      ),
                      Text(k.metin),
                      if (yazabilir)
                        Row(
                          children: [
                            IconButton(
                              key: ValueKey('brifing-oy-up-${k.sira}'),
                              tooltip: 'Beğendim',
                              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                              isSelected: k.oy == 1,
                              icon: const Icon(LucideIcons.thumbsUp, size: 18),
                              selectedIcon: Icon(LucideIcons.thumbsUp, size: 18, color: tema.colorScheme.primary),
                              onPressed: () => viewModel.oyVer(oge, k, 1),
                            ),
                            IconButton(
                              key: ValueKey('brifing-oy-down-${k.sira}'),
                              tooltip: 'Beğenmedim',
                              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                              isSelected: k.oy == -1,
                              icon: const Icon(LucideIcons.thumbsDown, size: 18),
                              selectedIcon: Icon(LucideIcons.thumbsDown, size: 18, color: tema.colorScheme.primary),
                              onPressed: () => viewModel.oyVer(oge, k, -1),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              _Saat(oge.zaman),
            ],
          ),
        ),
      ),
    );
  }
}
