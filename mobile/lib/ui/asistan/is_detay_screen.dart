import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/is_karti.dart';
import '../../utils/is_gorunum.dart';
import '../core/beyin_hata.dart';
import '../core/widgets.dart';
import 'is_detay_view_model.dart';

/// One work card: request, plan, questions (answered with one tap on an option, or with the person's own words: the "Kendi
/// cevabım" box is always under the options), history, and the stage buttons. At a gate "Onayla" moves the card on (the server
/// adds the approval); "Plana geri gönder" (a revision, which asks for a short note and is never sent without one) and "İptal"
/// (with a reason) are there while the card allows them. With no connection, or for someone who may not write, the buttons are shut.
class IsDetayScreen extends StatelessWidget {
  const IsDetayScreen({super.key, required this.viewModel});

  final IsDetayViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final veri = viewModel.veri;
        return Scaffold(
          appBar: AppBar(title: Text(veri?.kart.baslik ?? 'İş kartı', overflow: TextOverflow.ellipsis)),
          body: veri == null
              ? (viewModel.hata != null
                  ? BeyinHataDurumu(hata: viewModel.hata!, onTekrar: viewModel.yukle)
                  : const YuklemeIskeleti(adet: 3, yukseklik: 96))
              : RefreshIndicator(
                  onRefresh: viewModel.yukle,
                  child: OrtaGenislik(child: _Icerik(viewModel: viewModel, ayrinti: veri)),
                ),
        );
      },
    );
  }
}

class _Icerik extends StatelessWidget {
  const _Icerik({required this.viewModel, required this.ayrinti});

  final IsDetayViewModel viewModel;
  final IsAyrinti ayrinti;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    final kart = ayrinti.kart;
    Widget baslik(String metin) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(metin, style: tema.textTheme.titleSmall?.copyWith(color: soluk)),
        );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Chip(label: Text(asamaEtiketi(kart.asama)), visualDensity: VisualDensity.compact),
            Chip(label: Text(sahipEtiketi(kart.sahip)), visualDensity: VisualDensity.compact),
            if (kart.yer.isNotEmpty) Chip(label: Text(kart.yer), visualDensity: VisualDensity.compact),
            Chip(label: Text(kart.tip), visualDensity: VisualDensity.compact),
          ],
        ),
        if (viewModel.mesaj != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(viewModel.mesaj!, style: TextStyle(color: tema.colorScheme.error)),
          ),
        if (viewModel.cevrimdisi)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Çevrimdışısın; yazma düğmeleri kapalı. Bağlantı gelince kartı yenile.', style: TextStyle(color: soluk)),
          ),
        _Dugmeler(viewModel: viewModel, kart: kart),
        baslik('Talep'),
        ayrinti.talep.trim().isEmpty ? Text('Talep metni yok.', style: TextStyle(color: soluk)) : SelectableText(ayrinti.talep.trim()),
        baslik('Plan'),
        ayrinti.plan.trim().isEmpty
            ? Text('Plan henüz yazılmadı.', style: TextStyle(color: soluk))
            : MarkdownBody(
                data: ayrinti.plan.trim(),
                selectable: true,
                // Nothing is fetched from the network for a plan: an image shows its alt text.
                imageBuilder: (uri, baslik, alt) => Text(alt ?? 'Görsel', style: TextStyle(color: soluk)),
              ),
        baslik('Sorular'),
        if (ayrinti.sorular.isEmpty) Text('Soru yok.', style: TextStyle(color: soluk)),
        for (final s in ayrinti.sorular) _Soru(viewModel: viewModel, soru: s),
        baslik('Geçmiş'),
        if (ayrinti.gecmis.isEmpty) Text('Geçmiş satırı yok.', style: TextStyle(color: soluk)),
        for (final g in ayrinti.gecmis.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 96, child: Text(g.zaman, style: TextStyle(fontSize: 12, color: soluk))),
                Expanded(child: Text('${g.olay}${g.kim.isEmpty ? '' : ' · ${g.kim}'}')),
              ],
            ),
          ),
      ],
    );
  }
}

/// The stage buttons. Only the ones the card allows from here are shown; [IsDetayViewModel.yazmaAcik] decides if they work.
class _Dugmeler extends StatelessWidget {
  const _Dugmeler({required this.viewModel, required this.kart});

  final IsDetayViewModel viewModel;
  final IsKarti kart;

