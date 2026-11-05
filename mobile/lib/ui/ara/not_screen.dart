import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/beyin.dart';
import '../core/beyin_hata.dart';
import '../core/widgets.dart';
import 'ara_view_model.dart';

/// A note from the brain, its Markdown shown with the app's theme.
class NotScreen extends StatelessWidget {
  const NotScreen({super.key, required this.viewModel});

  final NotViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final not = viewModel.veri;
        return Scaffold(
          appBar: AppBar(title: Text(not?.baslik ?? 'Not', overflow: TextOverflow.ellipsis)),
          body: not == null
              ? (viewModel.hata != null
                  ? BeyinHataDurumu(hata: viewModel.hata!, onTekrar: viewModel.yukle)
                  : const YuklemeIskeleti(adet: 3, yukseklik: 96))
              : RefreshIndicator(
                  onRefresh: viewModel.yukle,
                  child: OrtaGenislik(child: _Icerik(not: not)),
                ),
        );
      },
    );
  }
}

class _Icerik extends StatelessWidget {
  const _Icerik({required this.not});

  final BeyinNotu not;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurfaceVariant;
    final govde = not.govde.trim();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Text(not.yol, style: TextStyle(fontSize: 12, color: soluk)),
        if (not.etiketler.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final e in not.etiketler) Chip(label: Text(e), visualDensity: VisualDensity.compact)],
          ),
        ],
        const SizedBox(height: 12),
        if (govde.isEmpty)
          Text('Bu notun gövdesi boş.', style: TextStyle(color: soluk))
        else
          MarkdownBody(
            data: govde,
            selectable: true,
            styleSheet: _stil(tema),
            // Nothing is fetched from the network for a note: an image shows its alt text,
            // and links are text (the app has no browser to hand them to).
            imageBuilder: (uri, baslik, alt) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.image, size: 16, color: soluk),
                const SizedBox(width: 6),
                Flexible(child: Text(alt ?? 'Görsel', style: TextStyle(color: soluk))),
              ],
            ),
          ),
      ],
    );
  }

  /// The app's own text styles and hairline colours, not the package defaults.
  MarkdownStyleSheet _stil(ThemeData tema) {
    final renk = tema.colorScheme;
    final satir = BorderSide(color: renk.outlineVariant);
    return MarkdownStyleSheet.fromTheme(tema).copyWith(
      p: tema.textTheme.bodyLarge,
      a: TextStyle(color: renk.primary, decoration: TextDecoration.underline),
      h1: tema.textTheme.headlineSmall,
      h2: tema.textTheme.titleLarge,
      h3: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      code: TextStyle(fontFamily: 'monospace', fontSize: 14, backgroundColor: renk.outlineVariant),
      codeblockDecoration: BoxDecoration(
        color: renk.outlineVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: renk.outline, width: 3)),
      ),
      horizontalRuleDecoration: BoxDecoration(border: Border(top: satir)),
      tableBorder: TableBorder.all(color: renk.outlineVariant),
    );
  }
}
