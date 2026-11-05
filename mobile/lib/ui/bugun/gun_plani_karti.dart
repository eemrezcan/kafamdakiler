import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/beyin.dart';
import '../core/beyin_gorunum.dart';
import 'gun_plani_view_model.dart';

/// The brain's plan for a day: arrows to move a day back or forward, then the plan
/// lines, the overdue tasks and the tally. Read only. A failed read shows the reason
/// in the card (the habit cards below keep working).
class GunPlaniKarti extends StatelessWidget {
  const GunPlaniKarti({super.key, required this.viewModel});

  final GunPlaniViewModel viewModel;

  String _baslik() {
    final t = viewModel.tarih;
    final bugun = viewModel.bugun;
    final fark = t.difference(bugun).inDays;
    return switch (fark) {
      0 => 'Bugün',
      -1 => 'Dün',
      1 => 'Yarın',
      _ => DateFormat(t.year == bugun.year ? 'd MMMM EEEE' : 'd MMMM y EEEE', 'tr').format(t),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final tema = Theme.of(context);
        final gun = viewModel.veri;
        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Önceki gün',
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: const Icon(LucideIcons.chevronLeft),
                      onPressed: () => viewModel.gunDegistir(-1),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text('Gün planı', style: TextStyle(fontSize: 12, color: tema.colorScheme.onSurfaceVariant)),
                          Text(_baslik(), style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sonraki gün',
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: const Icon(LucideIcons.chevronRight),
                      onPressed: () => viewModel.gunDegistir(1),
                    ),
                  ],
                ),
                if (!viewModel.bugunMu)
                  Center(child: TextButton(onPressed: viewModel.bugune, child: const Text('Bugüne dön'))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _govde(context, gun),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _govde(BuildContext context, BeyinGun? gun) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    if (gun == null) {
      final hata = viewModel.hata;
      if (hata == null) {
        return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator());
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(hata.ikon, size: 20, color: soluk),
            const SizedBox(width: 10),
            Expanded(child: Text(hata.metin, style: TextStyle(color: soluk))),
            TextButton(onPressed: viewModel.yukle, child: const Text('Tekrar dene')),
          ],
        ),
      );
    }
    if (gun.bos) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Bu gün için plan yok.', style: TextStyle(color: soluk)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in gun.bolumler)
          if (b.maddeler.isNotEmpty) ...[
            if (gun.bolumler.length > 1 || b.ad != 'Yapılacaklar') BolumBasligi(b.ad, ustBosluk: 8),
            for (final m in b.maddeler) _Madde(m),
          ],
        if (gun.geciken.isNotEmpty) ...[
          BolumBasligi('Geciken görevler', ustBosluk: 12),
          for (final g in gun.geciken) _Geciken(g),
        ],
        if (gun.toplam != null && gun.toplam!.madde > 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '${gun.toplam!.yapildi} / ${gun.toplam!.madde} tamam',
              style: TextStyle(fontSize: 12, color: soluk),
            ),
          ),
      ],
    );
  }
}

class _Madde extends StatelessWidget {
  const _Madde(this.madde);

  final BeyinGunMaddesi madde;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            madde.yapildi ? LucideIcons.circleCheck : LucideIcons.circle,
            size: 20,
            semanticLabel: madde.yapildi ? 'Yapıldı' : 'Yapılmadı',
            color: madde.yapildi ? tema.colorScheme.primary : soluk,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              madde.baslik,
              style: madde.yapildi ? TextStyle(color: soluk, decoration: TextDecoration.lineThrough) : null,
            ),
          ),
          if (madde.tahminDk != null) ...[
            const SizedBox(width: 8),
            Text(dakikaMetni(madde.tahminDk!), style: TextStyle(fontSize: 12, color: soluk)),
          ],
        ],
      ),
    );
  }
}

class _Geciken extends StatelessWidget {
  const _Geciken(this.gorev);

  final GecikenGorev gorev;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.clock, size: 20, color: tema.colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gorev.baslik),
                if (gorev.proje != null) Text(gorev.proje!, style: TextStyle(fontSize: 12, color: soluk)),
              ],
            ),
          ),
          if (gorev.gun != null) ...[
            const SizedBox(width: 8),
            Text('${gorev.gun} gün', style: TextStyle(fontSize: 12, color: tema.colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
