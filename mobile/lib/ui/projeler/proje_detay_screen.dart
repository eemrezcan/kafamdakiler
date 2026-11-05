import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/beyin.dart';
import '../core/beyin_gorunum.dart';
import '../core/beyin_hata.dart';
import '../core/widgets.dart';
import 'proje_view_model.dart';

class ProjeDetayScreen extends StatelessWidget {
  const ProjeDetayScreen({super.key, required this.viewModel});

  final ProjeDetayViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final proje = viewModel.veri;
        return Scaffold(
          appBar: AppBar(title: Text(proje?.baslik ?? 'Proje')),
          body: proje == null
              ? (viewModel.hata != null
                  ? BeyinHataDurumu(hata: viewModel.hata!, onTekrar: viewModel.yukle)
                  : const YuklemeIskeleti(adet: 3, yukseklik: 96))
              : RefreshIndicator(
                  onRefresh: viewModel.yukle,
                  child: OrtaGenislik(child: _Icerik(proje: proje)),
                ),
        );
      },
    );
  }
}

class _Icerik extends StatelessWidget {
  const _Icerik({required this.proje});

  final ProjeDetay proje;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        const BolumBasligi('Durum', ustBosluk: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(proje.durum ?? 'Durum yazılmamış.', style: proje.durum == null ? TextStyle(color: soluk) : null),
          ),
        ),
        const BolumBasligi('Sıradaki adım'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.arrowRight, size: 18, color: tema.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    proje.siradakiAdim ?? 'Sıradaki adım yazılmamış.',
                    style: proje.siradakiAdim == null ? TextStyle(color: soluk) : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        const BolumBasligi('Açık görevler'),
        if (proje.acikGorevler.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('Açık görev yok.', style: TextStyle(color: soluk)))
        else
          for (final g in proje.acikGorevler)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: _Gorev(g)),
        const BolumBasligi('Son günlük'),
        if (proje.sonGunluk.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('Günlük satırı yok.', style: TextStyle(color: soluk)))
        else
          Card(
            child: Column(
              // Stretch: a short row must not shrink and drift to the middle of the card.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < proje.sonGunluk.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _GunlukSatiri(proje.sonGunluk[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Gorev extends StatelessWidget {
  const _Gorev(this.gorev);

  final ProjeGorev gorev;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    final bilgi = [
      gorevDurumuMetni(gorev.durum),
      if (gorev.bitis != null) 'Bitiş ${kisaTarih(gorev.bitis!)}',
      oncelikMetni(gorev.oncelik),
    ].where((s) => s.isNotEmpty).join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gorev.baslik, style: tema.textTheme.bodyLarge),
            if (bilgi.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(bilgi, style: TextStyle(fontSize: 12, color: soluk)),
            ],
            if (gorev.sonrakiAdim != null) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.arrowRight, size: 14, color: tema.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(child: Text(gorev.sonrakiAdim!, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GunlukSatiri extends StatelessWidget {
  const _GunlukSatiri(this.satir);

  final GunlukSatiri satir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (satir.zaman != null)
            Text(satir.zaman!, style: TextStyle(fontSize: 12, color: tema.colorScheme.onSurfaceVariant)),
          if (satir.baslik != null) Text(satir.baslik!, style: tema.textTheme.bodyLarge),
          if (satir.metin != null && satir.metin!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(satir.metin!),
          ],
        ],
      ),
    );
  }
}
