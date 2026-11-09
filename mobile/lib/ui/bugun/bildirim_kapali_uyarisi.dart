import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/repositories/bildirim_izni.dart';

/// "Bildirimler kapalı": shown on Bugün while the phone may not show notifications, with a button to the system settings.
/// Hidden while the permission is on or not known yet. Without it, reminders and the server's messages fail without a word.
class BildirimKapaliUyarisi extends StatelessWidget {
  const BildirimKapaliUyarisi({super.key, required this.izin});

  final BildirimIzni izin;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: izin,
      builder: (context, _) {
        if (!izin.kapali) return const SizedBox.shrink();
        final tema = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            margin: EdgeInsets.zero,
            color: tema.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Icon(LucideIcons.bellOff, color: tema.colorScheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bildirimler kapalı',
                          style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: tema.colorScheme.onErrorContainer),
                        ),
                        Text(
                          'Hatırlatıcılar ve sunucudan gelen bildirimler görünmez.',
                          style: TextStyle(color: tema.colorScheme.onErrorContainer),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: izin.ayarlariAc,
                    child: Text('Ayarlara git', style: TextStyle(color: tema.colorScheme.onErrorContainer)),
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
