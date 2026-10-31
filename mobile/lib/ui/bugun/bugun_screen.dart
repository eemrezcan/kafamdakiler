import 'package:flutter/material.dart';

import '../../data/models/aliskanlik.dart';
import '../core/widgets.dart';
import 'aliskanlik_karti.dart';
import 'bugun_view_model.dart';
import 'sayi_giris_dialog.dart';

class BugunScreen extends StatelessWidget {
  const BugunScreen({super.key, required this.viewModel});

  final BugunViewModel viewModel;

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
    final yeni = await sayiGirisDialogu(
      context,
      baslik: a.ad,
      mevcut: a.bugun?.miktar ?? 0,
      birim: a.birim,
    );
    if (yeni != null) await viewModel.miktarYaz(a, yeni);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bugün')),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final liste = viewModel.liste;
          if (liste == null) {
            if (viewModel.yukleniyor) return const YuklemeIskeleti();
            return BosDurum(
              metin: viewModel.hata ?? 'Alışkanlıklar alınamadı.',
              dugme: 'Tekrar dene',
              onPressed: viewModel.yukle,
            );
          }
          return RefreshIndicator(
            onRefresh: viewModel.yukle,
            child: liste.isEmpty
                ? const BosDurum(metin: 'Henüz alışkanlık yok. Alışkanlıklar sekmesinden + ile ekleyebilirsin.')
                : OrtaGenislik(child: _liste(context)),
          );
        },
      ),
    );
  }

  Widget _liste(BuildContext context) {
    final planli = viewModel.planli;
    final plansiz = viewModel.plansiz;
    final tema = Theme.of(context);
    Widget kart(Aliskanlik a) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AliskanlikKarti(
            aliskanlik: a,
            onTik: () => _tik(context, a),
            onMiktar: (a, yeni) => viewModel.miktarYaz(a, yeni),
            onSayiGir: () => _sayiGir(context, a),
          ),
        );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (viewModel.cevrimdisi)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Çevrimdışısın; kaydettiklerin telefona yazılıyor, bağlantı gelince gönderilecek.',
              style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
            ),
          ),
        if (planli.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Bugün planlı alışkanlık yok.',
              style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
            ),
          ),
        for (final a in planli) kart(a),
        if (plansiz.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Text(
              'Bugün planlı değil',
              style: tema.textTheme.titleSmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
          ),
          for (final a in plansiz) Opacity(opacity: 0.55, child: kart(a)),
        ],
      ],
    );
  }
}
