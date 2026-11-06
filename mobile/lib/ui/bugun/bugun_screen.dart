import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/aliskanlik.dart';
import '../../utils/aliskanlik_gunu.dart';
import '../core/renkler.dart';
import '../core/widgets.dart';
import '../../utils/metin.dart';
import 'aliskanlik_karti.dart';
import 'bugun_view_model.dart';
import 'gun_plani_karti.dart';
import 'gun_plani_view_model.dart';
import 'sayi_giris_dialog.dart';
import 'yaklasanlar_karti.dart';
import 'yaklasanlar_view_model.dart';

class BugunScreen extends StatelessWidget {
  const BugunScreen({super.key, required this.viewModel, this.gunPlani, this.yaklasanlar});

  final BugunViewModel viewModel;

  /// The brain's plan for the day, shown above the habit cards. Without it the screen is habits only.
  final GunPlaniViewModel? gunPlani;

  /// Upcoming reminders, shown under the plan card. Without it the card is not there.
  final YaklasanlarViewModel? yaklasanlar;

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
          final plan = gunPlani;
          if (plan != null) {
            // Plan card and habits in one scroll: a failing side never hides the other.
            return RefreshIndicator(
              onRefresh: () => Future.wait([viewModel.yukle(), plan.yukle(), if (yaklasanlar != null) yaklasanlar!.yukle()]),
              child: OrtaGenislik(child: _liste(context, plan: plan)),
            );
          }
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
                ? const BosDurum(metin: 'Henüz alışkanlık yok. Profil > Alışkanlıklar ekranından + ile ekleyebilirsin.')
                : OrtaGenislik(child: _liste(context)),
          );
        },
      ),
    );
  }

  /// The habit part when the list is not there (yet): a skeleton, the error with a retry, or the empty hint.
  List<Widget> _aliskanlikDurumu(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = TextStyle(color: tema.colorScheme.onSurfaceVariant);
    if (viewModel.liste == null) {
      if (viewModel.yukleniyor) {
        return [
          for (var i = 0; i < 2; i++)
            Container(
              height: 88,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: tema.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(12)),
            ),
        ];
      }
      return [
        Text(viewModel.hata ?? 'Alışkanlıklar alınamadı.', style: soluk),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: viewModel.yukle, child: const Text('Tekrar dene')),
        ),
      ];
    }
    return [Text('Henüz alışkanlık yok. Profil > Alışkanlıklar ekranından + ile ekleyebilirsin.', style: soluk)];
  }

  Widget _liste(BuildContext context, {GunPlaniViewModel? plan}) {
    final planli = viewModel.planli;
    final plansiz = viewModel.plansiz;
    final tema = Theme.of(context);
    final aliskanlikVar = viewModel.liste != null && viewModel.liste!.isNotEmpty;
    Widget kart(Aliskanlik a) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AliskanlikKarti(
            aliskanlik: a,
            sonGunler: viewModel.sonGunler(a.id),
            onTik: () => _tik(context, a),
            onMiktar: (a, yeni) => viewModel.miktarYaz(a, yeni),
            onSayiGir: () => _sayiGir(context, a),
          ),
        );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Room for the floating "Yakala" button under the last card.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (viewModel.cevrimdisi)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Çevrimdışısın; kaydettiklerin telefona yazılıyor, bağlantı gelince gönderilecek.',
              style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
            ),
          ),
        const _Tarih(),
        if (plan != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: GunPlaniKarti(viewModel: plan)),
        // Hidden until it has an answer, so a failing reminders read leaves no gap.
        if (yaklasanlar != null) ...[
          YaklasanlarKarti(viewModel: yaklasanlar!),
          if (yaklasanlar!.liste != null) const SizedBox(height: 16),
        ],
        // The habit list is not there (yet) or empty: say so under the plan card.
        if (plan != null && !aliskanlikVar) ..._aliskanlikDurumu(context),
        if (planli.isNotEmpty) _BugunOzeti(planli: planli),
        if (planli.isEmpty && (plan == null || aliskanlikVar))
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

/// "Bugün 2 alışkanlıktan 1 tanesi tamam" and a thin bar, above the cards.
/// A habit counts as done when today's value reached 1 (for a limit habit:
/// still under the limit).
class _BugunOzeti extends StatelessWidget {
  const _BugunOzeti({required this.planli});

  final List<Aliskanlik> planli;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final tamam = planli.where((a) => (a.bugun?.deger ?? 0) >= 1).length;
    final hepsi = tamam == planli.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hepsi
                ? 'Bugün hepsi tamam: $tamam / ${planli.length}'
                : 'Bugün ${planli.length} alışkanlıktan $tamam tanesi tamam',
            style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: tamam / planli.length,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
            color: hepsi ? tamamRengi(context) : null,
          ),
        ],
      ),
    );
  }
}

/// "PAZARTESİ · 2 KASIM 2026" above the list, like the web page's eyebrow.
/// The habit day starts at 05:00, so just after midnight it is still yesterday.
class _Tarih extends StatelessWidget {
  const _Tarih();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final buyuk = trBuyuk(DateFormat('EEEE · d MMMM y', 'tr').format(aliskanlikGunu(DateTime.now())));
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        buyuk,
        style: tema.textTheme.labelSmall?.copyWith(color: tema.colorScheme.onSurfaceVariant, letterSpacing: 0.8),
      ),
    );
  }
}
