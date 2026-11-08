import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/models/gelen.dart';
import '../../data/models/yakalama.dart';
import '../../data/repositories/kullanici_repository.dart';
import '../../utils/eylem_gorunum.dart';
import '../ara/ara_dugmesi.dart';
import '../bugun/onay_bekleyen_karti.dart';
import '../bugun/onay_bekleyen_view_model.dart';
import '../core/renkler.dart';
import '../core/widgets.dart';
import 'gelen_isle_dialog.dart';
import 'gelen_liste_view_model.dart';
import 'gonderiliyor_satiri.dart';

/// The inbox, a tab, in two parts: "Gönderiliyor" (captures not in the brain yet; edit, delete) and "Yerleşmeyi bekliyor" (the
/// brain's cards). When actions wait in the approval queue a card at the top opens it. Each card shows Claude's suggestion under it: swipe right to
/// approve it, swipe left to look at it later, tap for the preview (correct, place by hand, delete, ask again).
/// Deciding is for the Sahip (K-0009); other users only read.
class GelenListeScreen extends StatelessWidget {
  const GelenListeScreen({super.key, required this.viewModel, this.onayBekleyen});

  final GelenListeViewModel viewModel;

  /// The "Onay bekleyen N" card at the top; it hides itself when nothing waits. Without it the card is not there.
  final OnayBekleyenViewModel? onayBekleyen;

