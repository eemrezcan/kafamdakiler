import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/gun_gorunum.dart';

/// "Dünden kaldı: Market": an item yesterday's plan left open, with "Bugüne al" and "Bırak". Without [onAl] and [onBirak]
/// (someone who may not write) it is a plain line.
class DundenBandi extends StatelessWidget {
  const DundenBandi({super.key, required this.dunden, this.onAl, this.onBirak});

  final DundenKalan dunden;
  final VoidCallback? onAl;
  final VoidCallback? onBirak;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final zemin = Color.lerp(tema.colorScheme.surface, tema.colorScheme.secondary, tema.brightness == Brightness.dark ? 0.16 : 0.1)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: zemin,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.undo2, size: 16, color: tema.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Dünden kaldı: '),
                        TextSpan(text: dunden.baslik, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (dunden.tahminDk != null) TextSpan(text: ' · ${sureMetni(dunden.tahminDk!)}'),
                      ]),
                      style: tema.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              if (onAl != null || onBirak != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 4,
                    children: [
                      if (onBirak != null)
                        TextButton(key: ValueKey('dunden-birak-${dunden.maddeId}'), onPressed: onBirak, child: const Text('Bırak')),
                      if (onAl != null)
                        FilledButton(key: ValueKey('dunden-al-${dunden.maddeId}'), onPressed: onAl, child: const Text('Bugüne al')),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
