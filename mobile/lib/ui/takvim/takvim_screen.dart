import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/gun_gorunum.dart';
import '../../utils/metin.dart';
import '../core/widgets.dart';
import '../gun/oge_sheet.dart';
import '../gun/yapilacak_satiri.dart';
import '../shell/ust_sag.dart';
import 'takvim_view_model.dart';
import 'yeni_yapilacak_sheet.dart';

/// The Takvim tab (K-0024): week or month, a dot per kind of thing on each day, the list of the chosen day with its load,
/// what is coming up, and ＋ for a new "yapılacak" (with the reminder switch).
class TakvimScreen extends StatelessWidget {
  const TakvimScreen({super.key, required this.viewModel, this.yazabilir = true});

  final TakvimViewModel viewModel;

  /// False (the Asistan account) hides ＋ and the write buttons.
  final bool yazabilir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trBuyuk(DateFormat('MMMM y', 'tr').format(viewModel.secili)),
                style: tema.textTheme.labelSmall?.copyWith(color: tema.colorScheme.onSurfaceVariant, letterSpacing: 0.8),
              ),
              const Text('Takvim'),
            ],
          ),
        ),
        actions: const [UstSagDugmeleri()],
      ),
      floatingActionButton: yazabilir
          ? FloatingActionButton(
              key: const ValueKey('takvim-yeni'),
              tooltip: 'Yeni yapılacak',
              onPressed: () => yeniYapilacakAc(context, viewModel: viewModel.gun, tarih: viewModel.secili, bugun: viewModel.bugun),
              child: const Icon(LucideIcons.plus),
            )
          : null,
      body: ListenableBuilder(
        listenable: Listenable.merge([viewModel, viewModel.gun]),
        builder: (context, _) => RefreshIndicator(
          onRefresh: viewModel.yukle,
          child: OrtaGenislik(child: _icerik(context)),
        ),
      ),
    );
  }

  Widget _icerik(BuildContext context) {
    final tema = Theme.of(context);
    final gun = viewModel.gun.gun;
    final aralik = viewModel.aralik;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Room for the ＋ button under the last row. The strip and the grid use the width up to 8 dp from the edges, so a day cell
      // is at least 48 dp wide at 360 dp; everything else is held in [_Girinti] (16 dp from the edges).
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
      children: [
        if (viewModel.cevrimdisi || viewModel.gun.cevrimdisi)
          _Girinti(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Çevrimdışısın; son okunan takvim gösteriliyor.',
                style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        _Girinti(
          child: SegmentedButton<TakvimGorunumu>(
            key: const ValueKey('takvim-gorunum'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: TakvimGorunumu.hafta, label: Text('Hafta')),
              ButtonSegment(value: TakvimGorunumu.ay, label: Text('Ay')),
            ],
            selected: {viewModel.gorunum},
            onSelectionChanged: (s) => viewModel.gorunumDegistir(s.first),
          ),
        ),
        const SizedBox(height: 8),
        _Girinti(child: _Gezgin(viewModel: viewModel)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: viewModel.gorunum == TakvimGorunumu.hafta
              ? _HaftaSeridi(viewModel: viewModel, aralik: aralik)
              : _AyIzgarasi(viewModel: viewModel, aralik: aralik),
        ),
        if (viewModel.hata != null && aralik == null)
          _Girinti(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(child: Text(viewModel.hata!, style: TextStyle(color: tema.colorScheme.error))),
                  TextButton(onPressed: viewModel.yukle, child: const Text('Tekrar dene')),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        _Girinti(child: _GunBasligi(tarih: viewModel.secili, yuk: gun?.yuk)),
        _Girinti(child: _GunListesi(viewModel: viewModel, gun: gun, yazabilir: yazabilir)),
        const SizedBox(height: 8),
        if (aralik != null && aralik.yaklasan.isNotEmpty) ...[
          _Girinti(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                'YAKLAŞAN',
                style: tema.textTheme.labelMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant, letterSpacing: 0.8, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          // Each row names its day (sözleşme E1); a tap shows that day in the calendar. Ticking is done from the day's own list.
          _Girinti(
            child: YapilacakListesi(
              key: const ValueKey('takvim-yaklasan'),
              ogeler: aralik.yaklasan,
              gunGoster: true,
              onAc: (o) {
                if (o.tarih != null) viewModel.sec(o.tarih!);
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// 16 dp from the edges, for what is not the strip or the grid.
class _Girinti extends StatelessWidget {
  const _Girinti({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child);
}

/// "‹  9 – 15 Kasım  ›" and "Bugün".
class _Gezgin extends StatelessWidget {
  const _Gezgin({required this.viewModel});

  final TakvimViewModel viewModel;

  String _etiket() {
    final r = viewModel.gorunenAralik;
    if (viewModel.gorunum == TakvimGorunumu.ay) return trBuyuk(DateFormat('MMMM y', 'tr').format(viewModel.secili));
    final g = DateFormat('d MMMM', 'tr');
    return '${DateFormat('d', 'tr').format(r.baslangic)} – ${g.format(r.bitis)}';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final gerek = viewModel.secili != viewModel.bugun;
    return Row(
      children: [
        IconButton(
          key: const ValueKey('takvim-geri'),
          tooltip: viewModel.gorunum == TakvimGorunumu.hafta ? 'Önceki hafta' : 'Önceki ay',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => viewModel.kaydir(-1),
        ),
        Expanded(child: Text(_etiket(), textAlign: TextAlign.center, style: tema.textTheme.titleSmall)),
        if (gerek) TextButton(key: const ValueKey('takvim-bugun'), onPressed: viewModel.bugunGit, child: const Text('Bugün')),
        IconButton(
          key: const ValueKey('takvim-ileri'),
          tooltip: viewModel.gorunum == TakvimGorunumu.hafta ? 'Sonraki hafta' : 'Sonraki ay',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(LucideIcons.chevronRight),
          onPressed: () => viewModel.kaydir(1),
        ),
      ],
    );
  }
}

const _kisaGunler = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

/// Up to three dots under a day: plan and tasks, reminders and events, and a red one when the day is over capacity.
class _Noktalar extends StatelessWidget {
  const _Noktalar({required this.gun, required this.secili});

  final TakvimGunu? gun;
  final bool secili;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final g = gun;
    Widget nokta(Color renk) => Container(width: 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 1.5), decoration: BoxDecoration(shape: BoxShape.circle, color: renk));
    return SizedBox(
      height: 6,
      child: g == null
          ? null
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (g.sayilar.plan + g.sayilar.gorev > 0) nokta(secili ? tema.colorScheme.onPrimary : tema.colorScheme.primary),
                if (g.sayilar.hatirlatici + g.sayilar.etkinlik > 0) nokta(secili ? tema.colorScheme.onPrimary : tema.colorScheme.secondary),
                if (g.yukAsimi) nokta(tema.colorScheme.error),
              ],
            ),
    );
  }
}

class _HaftaSeridi extends StatelessWidget {
  const _HaftaSeridi({required this.viewModel, required this.aralik});

  final TakvimViewModel viewModel;
  final TakvimAraligi? aralik;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final basi = viewModel.gorunenAralik.baslangic;
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(builder: (context) {
              final gun = DateTime.utc(basi.year, basi.month, basi.day + i);
              final secili = gun == viewModel.secili;
              final bugun = gun == viewModel.bugun;
              return Semantics(
                button: true,
                selected: secili,
                label: DateFormat('d MMMM EEEE', 'tr').format(gun),
                excludeSemantics: true,
                child: InkWell(
                  key: ValueKey('takvim-gun-${gun.day}-${gun.month}'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => viewModel.sec(gun),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 64),
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: secili ? tema.colorScheme.primary : null,
                      borderRadius: BorderRadius.circular(10),
                      border: bugun && !secili ? Border.all(color: tema.colorScheme.primary) : null,
                    ),
                    child: Column(
                      children: [
                        Text(_kisaGunler[i], style: tema.textTheme.labelSmall?.copyWith(color: secili ? tema.colorScheme.onPrimary : tema.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(
                          '${gun.day}',
                          style: tema.textTheme.titleMedium?.copyWith(color: secili ? tema.colorScheme.onPrimary : null, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        _Noktalar(gun: aralik?.gun(gun), secili: secili),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}

class _AyIzgarasi extends StatelessWidget {
  const _AyIzgarasi({required this.viewModel, required this.aralik});

  final TakvimViewModel viewModel;
  final TakvimAraligi? aralik;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final basi = viewModel.gorunenAralik.baslangic;
    final ay = viewModel.secili.month;
    return Column(
      children: [
        Row(
          children: [
            for (final g in _kisaGunler)
              Expanded(child: Center(child: Text(g, style: tema.textTheme.labelSmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)))),
          ],
        ),
        for (var hafta = 0; hafta < 6; hafta++)
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Builder(builder: (context) {
                    final gun = DateTime.utc(basi.year, basi.month, basi.day + hafta * 7 + i);
                    final secili = gun == viewModel.secili;
                    final bugun = gun == viewModel.bugun;
                    final digerAy = gun.month != ay;
                    return Semantics(
                      button: true,
                      selected: secili,
                      label: DateFormat('d MMMM EEEE', 'tr').format(gun),
                      excludeSemantics: true,
                      child: InkWell(
                        key: ValueKey('takvim-gun-${gun.day}-${gun.month}'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => viewModel.sec(gun),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: secili ? tema.colorScheme.primary : null,
                            borderRadius: BorderRadius.circular(8),
                            border: bugun && !secili ? Border.all(color: tema.colorScheme.primary) : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${gun.day}',
                                style: tema.textTheme.bodyMedium?.copyWith(
                                  color: secili ? tema.colorScheme.onPrimary : (digerAy ? tema.colorScheme.outline : null),
                                ),
                              ),
                              const SizedBox(height: 2),
                              _Noktalar(gun: aralik?.gun(gun), secili: secili),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
            ],
          ),
      ],
    );
  }
}

/// "Salı 10 Kasım" and the day's load, over its list.
class _GunBasligi extends StatelessWidget {
  const _GunBasligi({required this.tarih, required this.yuk});

  final DateTime tarih;
  final GunYuku? yuk;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              trBuyuk(DateFormat('EEEE d MMMM', 'tr').format(tarih)),
              key: const ValueKey('takvim-gun-adi'),
              overflow: TextOverflow.ellipsis,
              style: tema.textTheme.labelMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant, letterSpacing: 0.8, fontWeight: FontWeight.w600),
            ),
          ),
          if (yuk != null && yuk!.kapasiteDk > 0) ...[
            const SizedBox(width: 8),
            Text(
              '${sureMetni(yuk!.toplamDk)} / ${sureMetni(yuk!.kapasiteDk)}',
              key: const ValueKey('takvim-gun-yuku'),
              style: tema.textTheme.labelMedium?.copyWith(color: yuk!.asimDk > 0 ? tema.colorScheme.error : tema.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _GunListesi extends StatelessWidget {
  const _GunListesi({required this.viewModel, required this.gun, required this.yazabilir});

  final TakvimViewModel viewModel;
  final GunGorunum? gun;
  final bool yazabilir;

  @override
  Widget build(BuildContext context) {
    final g = gun;
    final vm = viewModel.gun;
    if (g == null) {
      if (vm.yukleniyor) return const SizedBox(height: 120, child: YuklemeIskeleti(adet: 2, yukseklik: 48));
      return BosKart(metin: vm.hata ?? 'Gün alınamadı.', onTap: vm.yukle);
    }
    if (g.ogeler.isEmpty) return const BosKart(key: ValueKey('takvim-gun-bos'), metin: 'Bu gün için bir şey yok.');
    return YapilacakListesi(
      ogeler: g.ogeler,
      onAc: (o) => ogeAc(context, viewModel: vm, oge: o, yazabilir: yazabilir),
      onYaptim: yazabilir ? (o) => vm.yaptim(o) : null,
    );
  }
}
