import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/is_karti.dart';
import '../../routing/router.dart';
import '../../utils/is_bildirimi.dart';
import '../../utils/is_gorunum.dart';
import '../core/beyin_hata.dart';
import '../core/widgets.dart';
import 'asistan_pano_view_model.dart';

/// The work cards in groups: what waits on the person, what the VPS has, builds, the gates that wait for an approval and what
/// finished this week. [yazabilir] is whether the person may open cards (the Sahip); offline the button is shut and the screen says so.
class AsistanPanoScreen extends StatelessWidget {
  const AsistanPanoScreen({super.key, required this.viewModel, this.yazabilir = true});

  final AsistanPanoViewModel viewModel;
  final bool yazabilir;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final veri = viewModel.veri;
        final cevrimdisi = veri?.cevrimdisi ?? false;
        return Scaffold(
          appBar: AppBar(title: const Text('Asistan işleri')),
          floatingActionButton: yazabilir
              ? FloatingActionButton.extended(
                  // Opening a card needs the server: offline the button is shut.
                  onPressed: cevrimdisi ? null : () => context.push(Rotalar.asistanYeni),
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('Yeni kart'),
                )
              : null,
          body: veri == null
              ? (viewModel.hata != null
                  ? BeyinHataDurumu(hata: viewModel.hata!, onTekrar: viewModel.yukle)
                  : const YuklemeIskeleti(yukseklik: 72))
              : RefreshIndicator(
                  onRefresh: viewModel.yukle,
                  child: veri.pano.bos
                      ? const BosDurum(ikon: LucideIcons.bot, metin: 'Henüz iş kartı yok. Yeni kart ile bir iş aç.')
                      : OrtaGenislik(child: _Pano(pano: veri.pano, cevrimdisi: cevrimdisi)),
                ),
        );
      },
    );
  }
}

class _Pano extends StatelessWidget {
  const _Pano({required this.pano, required this.cevrimdisi});

  final IsPanosu pano;
  final bool cevrimdisi;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Room for the floating button under the last row.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        if (cevrimdisi)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Çevrimdışısın; son indirilen pano gösteriliyor. Yazma düğmeleri kapalı.',
              style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
            ),
          ),
        _Grup(baslik: 'Sende bekleyen', kartlar: pano.sende),
        _Grup(baslik: 'Onay bekleyen kapılar', kartlar: pano.kapilar),
        _Grup(baslik: "VPS'te", kartlar: pano.vps),
        _Grup(baslik: "Laptop'ta", kartlar: pano.laptop),
        _Grup(baslik: 'Yapımda', kartlar: pano.yapim),
        _Grup(baslik: 'Bu hafta biten', kartlar: pano.biten),
      ],
    );
  }
}

class _Grup extends StatelessWidget {
  const _Grup({required this.baslik, required this.kartlar});

  final String baslik;
  final List<IsKarti> kartlar;

  @override
  Widget build(BuildContext context) {
    // An empty group is not shown.
    if (kartlar.isEmpty) return const SizedBox.shrink();
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
          child: Text(
            '$baslik · ${kartlar.length}',
            style: tema.textTheme.titleSmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
        ),
        for (final k in kartlar)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                minTileHeight: 64,
                title: Text(k.baslik, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(_altSatir(k)),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => context.push(isRotasi(k.kimlik)),
              ),
            ),
          ),
      ],
    );
  }

  static String _altSatir(IsKarti k) => [
        asamaEtiketi(k.asama),
        sahipEtiketi(k.sahip),
        if (k.yer.isNotEmpty) k.yer,
        if (k.bekleyenSoru > 0) '${k.bekleyenSoru} cevapsız soru',
      ].join(' · ');
}
