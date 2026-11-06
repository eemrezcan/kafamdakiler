import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/hatirlatici.dart';
import '../../routing/router.dart';
import '../../utils/hatirlatici_gorunum.dart';
import 'yaklasanlar_view_model.dart';

/// Upcoming reminders (overdue ones first, then the next 7 days) with the days left. Tapping goes to the list.
/// Hidden until the first answer, and when the read failed.
class YaklasanlarKarti extends StatelessWidget {
  const YaklasanlarKarti({super.key, required this.viewModel});

  final YaklasanlarViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final liste = viewModel.liste;
        if (liste == null) return const SizedBox.shrink();
        final tema = Theme.of(context);
        final soluk = tema.colorScheme.onSurfaceVariant;
        final simdi = viewModel.simdi;
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push(Rotalar.hatirlaticilar),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Yaklaşanlar', style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      Text('Tümü', style: TextStyle(color: tema.colorScheme.primary)),
                      Icon(LucideIcons.chevronRight, color: tema.colorScheme.primary),
                    ],
                  ),
                  if (liste.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 8),
                      child: Text('Önümüzdeki 7 günde hatırlatıcı yok.', style: TextStyle(color: soluk)),
                    ),
                  for (final h in liste) _Satir(h: h, simdi: simdi),
                  if (viewModel.fazla > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 8),
                      child: Text('+ ${viewModel.fazla} tane daha', style: TextStyle(fontSize: 12, color: soluk)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Satir extends StatelessWidget {
  const _Satir({required this.h, required this.simdi});

  final Hatirlatici h;
  final DateTime simdi;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final gecikmis = h.gecikmis(simdi);
    final renk = gecikmis ? tema.colorScheme.error : tema.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 8),
      child: Row(
        children: [
          Expanded(child: Text(h.baslik, maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Text(
            kalanGunMetni(h.kalanGun(simdi)),
            style: TextStyle(fontSize: 12, fontWeight: gecikmis ? FontWeight.w600 : FontWeight.w400, color: renk),
          ),
        ],
      ),
    );
  }
}
