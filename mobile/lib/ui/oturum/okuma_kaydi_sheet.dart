import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/models/aliskanlik.dart';
import '../../data/models/oge.dart';
import '../../data/repositories/aliskanlik_repository.dart';
import '../../data/repositories/esitleyici.dart';
import '../../utils/dogrulama.dart';
import '../core/ikonlar.dart';
import '../core/widgets.dart';
import 'okuma_kaydi_view_model.dart';

/// "Okuma kaydı" (K-0024): opened from the shelf ring on Bugün and from the shelf card on Alışkanlıklar. Which book (the ones in
/// progress, or "Raftan seç"), how far, how long, "Kitabı bitirdim", and the stopwatch as another way in.
Future<void> okumaKaydiAc(BuildContext context, {required Aliskanlik aliskanlik, String? ogeId}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ChangeNotifierProvider(
      create: (c) => OkumaKaydiViewModel(
        repo: c.read<AliskanlikRepository>(),
        esitleyici: c.read<Esitleyici>(),
        aliskanlik: aliskanlik,
        ogeId: ogeId,
      ),
      child: Builder(builder: (c) => OkumaKaydiSayfasi(viewModel: c.read<OkumaKaydiViewModel>(), kok: context)),
    ),
  );
}

class OkumaKaydiSayfasi extends StatefulWidget {
  const OkumaKaydiSayfasi({super.key, required this.viewModel, required this.kok});

  final OkumaKaydiViewModel viewModel;

  /// The context of the screen under the sheet: pages are pushed with it after the sheet closes.
  final BuildContext kok;

  @override
  State<OkumaKaydiSayfasi> createState() => _OkumaKaydiSayfasiState();
}

class _OkumaKaydiSayfasiState extends State<OkumaKaydiSayfasi> {
  late final _konum = TextEditingController(text: sayiMetni(_vm.konum));

  OkumaKaydiViewModel get _vm => widget.viewModel;
  Aliskanlik get _a => _vm.aliskanlik;

  @override
  void dispose() {
    _konum.dispose();
    super.dispose();
  }

  void _konumuYansit() => _konum.text = sayiMetni(_vm.konum);

  void _sec(String id) {
    _vm.sec(id);
    _konumuYansit();
  }

  void _adim(double d) {
    _vm.konumArttir(d);
    _konumuYansit();
  }

  Future<void> _elleSure() async {
    final dakika = await showDialog<int>(context: context, builder: (_) => const _SureDialogu());
    if (dakika != null) _vm.sureYaz(dakika);
  }

  void _git(String rota) {
    final router = GoRouter.of(widget.kok);
    Navigator.pop(context);
    router.push(rota);
  }

