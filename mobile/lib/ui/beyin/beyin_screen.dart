import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../routing/router.dart';
import '../core/beyin_hata.dart';
import '../core/widgets.dart';
import '../projeler/proje_view_model.dart';
import '../shell/ust_sag.dart';

/// The Beyin tab (K-0024): the one place of search, and the brain's projects. A search opens the results page (a hit opens the
/// note); a project opens its page. Reading the brain is the second thing the app does, so it is the last tab.
class BeyinScreen extends StatefulWidget {
  const BeyinScreen({super.key, required this.viewModel});

  final ProjeListeViewModel viewModel;

  @override
  State<BeyinScreen> createState() => _BeyinScreenState();
}

class _BeyinScreenState extends State<BeyinScreen> {
  final _alan = TextEditingController();

  ProjeListeViewModel get _vm => widget.viewModel;

  @override
  void dispose() {
    _alan.dispose();
    super.dispose();
  }

  /// Opens the results page for the typed words (an empty box opens it empty, ready to type).
  void _ara() {
    final q = _alan.text.trim();
    context.push(q.isEmpty ? Rotalar.ara : Uri(path: Rotalar.ara, queryParameters: {'q': q}).toString());
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('İkinci beyin', style: tema.textTheme.labelSmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
            const Text('Beyin'),
          ],
        ),
        actions: const [UstSagDugmeleri()],
      ),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => RefreshIndicator(
          onRefresh: _vm.yukle,
          child: OrtaGenislik(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                TextField(
                  key: const ValueKey('beyin-ara'),
                  controller: _alan,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _ara(),
                  decoration: InputDecoration(
                    hintText: 'Notlarda, projelerde ara…',
                    prefixIcon: const Icon(LucideIcons.search),
                    suffixIcon: IconButton(
                      key: const ValueKey('beyin-ara-git'),
                      tooltip: 'Ara',
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: const Icon(LucideIcons.arrowRight),
                      onPressed: _ara,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 8),
                  child: Text(
                    'PROJELER',
                    style: tema.textTheme.labelMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant, letterSpacing: 0.8, fontWeight: FontWeight.w600),
                  ),
                ),
                ..._projeler(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _projeler(BuildContext context) {
    final tema = Theme.of(context);
    final sonuc = _vm.veri;
    if (sonuc == null) {
      final hata = _vm.hata;
      if (hata != null) {
        return [SizedBox(height: 280, child: BeyinHataDurumu(hata: hata, onTekrar: _vm.yukle))];
      }
      return [for (var i = 0; i < 3; i++) Container(height: 64, margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: tema.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(10)))];
    }
    // Offline with nothing kept on the phone: say why the list is empty.
    if (sonuc.cevrimdisi && sonuc.liste.isEmpty) {
      return [SizedBox(height: 280, child: BeyinHataDurumu(hata: BeyinHatasi.cevrimdisi, onTekrar: _vm.yukle))];
    }
    if (sonuc.liste.isEmpty) {
      return const [BosKart(key: ValueKey('beyin-proje-yok'), metin: 'Beyinde henüz proje yok.')];
    }
    return [
      if (sonuc.cevrimdisi)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Çevrimdışısın; telefondaki liste gösteriliyor. Ayrıntı için internet gerekir.', style: TextStyle(color: tema.colorScheme.onSurfaceVariant)),
        ),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < sonuc.liste.length; i++) ...[
              if (i > 0) Divider(height: 1, color: tema.colorScheme.outlineVariant),
              ListTile(
                key: ValueKey('beyin-proje-${sonuc.liste[i].kimlik}'),
                minTileHeight: 64,
                leading: const Icon(LucideIcons.folder),
                title: Text(sonuc.liste[i].baslik),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => context.push('/projeler/${Uri.encodeComponent(sonuc.liste[i].kimlik)}'),
              ),
            ],
          ],
        ),
      ),
    ];
  }
}
