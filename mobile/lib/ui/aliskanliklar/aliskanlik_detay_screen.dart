import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../data/models/aliskanlik.dart';
import '../../data/models/enums.dart';
import '../../data/models/gun.dart';
import '../../data/repositories/kullanici_repository.dart';
import '../../utils/aliskanlik_gunu.dart';
import '../../utils/dogrulama.dart';
import '../bugun/aliskanlik_karti.dart' show yuzdeMetni;
import '../core/ikonlar.dart';
import '../core/renkler.dart';
import '../core/widgets.dart';
import '../../utils/metin.dart';
import 'aliskanlik_detay_view_model.dart';

enum _Menu { duzenle, arsivle, sil }

class AliskanlikDetayScreen extends StatelessWidget {
  const AliskanlikDetayScreen({super.key, required this.viewModel});

  final AliskanlikDetayViewModel viewModel;

  Future<void> _menu(BuildContext context, _Menu secim) async {
    final mesaj = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    switch (secim) {
      case _Menu.duzenle:
        router.push('/aliskanlik/${viewModel.id}/duzenle');
      case _Menu.arsivle:
        final yeniArsiv = !viewModel.aliskanlik!.arsivlendi;
        final hata = await viewModel.arsivDegistir();
        mesaj.showSnackBar(SnackBar(
          content: Text(hata ?? (yeniArsiv ? 'Arşivlendi' : 'Arşivden çıkarıldı')),
        ));
      case _Menu.sil:
        final onay = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Alışkanlık silinsin mi?'),
            content: Text(
              '"${viewModel.aliskanlik!.ad}" ve tüm kayıtları, öğeleri, oturumları ve fotoğrafları silinir. Bu geri alınamaz.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sil'),
              ),
            ],
          ),
        );
        if (onay != true) return;
        final hata = await viewModel.sil();
        if (hata != null) {
          mesaj.showSnackBar(SnackBar(content: Text(hata)));
        } else {
          mesaj.showSnackBar(const SnackBar(content: Text('Silindi')));
          router.pop();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sahip = context.watch<KullaniciRepository>().sahip;
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final a = viewModel.aliskanlik;
        return Scaffold(
          appBar: AppBar(
            title: Text(a?.ad ?? 'Alışkanlık'),
            actions: [
              if (sahip && a != null)
                PopupMenuButton<_Menu>(
                  tooltip: 'Seçenekler',
                  onSelected: (s) => _menu(context, s),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: _Menu.duzenle, child: Text('Düzenle')),
                    PopupMenuItem(value: _Menu.arsivle, child: Text(a.arsivlendi ? 'Arşivden çıkar' : 'Arşivle')),
                    const PopupMenuItem(value: _Menu.sil, child: Text('Sil')),
                  ],
                ),
            ],
          ),
          body: a == null
              ? (viewModel.yukleniyor
                  ? const Center(child: CircularProgressIndicator())
                  : BosDurum(
                      metin: viewModel.hata ?? 'Alışkanlık bulunamadı.',
                      dugme: 'Tekrar dene',
                      onPressed: viewModel.yukle,
                    ))
              : OrtaGenislik(child: _Icerik(aliskanlik: a, gunler: viewModel.gunler)),
        );
      },
    );
  }
}

class _Icerik extends StatelessWidget {
  const _Icerik({required this.aliskanlik, required this.gunler});

  final Aliskanlik aliskanlik;
  final List<Gun>? gunler;

