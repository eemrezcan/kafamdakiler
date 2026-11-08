import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../routing/router.dart';

/// The magnifier in the top bar of every tab (Bugün, Gelen, Projeler, Hatırlatıcılar): opens the search page.
class AraDugmesi extends StatelessWidget {
  const AraDugmesi({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Ara',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(LucideIcons.search),
        onPressed: () => context.push(Rotalar.ara),
      );
}
