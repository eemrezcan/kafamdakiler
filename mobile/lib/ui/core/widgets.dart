import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/aliskanlik_repository.dart';

/// Centres content with a sensible maximum width, so wide screens (tablet,
/// landscape) do not stretch lists and forms (M09).
class OrtaGenislik extends StatelessWidget {
  const OrtaGenislik({super.key, required this.child, this.maxGenislik = 640});

  final Widget child;
  final double maxGenislik;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxGenislik), child: child),
      );
}

/// The height of the floating "Yakala" button (an extended FAB) and the gap it keeps from the bottom bar.
const double yakalaDugmesiYuksekligi = 56;
const double yakalaDugmesiAraligi = 16;

/// Space under the last row of a scrolling screen so the floating "Yakala" button never covers it: the button's height,
/// its own gap from the bar, and 16 dp of air. Every list uses [listeKenarlari] instead of a number of its own.
const double yakalaAltBosluk = yakalaDugmesiYuksekligi + yakalaDugmesiAraligi + 16;

/// The padding of a scrolling screen: 16 dp at the sides, [ust] on top and [yakalaAltBosluk] at the bottom.
EdgeInsets listeKenarlari({double ust = 16}) => EdgeInsets.fromLTRB(16, ust, 16, yakalaAltBosluk);

/// Inner padding of a card and the gap between two cards, so the cards of every screen share one measure.
const kartIcBosluk = EdgeInsets.fromLTRB(16, 12, 16, 12);
const double kartAraligi = 16;

/// The title of a card or of a section on a card ("Gün planı", "Bugünün alışkanlıkları").
class KartBasligi extends StatelessWidget {
  const KartBasligi(this.metin, {super.key});

  final String metin;

  @override
  Widget build(BuildContext context) =>
      Text(metin, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600));
}

/// An empty state that lives inside a list, as a card: a sentence, and when [onTap] is given the whole card is a button.
class BosKart extends StatelessWidget {
  const BosKart({super.key, required this.metin, this.onTap, this.ikon});

  final String metin;
  final VoidCallback? onTap;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final renk = onTap == null ? tema.colorScheme.onSurfaceVariant : tema.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: kartAraligi),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: kartIcBosluk,
              child: Row(
                children: [
                  if (ikon != null) ...[Icon(ikon, size: 20, color: renk), const SizedBox(width: 12)],
                  Expanded(child: Text(metin, style: TextStyle(color: renk))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty and error states: a message and an optional action. Scrollable, so
/// pull-to-refresh also works on top of it.
class BosDurum extends StatelessWidget {
  const BosDurum({super.key, required this.metin, this.dugme, this.onPressed, this.ikon});

  final String metin;
  final String? dugme;
  final VoidCallback? onPressed;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme.onSurfaceVariant;
    return LayoutBuilder(
      builder: (context, kisit) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: kisit.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ikon != null) ...[Icon(ikon, size: 40, color: renk), const SizedBox(height: 12)],
                  Text(metin, textAlign: TextAlign.center, style: TextStyle(color: renk)),
                  if (dugme != null) ...[
                    const SizedBox(height: 16),
                    FilledButton(onPressed: onPressed, child: Text(dugme!)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grey placeholder cards shown while a list loads, so the screen does not jump.
class YuklemeIskeleti extends StatelessWidget {
  const YuklemeIskeleti({super.key, this.adet = 4, this.yukseklik = 88});

  final int adet;
  final double yukseklik;

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme.outlineVariant;
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: adet,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Container(
        height: yukseklik,
        decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// `/api/dosyalar/{id}` -> `{id}` (list summaries only carry the URL).
String? dosyaIdUrlden(String? url) {
  if (url == null || url.isEmpty) return null;
  final parcalar = url.split('/').where((p) => p.isNotEmpty);
  return parcalar.isEmpty ? null : parcalar.last;
}

/// A photo loaded through the API with the bearer token (the endpoint is not
/// public). Shows an icon when there is no photo or it cannot be loaded.
class ApiResim extends StatelessWidget {
  const ApiResim({super.key, required this.dosyaId, this.yedekIkon = LucideIcons.image, this.fit = BoxFit.cover});

  final String? dosyaId;
  final IconData yedekIkon;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).colorScheme;
    Widget yedek() => ColoredBox(
          color: tema.outlineVariant,
          child: Center(child: Icon(yedekIkon, color: tema.onSurfaceVariant)),
        );
    final id = dosyaId;
    if (id == null) return yedek();
    return FutureBuilder(
      future: context.read<AliskanlikRepository>().resim(id),
      builder: (context, anlik) {
        if (anlik.hasData) {
          return Image.memory(anlik.data!, fit: fit, gaplessPlayback: true, errorBuilder: (_, _, _) => yedek());
        }
        return yedek();
      },
    );
  }
}
