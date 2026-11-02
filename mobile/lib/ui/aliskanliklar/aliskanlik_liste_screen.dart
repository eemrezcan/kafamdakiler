import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../data/models/aliskanlik.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/kullanici_repository.dart';
import '../bugun/aliskanlik_karti.dart' show yuzdeMetni;
import '../core/ikonlar.dart';
import '../core/renkler.dart';
import '../core/widgets.dart';
import 'aliskanlik_liste_view_model.dart';

class AliskanlikListeScreen extends StatelessWidget {
  const AliskanlikListeScreen({super.key, required this.viewModel});

  final AliskanlikListeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    // Only the Sahip role gets the management entry points (M07).
    final sahip = context.watch<KullaniciRepository>().sahip;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alışkanlıklar'),
        actions: [
          ListenableBuilder(
            listenable: viewModel,
            builder: (context, _) => IconButton(
              tooltip: viewModel.arsiv ? 'Arşivi gizle' : 'Arşivdekileri göster',
              isSelected: viewModel.arsiv,
              icon: const Icon(LucideIcons.archive),
              onPressed: () => viewModel.arsivGoster(!viewModel.arsiv),
            ),
          ),
          if (sahip)
            IconButton(
              tooltip: 'Yeni alışkanlık',
              icon: const Icon(LucideIcons.plus),
              onPressed: () => context.push('/aliskanlik/yeni'),
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final liste = viewModel.liste;
          if (liste == null) {
            if (viewModel.yukleniyor) return const YuklemeIskeleti(yukseklik: 72);
            return BosDurum(
              metin: viewModel.hata ?? 'Liste alınamadı.',
              dugme: 'Tekrar dene',
              onPressed: viewModel.yukle,
            );
          }
          return RefreshIndicator(
            onRefresh: viewModel.yukle,
            child: liste.isEmpty
                ? BosDurum(
                    ikon: LucideIcons.target,
                    metin: viewModel.arsiv
                        ? 'Arşivde alışkanlık yok.'
                        : sahip
                            ? 'Henüz alışkanlık yok. Sağ üstteki + ile ekle.'
                            : 'Henüz alışkanlık yok.',
                  )
                : OrtaGenislik(
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: liste.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _Satir(liste[i]),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _Satir extends StatelessWidget {
  const _Satir(this.a);

  final Aliskanlik a;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final renk = aliskanlikRengi(context, a.renk);
    final rakam = KdYazi.of(context).sayi.copyWith(fontSize: 12, color: tema.colorScheme.onSurfaceVariant);
    return Card(
      color: kartZemini(context, renk),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: kartCercevesi(context, renk)),
      ),
      child: ListTile(
        minTileHeight: 64,
        onTap: () => context.push('/aliskanlik/${a.id}'),
        leading: CircleAvatar(
          backgroundColor: renk.withValues(alpha: 0.16),
          child: Icon(lucideIkonu(a.ikon), color: renk, size: 22),
        ),
        title: Text(a.ad, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${a.tur == AliskanlikTuru.raf ? 'Raf' : 'Sayaç'} · güç ${yuzdeMetni(a.guc)} · seri ${a.seri}',
          style: rakam,
        ),
        trailing: a.arsivlendi ? const Icon(LucideIcons.archive, size: 18) : const Icon(LucideIcons.chevronRight),
      ),
    );
  }
}
