import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/models/enums.dart';
import '../../data/models/oge.dart';
import '../../data/repositories/kullanici_repository.dart';
import '../core/widgets.dart';
import 'raf_view_model.dart';

const rafSekmeleri = [
  (OgeDurumu.devam, 'Devam'),
  (OgeDurumu.siradaki, 'Sıradaki'),
  (OgeDurumu.bitti, 'Bitti'),
  (OgeDurumu.birakildi, 'Bırakıldı'),
];

class RafScreen extends StatelessWidget {
  const RafScreen({super.key, required this.viewModel});

  final RafViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final sahip = context.watch<KullaniciRepository>().sahip;
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final secili = viewModel.secili;
        final etiket = secili?.ogeEtiketi ?? 'öğe';
        return DefaultTabController(
          length: rafSekmeleri.length,
          child: Scaffold(
            appBar: AppBar(
              title: Text(secili == null ? 'Raf' : '${secili.ad} · Raf'),
              actions: [
                if (sahip && secili != null)
                  IconButton(
                    tooltip: 'Yeni ${etiket.toLowerCase()} ekle',
                    icon: const Icon(LucideIcons.plus),
                    onPressed: () => context.push('/raf/${secili.id}/oge-yeni'),
                  ),
              ],
              bottom: secili == null
                  ? null
                  : TabBar(tabs: [for (final (_, ad) in rafSekmeleri) Tab(text: ad)]),
            ),
            body: _govde(context, sahip),
          ),
        );
      },
    );
  }

  Widget _govde(BuildContext context, bool sahip) {
    if (viewModel.ilkYukleme) return const YuklemeIskeleti();
    if (viewModel.secili == null) {
      if (viewModel.hata != null) {
        return BosDurum(metin: viewModel.hata!, dugme: 'Tekrar dene', onPressed: viewModel.yukle);
      }
      return RefreshIndicator(
        onRefresh: viewModel.yukle,
        child: const BosDurum(ikon: LucideIcons.libraryBig, metin: 'Bu alışkanlık bulunamadı ya da Raf türünde değil.'),
      );
    }
    return OrtaGenislik(
      maxGenislik: 840,
      child: TabBarView(
        children: [
          for (final (durum, _) in rafSekmeleri) _Raf(viewModel: viewModel, durum: durum),
        ],
      ),
    );
  }
}

class _Raf extends StatelessWidget {
  const _Raf({required this.viewModel, required this.durum});

  final RafViewModel viewModel;
  final OgeDurumu durum;

  @override
  Widget build(BuildContext context) {
    final ogeler = viewModel.ogeleri(durum);
    final etiket = (viewModel.secili?.ogeEtiketi ?? 'öğe').toLowerCase();
    return RefreshIndicator(
      onRefresh: viewModel.yukle,
      child: ogeler.isEmpty
          ? BosDurum(metin: viewModel.hata ?? 'Bu rafta henüz $etiket yok.')
          : GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150,
                childAspectRatio: 0.52,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: ogeler.length,
              itemBuilder: (context, i) => _Kapak(oge: ogeler[i]),
            ),
    );
  }
}

class _Kapak extends StatelessWidget {
  const _Kapak({required this.oge});

  final Oge oge;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return InkWell(
      onTap: () => context.push('/oge/${oge.id}'),
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox.expand(child: ApiResim(dosyaId: oge.fotografId, yedekIkon: LucideIcons.bookOpen)),
            ),
          ),
          if (oge.ilerleme != null && oge.durum == OgeDurumu.devam) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(value: oge.ilerleme!.clamp(0, 1).toDouble(), minHeight: 4),
          ],
          const SizedBox(height: 6),
          Text(oge.ad, style: tema.textTheme.labelLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (oge.altBaslik != null)
            Text(oge.altBaslik!, style: tema.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