  @override
  Widget build(BuildContext context) {
    final a = aliskanlik;
    final tema = Theme.of(context);
    final renk = aliskanlikRengi(context, a.renk);
    final rakam = KdYazi.of(context).sayi;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: renk.withValues(alpha: 0.16),
              child: Icon(lucideIkonu(a.ikon), color: renk, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(a.ad, style: tema.textTheme.headlineSmall)),
          ],
        ),
        if (a.arsivlendi)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Chip(avatar: const Icon(LucideIcons.archive, size: 16), label: const Text('Arşivde')),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            _Istatistik(etiket: 'Güç', deger: yuzdeMetni(a.guc), rakam: rakam),
            const SizedBox(width: 8),
            _Istatistik(etiket: 'Seri', deger: '${a.seri}', rakam: rakam),
            const SizedBox(width: 8),
            _Istatistik(etiket: 'En uzun seri', deger: '${a.enUzunSeri}', rakam: rakam),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Güç, düzenin: yaptığın her gün artar, kaçırınca biraz düşer; tek kaçırma sıfırlamaz.',
          style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Text(_ozet(a), style: TextStyle(color: tema.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 24),
        Text('Son 30 gün', style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (gunler == null)
          Text(
            'Günlük ızgara yüklenemedi (çevrimdışı olabilirsin). Çevrimiçi olunca bu ekranı yeniden aç.',
            style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
          )
        else
          _GunIzgarasi(gunler: gunler!, birim: a.birim, renk: renk, ilkGun: aliskanlikGunu(a.olusturulma)),
        if (a.tur == AliskanlikTuru.raf) ...[
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => context.push('/aliskanlik/${a.id}/raf'),
            icon: const Icon(LucideIcons.libraryBig),
            label: const Text('Rafa git'),
          ),
        ],
      ],
    );
  }

  String _ozet(Aliskanlik a) {
    final tur = a.tur == AliskanlikTuru.raf ? 'Raf' : 'Sayaç';
    final hedef = a.olcu == Olcu.evetHayir
        ? 'yaptım / yapmadım'
        : '${a.hedefYonu == HedefYonu.enCok ? 'en çok' : 'en az'} ${sayiMetni(a.gunlukHedef)} ${a.birim ?? ''} / gün';
    final siklik = switch (a.siklik) {
      Siklik.herGun => 'her gün',
      Siklik.haftadaN => 'haftada ${a.haftalikSayi} gün',
      Siklik.belirliGunler => (a.gunler ?? const []).map((g) => g.name).join(', '),
    };
    return '$tur · $hedef · $siklik';
  }
}

/// A stat box like the web's `.kd-stat`: hairline border, small uppercase
/// label on top, the value below.
class _Istatistik extends StatelessWidget {
  const _Istatistik({required this.etiket, required this.deger, required this.rakam});

  final String etiket;
  final String deger;
  final TextStyle rakam;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tema.colorScheme.surface,
          border: Border.all(color: tema.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trBuyuk(etiket),
              style: tema.textTheme.labelSmall?.copyWith(color: tema.colorScheme.onSurfaceVariant, letterSpacing: 0.6),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(deger, style: rakam.copyWith(fontSize: 22, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// 30 small squares, oldest first, in the habit colour: the darker, the
/// fuller the day. Days that were not planned stay as an outline; days before
/// the habit existed are a faint fill, so they do not read as "missed".
class _GunIzgarasi extends StatelessWidget {
  const _GunIzgarasi({required this.gunler, this.birim, required this.renk, required this.ilkGun});

  final List<Gun> gunler;
  final String? birim;
  final Color renk;
  final DateTime ilkGun;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).colorScheme;
    final bicim = DateFormat('d.MM.yyyy');
    final rakam = KdYazi.of(context).sayi.copyWith(fontSize: 11);

    BoxDecoration kutu(Gun g) {
      if (g.tarih.isBefore(ilkGun)) {
        return BoxDecoration(color: tema.outlineVariant.withValues(alpha: tema.outlineVariant.a * 0.5), borderRadius: BorderRadius.circular(8));
      }
      if (!g.planli) {
        return BoxDecoration(border: Border.all(color: tema.outlineVariant), borderRadius: BorderRadius.circular(8));
      }
      return BoxDecoration(
        color: renk.withValues(alpha: 0.14 + 0.86 * g.deger.clamp(0, 1)),
        borderRadius: BorderRadius.circular(8),
      );
    }

    // On a strong fill the number needs the surface colour to stay readable.
    Color yazi(Gun g) => !g.tarih.isBefore(ilkGun) && g.planli && g.deger > 0.5 ? tema.surface : tema.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final g in gunler)
              Tooltip(
                message: g.tarih.isBefore(ilkGun)
                    ? '${bicim.format(g.tarih)}: alışkanlık henüz yoktu'
                    : '${bicim.format(g.tarih)}: ${g.planli ? '${sayiMetni(g.miktar)} ${birim ?? ''}' : 'planlı değil'}',
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: kutu(g),
                  child: Text('${g.tarih.day}', style: rakam.copyWith(color: yazi(g))),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _Aciklama(renk: renk, metin: 'hedef tamam'),
            _Aciklama(renk: renk.withValues(alpha: 0.5), metin: 'kısmen'),
            _Aciklama(renk: renk.withValues(alpha: 0.14), metin: 'yapılmadı'),
            _Aciklama(cerceve: tema.outlineVariant, metin: 'planlı değil'),
          ],
        ),
      ],
    );
  }
}

/// One legend entry: a small square like the grid's, and its meaning.
class _Aciklama extends StatelessWidget {
  const _Aciklama({this.renk, this.cerceve, required this.metin});

  final Color? renk;
  final Color? cerceve;
  final String metin;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: renk,
            border: cerceve != null ? Border.all(color: cerceve!) : null,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(metin, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
