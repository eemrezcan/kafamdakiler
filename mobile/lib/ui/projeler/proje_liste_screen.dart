import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/beyin_hata.dart';
import '../core/widgets.dart';
import 'proje_view_model.dart';

class ProjeListeScreen extends StatelessWidget {
  const ProjeListeScreen({super.key, required this.viewModel});

  final ProjeListeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Projeler')),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final sonuc = viewModel.veri;
          if (sonuc == null) {
            final hata = viewModel.hata;
            if (hata != null) return BeyinHataDurumu(hata: hata, onTekrar: viewModel.yukle);
            return const YuklemeIskeleti(yukseklik: 72);
          }
          final liste = sonuc.liste;
          // Offline with nothing kept on the phone: say why the list is empty.
          if (sonuc.cevrimdisi && liste.isEmpty) {
            return BeyinHataDurumu(hata: BeyinHatasi.cevrimdisi, onTekrar: viewModel.yukle);
          }
          return RefreshIndicator(
            onRefresh: viewModel.yukle,
            child: liste.isEmpty
                ? const BosDurum(ikon: LucideIcons.folder, metin: 'Beyinde henüz proje yok.')
                : OrtaGenislik(
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      // Room for the floating "Yakala" button under the last row.
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      children: [
                        if (sonuc.cevrimdisi)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Çevrimdışısın; telefondaki liste gösteriliyor. Ayrıntı için internet gerekir.',
                              style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        for (final p in liste)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                minTileHeight: 64,
                                leading: const Icon(LucideIcons.folder),
                                title: Text(p.baslik),
                                subtitle: Text(p.kimlik),
                                trailing: const Icon(LucideIcons.chevronRight),
                                onTap: () => context.push('/projeler/${Uri.encodeComponent(p.kimlik)}'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
}
