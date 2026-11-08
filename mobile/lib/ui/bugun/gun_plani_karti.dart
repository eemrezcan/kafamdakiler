import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/beyin.dart';
import '../../data/repositories/gun_plani_repository.dart';
import '../core/beyin_gorunum.dart';
import 'gun_plani_dialoglari.dart';
import 'gun_plani_view_model.dart';

/// The brain's plan for a day: arrows to move a day back or forward, the morning card, the plan lines, the overdue tasks
/// and the tally. Plan lines can be ticked, carried to the next day and given a note; new lines and tasks can be added
/// (K2.3a). All of it works offline: a write shows at once and is sent later. A failed read shows the reason in the card
/// (the habit cards below keep working).
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

  /// "bugün", "yarın", "9 Kasım": the day the plan line goes to, for the add dialog.
  String _gunAdi() => switch (viewModel.tarih.difference(viewModel.bugun).inDays) {
        0 => 'bugün',
        -1 => 'dün',
        1 => 'yarın',
        _ => DateFormat('d MMMM', 'tr').format(viewModel.tarih),
      };

  Future<void> _ekle(BuildContext context) async {
    final projeler = await viewModel.projeler();
    if (!context.mounted) return;
    final ekleme = await planaEkleDialogu(context, projeler: projeler, gunAdi: _gunAdi());
    switch (ekleme) {
      case MaddeEklemesi(:final metin):
        await viewModel.maddeEkle(metin);
      case GorevEklemesi(:final gorev):
        await viewModel.gorevEkle(baslik: gorev.baslik, proje: gorev.proje, bitis: gorev.bitis);
      case null:
        break;
    }
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
                // The same heading as the other cards of Bugün; the screen already says it is today, so the day is only
                // named when another one is on show (tapping it comes back to today).
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text('Gün planı', style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    if (!viewModel.bugunMu)
                      Tooltip(
                        message: 'Bugüne dön',
                        child: TextButton(onPressed: viewModel.bugune, child: Text(_baslik())),
                      ),
                    IconButton(
                      tooltip: 'Önceki gün',
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: const Icon(LucideIcons.chevronLeft),
                      onPressed: () => viewModel.gunDegistir(-1),
                    ),
                    IconButton(
                      tooltip: 'Sonraki gün',
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: const Icon(LucideIcons.chevronRight),
                      onPressed: () => viewModel.gunDegistir(1),
                    ),
                  ],
                ),
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
    final yazilabilir = viewModel.yazilabilir;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in viewModel.bildirimler) _Bildirim(b, onKapat: () => viewModel.bildirimiKapat(b)),
        if (viewModel.cevrimdisi)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(LucideIcons.cloudOff, size: 16, color: soluk),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Çevrimdışısın; telefondaki plan gösteriliyor.', style: TextStyle(fontSize: 12, color: soluk)),
                ),
              ],
            ),
          ),
        if (viewModel.sabah.isNotEmpty) _SabahKarti(viewModel: viewModel),
        if (gun.kapasiteUyarisi case final uyari?)
          Container(
            key: const Key('kapasite-uyarisi'),
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: tema.colorScheme.error),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.triangleAlert, size: 18, color: tema.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bugün sığmıyor: açık işler ${dakikaMetni(uyari.acikTahminDk)}, günlük kapasite '
                    '${dakikaMetni(uyari.kapasiteDk)}; ${dakikaMetni(uyari.asimDk)} fazla. Bir kısmını devret.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        if (gun.kapandi) Text('Bu gün kapandı; kapanmış güne yazılmaz.', style: TextStyle(fontSize: 12, color: soluk)),
        if (gun.bos)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Bu gün için plan yok.', style: TextStyle(color: soluk)),
          )
        else ...[
          for (final b in gun.bolumler)
            if (b.maddeler.isNotEmpty) ...[
              if (gun.bolumler.length > 1 || b.ad != 'Yapılacaklar') BolumBasligi(b.ad, ustBosluk: 8),
              for (final m in b.maddeler)
                _Madde(
                  m,
                  yazilabilir: yazilabilir,
                  onIsaretle: () => viewModel.isaretle(m),
                  onDevret: () => viewModel.devret(m, b.ad),
                  onNot: () async {
                    final metin = await gunPlaniMetinDialogu(
                      context,
                      baslik: 'Maddeye not',
                      ipucu: m.baslik,
                      onay: 'Kaydet',
                      enCok: 500,
                    );
                    if (metin != null) await viewModel.notEkle(m, metin);
                  },
                ),
            ],
          if (viewModel.geciken(gun) case final geciken when geciken.isNotEmpty) ...[
            BolumBasligi('Geciken görevler', ustBosluk: 12),
            for (final g in geciken)
              _Geciken(
                g,
                proje: g.proje == null ? null : viewModel.projeAdi(g.proje!),
                yazilabilir: yazilabilir,
                onBitir: () => viewModel.gorevBitir(g.kimlik),
                onBol: () async {
                  final gunSayisi = await gunlereBolDialogu(context, g.baslik);
                  if (gunSayisi != null) await viewModel.bol(g.kimlik, gunSayisi);
                },
              ),
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
        if (yazilabilir)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextButton.icon(
              key: const Key('plan-ekle'),
              onPressed: () => _ekle(context),
              icon: const Icon(Icons.add),
              label: const Text('Ekle'),
            ),
          ),
      ],
    );
  }
}