  Future<void> _kaydet() async {
    if (!_vm.kaydetmeyeHazir()) return;
    final nav = Navigator.of(context);
    final mesaj = ScaffoldMessenger.of(widget.kok);
    final sonuc = await _vm.kaydet();
    nav.pop();
    mesaj
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(sonuc == OkumaKaydiSonucu.bitirilemedi
            ? 'Okuma kaydedildi; kitabı bitti olarak işaretlemek için bağlantı gerekli. Kitabın sayfasından işaretleyebilirsin.'
            : 'Okuma kaydedildi'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    final birim = _a.birim ?? 'sayfa';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          final secili = _vm.secili;
          final hata = _vm.gorunenHata;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Okuma kaydı', style: tema.textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(
                  '${_a.ad} · bugün ${sayiMetni(_a.bugun?.miktar ?? 0)}${_a.gunlukHedef == null ? '' : ' / ${sayiMetni(_a.gunlukHedef)}'} $birim',
                  style: tema.textTheme.bodyMedium?.copyWith(color: soluk),
                ),
                const SizedBox(height: 16),
                Text('Hangi ${(_a.ogeEtiketi ?? 'öğe').toLowerCase()}?', style: tema.textTheme.labelLarge),
                const SizedBox(height: 8),
                SizedBox(
                  height: 116,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final k in _vm.kitaplar) _Kitap(oge: k, secili: k.id == secili?.id, birim: birim, ikon: lucideIkonu(_a.ikon), onTap: () => _sec(k.id)),
                      _RaftanSec(onTap: () => _git('/aliskanlik/${_a.id}/raf')),
                    ],
                  ),
                ),
                if (secili == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Devam eden ${(_a.ogeEtiketi ?? 'öğe').toLowerCase()} yok. Raftan bir tane seç.', style: TextStyle(color: soluk)),
                  )
                else ...[
                  const SizedBox(height: 12),
                  Text(
                    'Nereye kadar geldin? (${sayiMetni(secili.guncelKonum)}${secili.toplam == null ? '' : ' / ${sayiMetni(secili.toplam)}'})',
                    style: tema.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      IconButton.outlined(
                        key: const ValueKey('okuma-eksi'),
                        tooltip: 'Bir azalt',
                        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                        icon: const Icon(LucideIcons.minus),
                        onPressed: () => _adim(-1),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('okuma-konum'),
                          controller: _konum,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: tema.textTheme.titleMedium,
                          onChanged: (v) {
                            final s = sayiCoz(v);
                            if (s != null) _vm.konumYaz(s);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        key: const ValueKey('okuma-arti'),
                        tooltip: 'Bir artır',
                        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                        icon: const Icon(LucideIcons.plus),
                        onPressed: () => _adim(1),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      hata ?? _farkMetni(birim),
                      key: const ValueKey('okuma-fark'),
                      style: tema.textTheme.bodySmall?.copyWith(color: hata == null ? soluk : tema.colorScheme.error),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Ne kadar sürdü? (isteğe bağlı)', style: tema.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final dk in OkumaKaydiViewModel.sureSecenekleri)
                        ChoiceChip(
                          key: ValueKey('okuma-sure-$dk'),
                          label: Text('$dk dk'),
                          selected: _vm.dakika == dk,
                          onSelected: (s) => _vm.sureYaz(s ? dk : null),
                        ),
                      ActionChip(
                        key: const ValueKey('okuma-sure-elle'),
                        label: Text(_vm.dakika != null && !OkumaKaydiViewModel.sureSecenekleri.contains(_vm.dakika) ? '${_vm.dakika} dk' : 'Elle…'),
                        onPressed: _elleSure,
                      ),
                    ],
                  ),
                  SwitchListTile(
                    key: const ValueKey('okuma-bitti'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(_a.ogeEtiketi == 'Kitap' ? 'Kitabı bitirdim' : 'Bitirdim'),
                    value: _vm.bitti,
                    onChanged: _vm.bittiYaz,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (secili != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('okuma-kronometre'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          onPressed: () => _git('/oge/${secili.id}/oturum'),
                          icon: const Icon(LucideIcons.timer, size: 18),
                          label: const Text('Kronometre'),
                        ),
                      ),
                    if (secili != null) const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('okuma-kaydet'),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: _vm.kaydedilebilir ? _kaydet : null,
                        child: const Text('Kaydet'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// "bugün +18 sayfa → hedefe 12 sayfa kaldı" / "hedefe ulaştın".
  String _farkMetni(String birim) {
    final f = _vm.fark;
    final kalan = _vm.hedefKalan;
    final bas = f == 0 ? 'Henüz ilerleme yok' : 'bu kayıtta +${sayiMetni(f)} $birim';
    if (kalan == null) return bas;
    return '$bas → ${kalan == 0 ? 'günün hedefine ulaştın' : 'hedefe ${sayiMetni(kalan)} $birim kaldı'}';
  }
}

class _Kitap extends StatelessWidget {
  const _Kitap({required this.oge, required this.secili, required this.birim, required this.ikon, required this.onTap});

  final OgeOzet oge;
  final bool secili;
  final String birim;
  final IconData ikon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Semantics(
      button: true,
      selected: secili,
      label: '${oge.ad}, ${sayiMetni(oge.guncelKonum)} $birim',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('okuma-kitap-${oge.id}'),
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 88,
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: secili ? tema.colorScheme.primary : Colors.transparent, width: 2),
            color: secili ? tema.colorScheme.primary.withValues(alpha: 0.08) : null,
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: SizedBox(width: 44, height: 62, child: ApiResim(dosyaId: dosyaIdUrlden(oge.fotografUrl), yedekIkon: ikon)),
              ),
              const SizedBox(height: 4),
              Text(oge.ad, maxLines: 1, overflow: TextOverflow.ellipsis, style: tema.textTheme.labelSmall),
              Text(sayiMetni(oge.guncelKonum), style: tema.textTheme.labelSmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaftanSec extends StatelessWidget {
  const _RaftanSec({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return InkWell(
      key: const ValueKey('okuma-raf'),
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: SizedBox(
        width: 88,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 62,
              decoration: BoxDecoration(color: tema.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(5)),
              child: Icon(LucideIcons.plus, color: tema.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text('Raftan seç', style: tema.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

/// "Elle…": minutes typed by hand. The dialog owns its controller.
class _SureDialogu extends StatefulWidget {
  const _SureDialogu();

  @override
  State<_SureDialogu> createState() => _SureDialoguState();
}

class _SureDialoguState extends State<_SureDialogu> {
  final _denetleyici = TextEditingController();
  String? _hata;

  @override
  void dispose() {
    _denetleyici.dispose();
    super.dispose();
  }

  void _tamam() {
    final hata = dakikaDogrula(_denetleyici.text);
    if (hata != null) return setState(() => _hata = hata);
    Navigator.pop(context, int.tryParse(_denetleyici.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kaç dakika?'),
      content: TextField(
        key: const ValueKey('okuma-sure-alan'),
        controller: _denetleyici,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(suffixText: 'dk', errorText: _hata),
        onSubmitted: (_) => _tamam(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(onPressed: _tamam, child: const Text('Tamam')),
      ],
    );
  }
}
