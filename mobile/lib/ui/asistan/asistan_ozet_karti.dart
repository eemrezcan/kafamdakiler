import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../routing/router.dart';
import 'asistan_pano_view_model.dart';

/// "Asistan" on the Bugün tab: the numbers of the work cards (waiting on the person, at the VPS, finished this week) and the
/// titles of the first two that wait; tapping opens the board. Hidden until the first answer and when the read failed with
/// nothing kept on the phone.
class AsistanOzetKarti extends StatelessWidget {
  const AsistanOzetKarti({super.key, required this.viewModel});

  final AsistanOzetViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final veri = viewModel.veri;
        if (veri == null) return const SizedBox.shrink();
        final tema = Theme.of(context);
        final soluk = TextStyle(color: tema.colorScheme.onSurfaceVariant);
        final basliklar = viewModel.ilkBasliklar;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push(Rotalar.asistan),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: [
                    Icon(LucideIcons.bot, color: tema.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Asistan', style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            'Sende bekleyen ${viewModel.sende} · VPS\'te ${viewModel.vpste} · Bu hafta biten ${viewModel.buHaftaBiten}',
                            style: soluk,
                          ),
                          for (final b in basliklar)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('• $b', maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          if (veri.cevrimdisi) Text('Çevrimdışı: son indirilen', style: soluk),
                        ],
                      ),
                    ),
                    Icon(LucideIcons.chevronRight, color: tema.colorScheme.primary),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