  void _ileti(BuildContext context, String metin) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(metin)));

  Future<void> _elleYerlestir(BuildContext context, GelenKarti kart) async {
    final projeler = await viewModel.projeler();
    final secenekler = await viewModel.secenekler();
    if (!context.mounted) return;
    final girdi = await gelenIsleDialogGoster(context, kart: kart, projeler: projeler, secenekler: secenekler);
    if (girdi != null) await viewModel.isle(kart.kimlik, girdi);
  }

  Future<void> _sil(BuildContext context, GelenKarti kart) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kart silinsin mi?'),
        content: const Text('Bu kart ve görseli kalıcı olarak silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
        ],
      ),
    );
    if (onay == true) await viewModel.sil(kart.kimlik);
  }

  Future<void> _yakalamaSil(BuildContext context, YakalamaSatiri s) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Yakalama silinsin mi?'),
        content: Text(s.konum == YakalamaKonumu.telefonda
            ? 'Henüz gönderilmedi; silersen sunucuya hiçbir şey gitmez.'
            : 'Sunucudaki kayıt da silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
        ],
      ),
    );
    if (onay == true) await viewModel.yakalamaSil(s.id);
  }

  Future<void> _yenidenOner(BuildContext context, GelenKarti kart) async {
    _ileti(context, 'Claude\'a soruluyor; biraz sürebilir…');
    final mesaj = await viewModel.oneriIste(kart.kimlik);
    if (context.mounted) _ileti(context, mesaj);
  }

  Future<void> _onizle(BuildContext context, GelenKarti kart, {required bool karar}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => _Onizleme(
        kart: kart,
        karar: karar,
        onUygula: () async {
          Navigator.pop(sheet);
          await viewModel.uygula(kart);
        },
        onDuzelt: () {
          Navigator.pop(sheet);
          context.push('/eylem/${kart.oneri!.eylemId}');
        },
        onReddet: () async {
          Navigator.pop(sheet);
          await viewModel.reddet(kart);
        },
        onElle: () async {
          Navigator.pop(sheet);
          await _elleYerlestir(context, kart);
        },
        onSil: () async {
          Navigator.pop(sheet);
          await _sil(context, kart);
        },
        yenidenOnerebilir: viewModel.asistanBagli,
        onYenidenOner: () async {
          Navigator.pop(sheet);
          await _yenidenOner(context, kart);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sahip = context.watch<KullaniciRepository>().sahip;
    return Scaffold(
      appBar: AppBar(title: const Text('Gelen'), actions: const [AraDugmesi()]),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          // First load still running: nothing to lay out yet.
          if (viewModel.liste == null && viewModel.yukleniyor) return const YuklemeIskeleti(yukseklik: 96);
          final tema = Theme.of(context);
          final kartlar = viewModel.kartlar;
          final gonderiliyor = viewModel.gonderiliyor;
          // The cards could not be read (or are not there to read offline): say why in their own part, so "Gönderiliyor" above
          // still shows. Offline with cached cards, the cards show with a note instead.
          final kartlarAlinamadi = viewModel.liste == null ||
              viewModel.liste!.isEmpty && (viewModel.hata != null || viewModel.cevrimdisi);
          return RefreshIndicator(
            onRefresh: () => Future.wait([viewModel.yukle(), if (onayBekleyen != null) onayBekleyen!.yukle()]),
            child: OrtaGenislik(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  if (onayBekleyen != null) OnayBekleyenKarti(viewModel: onayBekleyen!),
                  if (viewModel.cevrimdisi && kartlar.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Çevrimdışısın; kararların telefona yazılıyor, bağlantı gelince gönderilecek.',
                        style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  // Most of the time nothing is on its way, and then the part is not drawn at all.
                  if (gonderiliyor.isNotEmpty) ...[
                    _Baslik('GÖNDERİLİYOR  ${gonderiliyor.length}'),
                    for (final s in gonderiliyor)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GonderiliyorSatiri(satir: s, onSil: () => _yakalamaSil(context, s)),
                      ),
                    const SizedBox(height: 8),
                  ],
                  _Baslik(kartlarAlinamadi ? 'YERLEŞMEYİ BEKLİYOR' : 'YERLEŞMEYİ BEKLİYOR  ${kartlar.length}'),
                  if (kartlarAlinamadi)
                    _KartlarAlinamadi(
                      metin: viewModel.cevrimdisi ? 'Bağlantı yok; bağlantı gelince kartlar burada görünür.' : viewModel.hata ?? 'Liste alınamadı.',
                      onTekrar: viewModel.yukle,
                    )
                  else ...[
                    if (viewModel.hata != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(viewModel.hata!, style: TextStyle(color: tema.colorScheme.error)),
                      ),
                    if (kartlar.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Gelen kutusu boş.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    for (final k in kartlar)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _KartSatiri(
                          kart: k,
                          karar: sahip,
                          sonra: viewModel.sonraMi(k.kimlik),
                          onAc: () => _onizle(context, k, karar: sahip),
                          onUygula: () => viewModel.uygula(k),
                          onSonra: () async => viewModel.sonraBak(k.kimlik),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Baslik extends StatelessWidget {
  const _Baslik(this.metin);

  final String metin;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(metin, style: tema.textTheme.labelSmall?.copyWith(color: tema.colorScheme.onSurfaceVariant, letterSpacing: 0.8)),
    );
  }
}

/// The cards part when the list is not there: offline, or the server said no. Retry stays within the part.
class _KartlarAlinamadi extends StatelessWidget {
  const _KartlarAlinamadi({required this.metin, required this.onTekrar});

  final String metin;
  final Future<void> Function() onTekrar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(metin, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          TextButton(onPressed: onTekrar, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }
}

/// A card with its suggestion. For the Sahip, a card that has a suggestion can be swiped: right approves it, left puts it
/// aside; the swipe never removes the card by itself (the list reloads and does that).
class _KartSatiri extends StatelessWidget {
  const _KartSatiri({required this.kart, required this.karar, required this.sonra, required this.onAc, required this.onUygula, required this.onSonra});

  final GelenKarti kart;
  final bool karar;
  final bool sonra;
  final VoidCallback onAc;
  final Future<void> Function() onUygula;
  final Future<void> Function() onSonra;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    final o = kart.oneri;

    final icerik = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAc,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(kart.ozet, style: tema.textTheme.titleMedium, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (kart.yakalandi != null) _Isaret(ikon: LucideIcons.clock, metin: kart.yakalandi!.replaceFirst('T', ' '), renk: soluk),
                  if (kart.hedef != null) _Isaret(ikon: LucideIcons.target, metin: kart.hedef!, renk: soluk),
                  if (kart.gorselVar) _Isaret(ikon: LucideIcons.image, metin: 'Görselli', renk: soluk),
                  if (kart.laptoptaIslenecek) _Isaret(ikon: LucideIcons.laptop, metin: 'Laptopta işlenecek', renk: tema.colorScheme.tertiary),
                  if (sonra) _Isaret(ikon: LucideIcons.clock3, metin: 'Sonra', renk: soluk),
                ],
              ),
              if (kart.laptoptaIslenecek && kart.laptopNotu != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(kart.laptopNotu!, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: soluk)),
                ),
              if (o != null) ...[
                const Divider(height: 20),
                _OneriOzeti(oneri: o),
              ],
            ],
          ),
        ),
      ),
    );

    if (!karar || o == null) return icerik;

    return Dismissible(
      key: ValueKey('gelen-${kart.kimlik}'),
      confirmDismiss: (yon) async {
        if (yon == DismissDirection.startToEnd) {
          await onUygula();
        } else {
          await onSonra();
        }
        return false;
      },
      background: _Arka(hizalama: Alignment.centerLeft, renk: tamamRengi(context).withValues(alpha: 0.25), ikon: LucideIcons.check, etiket: 'Uygula'),
      secondaryBackground: _Arka(hizalama: Alignment.centerRight, renk: tema.colorScheme.surfaceContainerHighest, ikon: LucideIcons.clock3, etiket: 'Sonra'),
      child: icerik,
    );
  }
}