/// "Dünden kalanlar": yesterday's plan lines that stayed open. "Taşı" carries one to today; "Bırak" only closes this entry
/// (nothing is written to the brain).
class _SabahKarti extends StatelessWidget {
  const _SabahKarti({required this.viewModel});

  final GunPlaniViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      key: const Key('sabah-karti'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dünden kalanlar', style: tema.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
          for (final s in viewModel.sabah)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: _SabahSatiri(s, gorev: viewModel.sabahGorevi(s), viewModel: viewModel)),
                  TextButton(onPressed: () => viewModel.sabahTasi(s), child: const Text('Taşı')),
                  TextButton(onPressed: () => viewModel.sabahBirak(s), child: const Text('Bırak')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A leftover line; when it stands for an overdue task, the task's project and lateness are told under it (the task is then
/// left out of "Geciken görevler", so it shows once).
class _SabahSatiri extends StatelessWidget {
  const _SabahSatiri(this.sabah, {required this.gorev, required this.viewModel});

  final SabahMaddesi sabah;
  final GecikenGorev? gorev;
  final GunPlaniViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final g = gorev;
    if (g == null) return Text(sabah.madde.baslik);
    final parcalar = [
      if (g.proje != null) viewModel.projeAdi(g.proje!),
      if (g.gun != null) '${g.gun} gün gecikti',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(sabah.madde.baslik),
        if (parcalar.isNotEmpty)
          Text(
            parcalar.join(' · '),
            style: TextStyle(fontSize: 12, color: g.gun != null ? tema.colorScheme.error : tema.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

/// A refused write (taken back off the screen) or an accepted one that needs a look.
class _Bildirim extends StatelessWidget {
  const _Bildirim(this.bildirim, {required this.onKapat});

  final YazmaBildirimi bildirim;
  final VoidCallback onKapat;

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 4, 0, 4),
      decoration: BoxDecoration(border: Border.all(color: renk), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(LucideIcons.triangleAlert, size: 18, color: renk),
          const SizedBox(width: 8),
          Expanded(child: Text(bildirim.metin, style: const TextStyle(fontSize: 13))),
          IconButton(
            tooltip: 'Kapat',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.close, size: 18),
            onPressed: onKapat,
          ),
        ],
      ),
    );
  }
}

class _Madde extends StatelessWidget {
  const _Madde(
    this.madde, {
    required this.yazilabilir,
    required this.onIsaretle,
    required this.onDevret,
    required this.onNot,
  });

  final BeyinGunMaddesi madde;
  final bool yazilabilir;
  final VoidCallback onIsaretle;
  final VoidCallback onDevret;
  final VoidCallback onNot;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    final islemli = yazilabilir && madde.kalici;
    final ikon = Icon(
      madde.yapildi
          ? LucideIcons.circleCheck
          : madde.devredildi
              ? LucideIcons.chevronRight
              : madde.yerel
                  ? LucideIcons.clock
                  : LucideIcons.circle,
      size: 20,
      semanticLabel: madde.yapildi
          ? 'Yapıldı'
          : madde.devredildi
              ? 'Devredildi'
              : madde.yerel
                  ? 'Gönderilecek'
                  : 'Yapılmadı',
      color: madde.yapildi ? tema.colorScheme.primary : soluk,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 48 dp target around the 20 dp mark.
          SizedBox.square(
            dimension: 40,
            child: islemli && !madde.devredildi
                ? IconButton(
                    tooltip: madde.yapildi ? 'İşareti kaldır: ${madde.baslik}' : 'Yaptım: ${madde.baslik}',
                    onPressed: onIsaretle,
                    icon: ikon,
                  )
                : Center(child: ikon),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              madde.baslik,
              style: madde.yapildi || madde.devredildi
                  ? TextStyle(color: soluk, decoration: madde.yapildi ? TextDecoration.lineThrough : null)
                  : null,
            ),
          ),
          if (madde.yerel)
            Text('gönderilecek', style: TextStyle(fontSize: 11, color: soluk))
          else if (madde.devredildi)
            Text('devredildi', style: TextStyle(fontSize: 11, color: soluk)),
          if (madde.tahminDk != null) ...[
            const SizedBox(width: 8),
            Text(dakikaMetni(madde.tahminDk!), style: TextStyle(fontSize: 12, color: soluk)),
          ],
          if (islemli && madde.acik)
            PopupMenuButton<String>(
              tooltip: 'Madde işlemleri: ${madde.baslik}',
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) => v == 'devret' ? onDevret() : onNot(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'devret', child: Text('Ertesi güne devret')),
                PopupMenuItem(value: 'not', child: Text('Not ekle')),
              ],
            ),
        ],
      ),
    );
  }
}

class _Geciken extends StatelessWidget {
  const _Geciken(this.gorev, {required this.proje, required this.yazilabilir, required this.onBitir, required this.onBol});

  final GecikenGorev gorev;

  /// The project's title (or id when unknown).
  final String? proje;
  final bool yazilabilir;
  final VoidCallback onBitir;
  final VoidCallback onBol;

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
                if (proje != null) Text(proje!, style: TextStyle(fontSize: 12, color: soluk)),
              ],
            ),
          ),
          if (gorev.gun != null) ...[
            const SizedBox(width: 8),
            Text('${gorev.gun} gün gecikti', style: TextStyle(fontSize: 12, color: tema.colorScheme.error)),
          ],
          if (yazilabilir)
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
    );
  }
}
