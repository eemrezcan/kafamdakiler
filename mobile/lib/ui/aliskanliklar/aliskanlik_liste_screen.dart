import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../data/models/aliskanlik.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/kullanici_repository.dart';
import '../bugun/aliskanlik_karti.dart';
import '../bugun/sayi_giris_dialog.dart';
import '../core/ikonlar.dart';
import '../core/renkler.dart';
import '../core/widgets.dart';
import '../shell/ust_sag.dart';
import 'aliskanlik_liste_view_model.dart';

/// The Alışkanlıklar tab (K-0024): every habit as a card with its own quick write (tick, +/-, the reading entry of a shelf
/// habit with the book in progress and the others on the shelf); the archive is a plain list.
class AliskanlikListeScreen extends StatelessWidget {
  const AliskanlikListeScreen({super.key, required this.viewModel});

  final AliskanlikListeViewModel viewModel;

  Future<void> _tik(BuildContext context, Aliskanlik a) async {
    final mesaj = ScaffoldMessenger.of(context);
    final onceki = await viewModel.tikDegistir(a);
    mesaj
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(onceki >= 1 ? '${a.ad}: işaret kaldırıldı' : '${a.ad}: yapıldı'),
        action: SnackBarAction(label: 'Geri al', onPressed: () => viewModel.miktarYaz(a, onceki)),
      ));
  }

  Future<void> _sayiGir(BuildContext context, Aliskanlik a) async {
    final yeni = await sayiGirisDialogu(context, baslik: a.ad, mevcut: a.bugun?.miktar ?? 0, birim: a.birim);
    if (yeni != null) await viewModel.miktarYaz(a, yeni);
  }

  @override
  Widget build(BuildContext context) {
    // Only the Sahip role gets the management entry points (M07).
    final sahip = context.watch<KullaniciRepository>().sahip;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            final ozet = viewModel.bugunOzeti;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!viewModel.arsiv && viewModel.liste != null && ozet.planli > 0)
                  Text(
                    '${ozet.tamam} / ${ozet.planli} bugün',
                    key: const ValueKey('aliskanlik-ozet'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                const Text('Alışkanlıklar'),
              ],
            );
          },
        ),
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
          const UstSagDugmeleri(),
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
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: liste.length,
                      separatorBuilder: (_, _) => SizedBox(height: viewModel.arsiv ? 8 : 12),
                      itemBuilder: (context, i) => viewModel.arsiv
                          ? _Satir(liste[i])
                          : AliskanlikKarti(
                              aliskanlik: liste[i],
                              onTik: () => _tik(context, liste[i]),
                              onMiktar: (a, yeni) => viewModel.miktarYaz(a, yeni),
                              onSayiGir: () => _sayiGir(context, liste[i]),
                            ),
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
