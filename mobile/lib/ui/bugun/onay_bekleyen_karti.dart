import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../routing/router.dart';
import 'onay_bekleyen_view_model.dart';

/// "Onay bekleyen N": the number of actions waiting in the approval queue; tapping opens the queue.
/// Hidden until the first answer, when nothing waits, and when the read failed.
class OnayBekleyenKarti extends StatelessWidget {
  const OnayBekleyenKarti({super.key, required this.viewModel});

  final OnayBekleyenViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final sayi = viewModel.sayi;
        if (sayi == null || sayi == 0) return const SizedBox.shrink();
        final tema = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push(Rotalar.eylemler),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: [
                    Icon(LucideIcons.listChecks, color: tema.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Onay bekleyen $sayi', style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    Text('Aç', style: TextStyle(color: tema.colorScheme.primary)),
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
