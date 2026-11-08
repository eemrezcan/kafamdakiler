import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/beyin.dart';
import '../../data/models/proje_repo.dart';
import '../core/beyin_gorunum.dart';
import '../core/beyin_hata.dart';
import '../bugun/gun_plani_dialoglari.dart';
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
                  child: OrtaGenislik(child: _Icerik(proje: proje, viewModel: viewModel)),
                ),
        );
      },
    );
  }
}

class _Icerik extends StatelessWidget {
  const _Icerik({required this.proje, required this.viewModel});

  final ProjeDetay proje;
  final ProjeDetayViewModel viewModel;

  /// The new-task form starts on this project; a task added here is sent in the background and shows after the next read.
  Future<void> _gorevEkle(BuildContext context) async {
    final projeler = await viewModel.projeler();
    if (!context.mounted) return;
    final gorev = await gorevEkleDialogu(context, projeler);
    if (gorev == null) return;
    await viewModel.gorevEkle(baslik: gorev.baslik, proje: gorev.proje, bitis: gorev.bitis);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Görev eklendi; gönderilince listede görünür.')));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    final acik = [for (final g in proje.acikGorevler) if (!viewModel.bitirilen.contains(g.kimlik)) g];
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
        if (acik.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('Açık görev yok.', style: TextStyle(color: soluk)))
        else
          for (final g in acik)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _Gorev(
                g,
                onBitir: () => viewModel.gorevBitir(g.kimlik),
                onBol: () async {
                  final gunSayisi = await gunlereBolDialogu(context, g.baslik);
                  if (gunSayisi != null) await viewModel.bol(g.kimlik, gunSayisi);
                },
              ),
            ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _gorevEkle(context),
            icon: const Icon(Icons.add_task),
            label: const Text('Görev ekle'),
          ),
        ),
        // No card at all while loading, when nothing is linked, or when the card could not be read: the page is about the
        // project, and the repository is an extra.
        if (viewModel.repoOzeti != null) ...[
          const BolumBasligi('Depo'),
          _RepoKarti(ozet: viewModel.repoOzeti!),
        ],
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

/// The repository of the project: its link (selectable, with a copy button; there is no browser plugin in the app), the open
/// pull request count and the last commits. Without the server's GitHub token only the link is shown, with the reason.
class _RepoKarti extends StatelessWidget {
  const _RepoKarti({required this.ozet});

  final ProjeRepoOzeti ozet;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    final commitler = ozet.commitler ?? const <RepoCommit>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.gitBranch, size: 18, color: tema.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(ozet.depo, style: tema.textTheme.bodyLarge)),
                IconButton(
                  tooltip: 'Bağlantıyı kopyala',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: const Icon(LucideIcons.copy, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: ozet.baglanti));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(const SnackBar(content: Text('Bağlantı kopyalandı')));
                  },
                ),
              ],
            ),
            SelectableText(ozet.baglanti, style: TextStyle(fontSize: 12, color: soluk)),
            if (!ozet.tamam) ...[
              const SizedBox(height: 8),
              Text(ozet.mesaj ?? 'Depo bilgisi alınamadı.', style: TextStyle(fontSize: 13, color: soluk)),
            ] else ...[
              const SizedBox(height: 8),
              Text('${ozet.acikPrSayisi ?? 0} açık PR', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (commitler.isEmpty)
                Text('Commit yok.', style: TextStyle(color: soluk))
              else
                for (final c in commitler)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.mesaj),
                        Text(
                          [c.hash, if (c.yazar != null) c.yazar!, if (c.tarih != null) kisaTarih(c.tarih!.toLocal())].join(' · '),
                          style: TextStyle(fontSize: 12, color: soluk),
                        ),
                      ],
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Gorev extends StatelessWidget {
  const _Gorev(this.gorev, {required this.onBitir, required this.onBol});

  final ProjeGorev gorev;
  final VoidCallback onBitir;
  final VoidCallback onBol;

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
            Row(
              children: [
                Expanded(child: Text(gorev.baslik, style: tema.textTheme.bodyLarge)),
                PopupMenuButton<String>(
                  tooltip: 'Görev işlemleri: ${gorev.baslik}',
                  icon: const Icon(Icons.more_vert, size: 20),
                  padding: EdgeInsets.zero,
                  onSelected: (v) => v == 'bitir' ? onBitir() : onBol(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'bitir', child: Text('Görevi bitir')),
                    PopupMenuItem(value: 'bol', child: Text('Günlere böl')),
                  ],
                ),
              ],
            ),
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
