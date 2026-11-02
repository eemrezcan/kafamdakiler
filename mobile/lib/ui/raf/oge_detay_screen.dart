import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../data/models/enums.dart';
import '../../data/models/oge.dart';
import '../../data/models/oturum.dart';
import '../../data/repositories/kullanici_repository.dart';
import '../../utils/dogrulama.dart';
import '../../utils/metin.dart';
import '../core/renkler.dart';
import '../core/widgets.dart';
import 'oge_detay_view_model.dart';

String ogeDurumMetni(OgeDurumu d) => switch (d) {
      OgeDurumu.devam => 'Devam',
      OgeDurumu.siradaki => 'Sıradaki',
      OgeDurumu.bitti => 'Bitti',
      OgeDurumu.birakildi => 'Bırakıldı',
    };

class OgeDetayScreen extends StatelessWidget {
  const OgeDetayScreen({super.key, required this.viewModel});

  final OgeDetayViewModel viewModel;

  Future<void> _sil(BuildContext context) async {
    final mesaj = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Silinsin mi?'),
        content: Text('"${viewModel.oge!.ad}", oturumları ve fotoğrafı silinir. Bu geri alınamaz.'),
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
    final hata = await viewModel.ogeSil();
    if (hata != null) {
      mesaj.showSnackBar(SnackBar(content: Text(hata)));
    } else {
      mesaj.showSnackBar(const SnackBar(content: Text('Silindi')));
      router.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sahip = context.watch<KullaniciRepository>().sahip;
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final oge = viewModel.oge;
        return Scaffold(
          appBar: AppBar(
            actions: [
              if (sahip && oge != null) ...[
                IconButton(
                  tooltip: 'Düzenle',
                  icon: const Icon(LucideIcons.pencil),
                  onPressed: () => context.push('/oge/${oge.id}/duzenle'),
                ),
                IconButton(
                  tooltip: 'Sil',
                  icon: const Icon(LucideIcons.trash2),
                  onPressed: () => _sil(context),
                ),
              ],
            ],
          ),
          body: oge == null
              ? (viewModel.yukleniyor
                  ? const Center(child: CircularProgressIndicator())
                  : BosDurum(metin: viewModel.hata ?? 'Öğe bulunamadı.', dugme: 'Tekrar dene', onPressed: viewModel.yukle))
              : OrtaGenislik(child: _Icerik(viewModel: viewModel, sahip: sahip)),
        );
      },
    );
  }
}

class _Icerik extends StatelessWidget {
  const _Icerik({required this.viewModel, required this.sahip});

  final OgeDetayViewModel viewModel;
  final bool sahip;

  @override
  Widget build(BuildContext context) {
    final oge = viewModel.oge!;
    final tema = Theme.of(context);
    final rakam = KdYazi.of(context).sayi;
    final birim = viewModel.birim;
    final renk = aliskanlikRengi(context, viewModel.renk);
    final tarih = DateFormat('d.MM.yyyy');
    final toplam = oge.toplam != null ? ' / ${sayiMetni(oge.toplam)}' : '';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 160,
              height: 230,
              child: ApiResim(dosyaId: oge.fotografId, yedekIkon: LucideIcons.bookOpen),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(oge.ad, style: tema.textTheme.headlineSmall, textAlign: TextAlign.center),
        if (oge.altBaslik != null)
          Text(oge.altBaslik!, style: tema.textTheme.bodyLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        // Shelf as a small outlined pill in the habit colour (web `.kd-status`).
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(border: Border.all(color: renk), borderRadius: BorderRadius.circular(99)),
            child: Text(
              trBuyuk(ogeDurumMetni(oge.durum)),
              style: tema.textTheme.labelSmall?.copyWith(color: renk, letterSpacing: 0.8, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (oge.ilerleme != null)
          LinearProgressIndicator(
            value: oge.ilerleme!.clamp(0, 1).toDouble(),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: renk,
          ),
        const SizedBox(height: 8),
        Text('${sayiMetni(oge.guncelKonum)}$toplam $birim', style: rakam.copyWith(fontSize: 18), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 24,
          runSpacing: 8,
          children: [
            if (oge.hiz != null) _Bilgi('Hız', '${sayiMetni(oge.hiz)} $birim/gün'),
            if (oge.tahminiBitis != null) _Bilgi('Tahmini bitiş', tarih.format(oge.tahminiBitis!)),
            if (oge.toplamDakika != null) _Bilgi('Toplam süre', '${oge.toplamDakika} dk'),
            if (oge.puan != null) _Bilgi('Puan', '${oge.puan}/5'),
          ],
        ),
        if (oge.not != null) ...[
          const SizedBox(height: 16),
          Text(oge.not!, style: tema.textTheme.bodyMedium),
        ],
        // A finished or dropped item has nothing left to read; it is moved back from the edit form.
        if (oge.durum == OgeDurumu.devam || oge.durum == OgeDurumu.siradaki) ...[
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => context.push('/oge/${oge.id}/oturum'),
            icon: const Icon(LucideIcons.play),
            label: const Text('Okumaya başla'),
          ),
        ],
        const SizedBox(height: 24),
        Text('Oturum geçmişi', style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (viewModel.oturumlar == null)
          Text(
            'Geçmiş yüklenemedi (çevrimdışı olabilirsin). Çevrimiçi olunca bu ekranı yeniden aç.',
            style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
          )
        else if (viewModel.oturumlar!.isEmpty)
          Text(
            'Henüz oturum yok. "Okumaya başla" ile ilkini kaydet.',
            style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
          )
        else
          for (final o in viewModel.oturumlar!)
            _OturumSatiri(oturum: o, oge: oge, birim: birim, viewModel: viewModel, sahip: sahip),
      ],
    );
  }
}

class _Bilgi extends StatelessWidget {
  const _Bilgi(this.etiket, this.deger);