/// Where Claude would put the card, with the warnings.
class _OneriOzeti extends StatelessWidget {
  const _OneriOzeti({required this.oneri});

  final GelenOneri oneri;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _Isaret(ikon: LucideIcons.sparkles, metin: 'Öneri', renk: tema.colorScheme.primary),
            if (oneri.disKaynak) _Isaret(ikon: LucideIcons.triangleAlert, metin: 'Dış kaynak', renk: tema.colorScheme.error),
            if (oneri.guven != null)
              _Isaret(
                ikon: LucideIcons.gauge,
                metin: oneri.eminDegil ? 'Emin değil · ${eylemGuvenMetni(oneri.guven!)}' : 'Güven ${eylemGuvenMetni(oneri.guven!)}',
                renk: oneri.eminDegil ? tema.colorScheme.error : soluk,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(oneri.yol, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(oneri.baslik),
        if (oneri.etiketler.isNotEmpty) Text(oneri.etiketler.map((e) => '#$e').join(' '), style: TextStyle(fontSize: 12, color: soluk)),
        if (oneri.gerekce != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(oneri.gerekce!, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: soluk)),
          ),
      ],
    );
  }
}

/// The preview: the card and its suggestion in full, and what can be done with them.
class _Onizleme extends StatelessWidget {
  const _Onizleme({
    required this.kart,
    required this.karar,
    required this.onUygula,
    required this.onDuzelt,
    required this.onReddet,
    required this.onElle,
    required this.onSil,
    required this.yenidenOnerebilir,
    required this.onYenidenOner,
  });

  final GelenKarti kart;
  final bool karar;
  final Future<void> Function() onUygula;
  final VoidCallback onDuzelt;
  final Future<void> Function() onReddet;
  final Future<void> Function() onElle;
  final Future<void> Function() onSil;
  final bool yenidenOnerebilir;
  final Future<void> Function() onYenidenOner;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final o = kart.oneri;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kart.ozet, style: tema.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (kart.yakalandi != null) Text('Yakalandı: ${kart.yakalandi!.replaceFirst('T', ' ')}'),
            if (kart.hedef != null) Text('Hedef ipucu: ${kart.hedef}'),
            if (kart.gorselVar) const Text('Görselli kart; görsel Claude\'a gönderilmez.'),
            if (kart.laptoptaIslenecek) Text('Laptopta işlenecek: ${kart.laptopNotu ?? 'karta uyan etiket sözlükte yok.'}'),
            if (o != null) ...[
              const Divider(height: 24),
              _OneriOzeti(oneri: o),
            ],
            if (karar) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (o != null) ...[
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: onUygula,
                      icon: const Icon(LucideIcons.check),
                      label: const Text('Uygula'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: onDuzelt,
                      icon: const Icon(LucideIcons.pencil),
                      label: const Text('Düzelt'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: onReddet,
                      icon: const Icon(LucideIcons.x),
                      label: const Text('Reddet'),
                    ),
                  ],
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                    onPressed: onElle,
                    icon: const Icon(LucideIcons.folderInput),
                    label: const Text('Elle yerleştir'),
                  ),
                  if (o == null && yenidenOnerebilir)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: onYenidenOner,
                      icon: const Icon(LucideIcons.sparkles),
                      label: const Text('Yeniden öner'),
                    ),
                  TextButton.icon(
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: tema.colorScheme.error),
                    onPressed: onSil,
                    icon: const Icon(LucideIcons.trash2),
                    label: const Text('Sil'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Arka extends StatelessWidget {
  const _Arka({required this.hizalama, required this.renk, required this.ikon, required this.etiket});

  final Alignment hizalama;
  final Color renk;
  final IconData ikon;
  final String etiket;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: hizalama,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(12)),
      child: Icon(ikon, semanticLabel: etiket),
    );
  }
}

class _Isaret extends StatelessWidget {
  const _Isaret({required this.ikon, required this.metin, required this.renk});

  final IconData ikon;
  final String metin;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ikon, size: 14, color: renk),
        const SizedBox(width: 4),
        Flexible(child: Text(metin, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: renk))),
      ],
    );
  }
}
