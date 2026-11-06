import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/models/hatirlatici.dart';
import '../../data/repositories/kullanici_repository.dart';
import '../../utils/hatirlatici_gorunum.dart';
import '../core/widgets.dart';
import 'hatirlatici_karti.dart';
import 'hatirlatici_liste_view_model.dart';

/// The reminders list, a full-screen page opened from the Today card and from Profil. Adding, editing, Yaptım and
/// Ertele are for the Sahip (K-0009); other users only read.
class HatirlaticiListeScreen extends StatelessWidget {
  const HatirlaticiListeScreen({super.key, required this.viewModel});

  final HatirlaticiListeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final sahip = context.watch<KullaniciRepository>().sahip;
    return Scaffold(
      appBar: AppBar(title: const Text('Hatırlatıcılar')),
      floatingActionButton: sahip
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/hatirlatici/yeni'),
              icon: const Icon(LucideIcons.plus),
              label: const Text('Yeni'),
            )
          : null,
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final liste = viewModel.liste;
          if (liste == null) {
            if (viewModel.yukleniyor) return const YuklemeIskeleti(yukseklik: 96);
            return BosDurum(
              metin: viewModel.hata ?? 'Liste alınamadı.',
              dugme: 'Tekrar dene',
              onPressed: viewModel.yukle,
            );
          }
          final satirlar = viewModel.gosterilen;
          return RefreshIndicator(
            onRefresh: viewModel.yukle,
            child: OrtaGenislik(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                // Room for the floating button under the last row.
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  SegmentedButton<HatirlaticiDurumu>(
                    showSelectedIcon: false,
                    segments: [
                      for (final d in HatirlaticiDurumu.values)
                        ButtonSegment(value: d, label: Text('${hatirlaticiDurumAdi(d)} ${viewModel.sayi(d)}')),
                    ],
                    selected: {viewModel.durum},
                    onSelectionChanged: (s) => viewModel.durumSec(s.first),
                  ),
                  const SizedBox(height: 12),
                  if (viewModel.hata != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(viewModel.hata!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  if (satirlar.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        liste.isEmpty
                            ? 'Henüz hatırlatıcı yok. Bir görev, verdiğin bir söz ya da özel bir tarih ekle.'
                            : 'Bu sekmede hatırlatıcı yok.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  for (final h in satirlar)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: HatirlaticiKarti(
                        hatirlatici: h,
                        simdi: viewModel.simdi,
                        duzenlenebilir: sahip,
                        onYaptim: () => viewModel.yaptim(h.id),
                        onErtele: (sure) => viewModel.ertele(h.id, sure),
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