  final String etiket;
  final String deger;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      children: [
        Text(deger, style: KdYazi.of(context).sayi.copyWith(fontWeight: FontWeight.w600)),
        Text(etiket, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _OturumSatiri extends StatelessWidget {
  const _OturumSatiri({
    required this.oturum,
    required this.oge,
    required this.birim,
    required this.viewModel,
    required this.sahip,
  });

  final Oturum oturum;
  final Oge oge;
  final String birim;
  final OgeDetayViewModel viewModel;
  final bool sahip;

  Future<void> _duzenle(BuildContext context) async {
    final mesaj = ScaffoldMessenger.of(context);
    final sonuc = await showDialog<(double, int?)>(
      context: context,
      builder: (context) => _OturumDuzenleDialogu(oturum: oturum, toplam: oge.toplam),
    );
    if (sonuc == null) return;
    final hata = await viewModel.oturumGuncelle(oturum, sonuc.$1, sonuc.$2);
    mesaj.showSnackBar(SnackBar(content: Text(hata ?? 'Oturum güncellendi')));
  }

  Future<void> _sil(BuildContext context) async {
    final mesaj = ScaffoldMessenger.of(context);
    final onay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Son oturum silinsin mi?'),
        content: const Text('Konum bir önceki oturumun bitişine döner.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    );
    if (onay != true) return;
    final hata = await viewModel.oturumSil(oturum);
    mesaj.showSnackBar(SnackBar(content: Text(hata ?? 'Oturum silindi')));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final rakam = KdYazi.of(context).sayi.copyWith(fontSize: 13);
    final soluk = rakam.copyWith(color: tema.colorScheme.onSurfaceVariant);
    // One line like the web's session row: date, range, then the amount at the right end.
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tema.colorScheme.outlineVariant))),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(DateFormat('d MMM', 'tr').format(oturum.tarih), style: soluk)),
          Text('${sayiMetni(oturum.baslangicKonum)} → ${sayiMetni(oturum.bitisKonum)}', style: rakam),
          const Spacer(),
          Text('+${sayiMetni(oturum.miktar)} $birim${oturum.dakika != null ? ' · ${oturum.dakika} dk' : ''}', style: rakam),
          // Only the last session can be changed (the chain must stay consistent).
          if (sahip && oturum.son) ...[
            const SizedBox(width: 4),
            PopupMenuButton<bool>(
              tooltip: 'Son oturumu düzenle ya da sil',
              icon: Icon(LucideIcons.pencil, size: 18, color: tema.colorScheme.onSurfaceVariant),
              onSelected: (duzenle) => duzenle ? _duzenle(context) : _sil(context),
              itemBuilder: (_) => const [
                PopupMenuItem(value: true, child: Text('Düzenle')),
                PopupMenuItem(value: false, child: Text('Son oturumu sil')),
              ],
            ),
          ] else
            const SizedBox(width: 52),
        ],
      ),
    );
  }
}

class _OturumDuzenleDialogu extends StatefulWidget {
  const _OturumDuzenleDialogu({required this.oturum, this.toplam});

  final Oturum oturum;
  final double? toplam;

  @override
  State<_OturumDuzenleDialogu> createState() => _OturumDuzenleDialoguState();
}

class _OturumDuzenleDialoguState extends State<_OturumDuzenleDialogu> {
  final _form = GlobalKey<FormState>();
  late final _konum = TextEditingController(text: sayiMetni(widget.oturum.bitisKonum));
  late final _dakika = TextEditingController(text: widget.oturum.dakika?.toString() ?? '');

  @override
  void dispose() {
    _konum.dispose();
    _dakika.dispose();
    super.dispose();
  }

  void _tamam() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, (sayiCoz(_konum.text)!, int.tryParse(_dakika.text.trim())));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Son oturumu düzenle'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _konum,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: InputDecoration(
                labelText: 'Bitiş konumu',
                helperText: 'Başlangıç: ${sayiMetni(widget.oturum.baslangicKonum)}',
              ),
              validator: (v) => konumDogrula(v, baslangic: widget.oturum.baslangicKonum, toplam: widget.toplam),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dakika,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Süre (dakika, isteğe bağlı)'),
              validator: dakikaDogrula,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(onPressed: _tamam, child: const Text('Kaydet')),
      ],
    );
  }
}