  Future<void> _onayla(BuildContext context, String sonraki) async {
    // A push or a deploy cannot be taken back: it is asked once more. The code gate is the cheaper one (and has a notification button).
    if (kart.asama != 'kod-onayi') {
      final tamam = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${asamaEtiketi(kart.asama)} verilsin mi?'),
          content: const Text('Planı ve geçmişi gördün; onay kartı bir sonraki aşamaya taşır.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Onayla')),
          ],
        ),
      );
      if (tamam != true) return;
    }
    await viewModel.asamaDegistir(sonraki);
  }

  /// A revision: the card goes back to the plan with a note for whoever works on it. The server refuses it without one, so the
  /// window does not close on an empty note.
  Future<void> _revizyon(BuildContext context) async {
    final not = await showDialog<String>(context: context, builder: (context) => const _NotDialogu());
    if (not != null) await viewModel.asamaDegistir('plan', not: not);
  }

  Future<void> _iptal(BuildContext context) async {
    final gerekce = await showDialog<String>(context: context, builder: (context) => const _GerekceDialogu());
    if (gerekce != null) await viewModel.asamaDegistir('iptal', gerekce: gerekce);
  }

  @override
  Widget build(BuildContext context) {
    if (!kart.acik) return const SizedBox.shrink();
    final acik = viewModel.yazmaAcik;
    final sonraki = kapidanSonraki(kart.asama);
    final onaylanabilir = kapidaMi(kart) && sonraki != null && kart.gecisler.contains(sonraki);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (onaylanabilir)
            FilledButton.icon(
              onPressed: acik ? () => _onayla(context, sonraki) : null,
              icon: const Icon(LucideIcons.check),
              label: Text(onayEtiketi(kart.asama)),
            ),
          // From the request stage the plan is the next step, not a revision: no note.
          if (kart.gecisler.contains('plan') && kart.asama == 'talep')
            OutlinedButton.icon(
              key: const ValueKey('is-plana-al'),
              onPressed: acik ? () => viewModel.asamaDegistir('plan') : null,
              icon: const Icon(LucideIcons.arrowRight),
              label: const Text('Plana al'),
            )
          else if (kart.gecisler.contains('plan'))
            OutlinedButton.icon(
              key: const ValueKey('is-plana-geri'),
              onPressed: acik ? () => _revizyon(context) : null,
              icon: const Icon(LucideIcons.undo2),
              label: const Text('Plana geri gönder'),
            ),
          if (kart.gecisler.contains('iptal'))
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: acik ? () => _iptal(context) : null,
              icon: const Icon(LucideIcons.x),
              label: const Text('İptal et'),
            ),
        ],
      ),
    );
  }
}

/// The note of a revision: required, short. The window owns its controller.
class _NotDialogu extends StatefulWidget {
  const _NotDialogu();

  @override
  State<_NotDialogu> createState() => _NotDialoguState();
}

class _NotDialoguState extends State<_NotDialogu> {
  final _kontrol = TextEditingController();
  String? _hata;

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  void _tamam() {
    final metin = _kontrol.text.trim();
    if (metin.isEmpty) {
      setState(() => _hata = 'Revizyon için kısa bir not yaz.');
      return;
    }
    Navigator.pop(context, metin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Plana geri gönderilsin mi?'),
      content: TextField(
        key: const ValueKey('revizyon-not'),
        controller: _kontrol,
        autofocus: true,
        maxLength: 300,
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: 'Ne değişsin? (kısa not)', errorText: _hata),
        onChanged: (_) {
          if (_hata != null) setState(() => _hata = null);
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(key: const ValueKey('revizyon-gonder'), onPressed: _tamam, child: const Text('Gönder')),
      ],
    );
  }
}

class _GerekceDialogu extends StatefulWidget {
  const _GerekceDialogu();

  @override
  State<_GerekceDialogu> createState() => _GerekceDialoguState();
}

class _GerekceDialoguState extends State<_GerekceDialogu> {
  final _kontrol = TextEditingController();
  String? _hata;

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  void _tamam() {
    final metin = _kontrol.text.trim();
    if (metin.isEmpty) {
      setState(() => _hata = 'İptal için gerekçe yaz.');
      return;
    }
    Navigator.pop(context, metin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kart iptal edilsin mi?'),
      content: TextField(
        controller: _kontrol,
        autofocus: true,
        maxLength: 300,
        decoration: InputDecoration(labelText: 'Gerekçe', errorText: _hata),
        onChanged: (_) {
          if (_hata != null) setState(() => _hata = null);
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(onPressed: _tamam, child: const Text('İptal et')),
      ],
    );
  }
}

/// A question: the options as chips (the recommended one marked, "neden" opens under it), one tap answers. An answered
/// question is locked and shows the answer. A question with no options takes free text.
class _Soru extends StatefulWidget {
  const _Soru({required this.viewModel, required this.soru});

  final IsDetayViewModel viewModel;
  final IsSorusu soru;

  @override
  State<_Soru> createState() => _SoruState();
}

class _SoruState extends State<_Soru> {
  final _kontrol = TextEditingController();

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final soru = widget.soru;
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    final acik = widget.viewModel.yazmaAcik;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('S${soru.no} · ${soru.soru}', style: tema.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (soru.cevaplandi)
              Row(
                children: [
                  Icon(LucideIcons.lock, size: 16, color: soluk),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Cevap: ${soru.cevap}')),
                ],
              )
            else ...[
              if (soru.secenekler.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in soru.secenekler)
                      ActionChip(
                        avatar: s == soru.onerilen ? const Icon(LucideIcons.star, size: 16) : null,
                        label: Text(s == soru.onerilen ? '$s (önerilen)' : s),
                        onPressed: acik ? () => widget.viewModel.cevapla(soru, s) : null,
                      ),
                  ],
                ),
              // The options are suggestions: the person's own words are always accepted (the server takes any text).
              Padding(
                padding: EdgeInsets.only(top: soru.secenekler.isNotEmpty ? 12 : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: ValueKey('soru-kendi-${soru.no}'),
                        controller: _kontrol,
                        enabled: acik,
                        maxLength: 500,
                        decoration: const InputDecoration(labelText: 'Kendi cevabım'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton(
                        key: ValueKey('soru-kendi-gonder-${soru.no}'),
                        onPressed: acik ? () => widget.viewModel.cevapla(soru, _kontrol.text) : null,
                        child: const Text('Gönder'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (soru.neden != null && soru.neden!.trim().isNotEmpty)
              Theme(
                data: tema.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text('Neden?', style: tema.textTheme.bodyMedium?.copyWith(color: soluk)),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [Align(alignment: Alignment.centerLeft, child: Text(soru.neden!.trim()))],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
