import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/beyin.dart';
import '../core/beyin_hata.dart';
import '../core/widgets.dart';
import 'ara_view_model.dart';

/// Where a search hit opens: `/not?yol=<path>`.
String notRotasi(String yol) => Uri(path: '/not', queryParameters: {'yol': yol}).toString();

class AraScreen extends StatefulWidget {
  const AraScreen({super.key, required this.viewModel});

  final AraViewModel viewModel;

  @override
  State<AraScreen> createState() => _AraScreenState();
}

class _AraScreenState extends State<AraScreen> {
  final _alan = TextEditingController();

  AraViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _alan.text = _vm.sorgu;
  }

  @override
  void dispose() {
    _alan.dispose();
    super.dispose();
  }

  void _ara() {
    FocusScope.of(context).unfocus();
    _vm.ara(_alan.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ara')),
      body: OrtaGenislik(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _alan,
                textInputAction: TextInputAction.search,
                maxLength: AraViewModel.enUzunSorgu,
                buildCounter: (context, {required currentLength, required isFocused, required maxLength}) => null,
                onSubmitted: (_) => _ara(),
                decoration: InputDecoration(
                  hintText: 'Beyinde ara',
                  prefixIcon: const Icon(LucideIcons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Ara',
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: const Icon(LucideIcons.arrowRight),
                    onPressed: _ara,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _vm,
                builder: (context, _) => _sonuc(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sonuc(BuildContext context) {
    final hata = _vm.hata;
    final sonuclar = _vm.sonuclar;
    if (_vm.yukleniyor) return const YuklemeIskeleti(adet: 3, yukseklik: 72);
    if (hata != null) return BeyinHataDurumu(hata: hata, onTekrar: _vm.tekrar);
    if (sonuclar == null) {
      return const BosDurum(ikon: LucideIcons.search, metin: 'Notlarda, görevlerde ve günlükte ara.');
    }
    if (sonuclar.isEmpty) {
      return BosDurum(ikon: LucideIcons.searchX, metin: '"${_vm.sorgu}" için sonuç yok.');
    }
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      // Room for the floating "Yakala" button under the last row.
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: sonuclar.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _Sonuc(sonuclar[i]),
    );
  }
}

class _Sonuc extends StatelessWidget {
  const _Sonuc(this.sonuc);

  final AramaSonucu sonuc;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    final konum = [if (sonuc.proje != null) sonuc.proje!, if (sonuc.alan != null && sonuc.proje == null) sonuc.alan!].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(notRotasi(sonuc.yol)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sonuc.baslik, style: tema.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              if (sonuc.alinti != null && sonuc.alinti!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(sonuc.alinti!, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: soluk)),
              ],
              if (konum.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(LucideIcons.folder, size: 14, color: tema.colorScheme.primary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(konum, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: tema.colorScheme.primary)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
