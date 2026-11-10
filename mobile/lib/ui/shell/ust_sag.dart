import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/kullanici_repository.dart';
import '../../routing/router.dart';
import '../profil/profil_sheet.dart';
import 'bildirim_sayisi_view_model.dart';

/// The top right of every tab: the bell with its unread badge (opens Bildirimler) and the profile button (opens the profile
/// sheet). Search is not here any more; it lives on Beyin only (K-0024).
class UstSagDugmeleri extends StatelessWidget {
  const UstSagDugmeleri({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final email = context.watch<KullaniciRepository>().ben?.email;
    final bas = (email != null && email.isNotEmpty) ? email[0].toUpperCase() : '?';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Zil(),
        IconButton(
          tooltip: 'Profil',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: tema.colorScheme.primary,
            foregroundColor: tema.colorScheme.onPrimary,
            child: Text(bas, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          onPressed: () => profilAc(context),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _Zil extends StatelessWidget {
  const _Zil();

  @override
  Widget build(BuildContext context) {
    // The shell provides the count; a tab shown without it (a widget test) simply has no badge.
    final vm = context.watch<BildirimSayisiViewModel?>();
    final sayi = vm?.okunmamis ?? 0;
    return IconButton(
      tooltip: sayi > 0 ? 'Bildirimler, $sayi okunmamış' : 'Bildirimler',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Badge(
        isLabelVisible: sayi > 0,
        label: Text(sayi > 99 ? '99+' : '$sayi'),
        child: const Icon(LucideIcons.bell),
      ),
      onPressed: () => context.push(Rotalar.bildirimler),
    );
  }
}
