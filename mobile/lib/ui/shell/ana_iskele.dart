import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/esitleyici.dart';
import '../../data/repositories/asistan_repository.dart';
import '../../data/repositories/bildirim_repository.dart';
import 'asistan_sayisi_view_model.dart';
import 'bildirim_sayisi_view_model.dart';

/// Bottom navigation: Bugün · Takvim · Asistan (in the middle, a round button) · Alışkanlıklar · Beyin (K-0024). The bell and
/// the profile button are in each tab's top bar ([UstSagDugmeleri]); Yakala, Gelen and the approval queue are reached from
/// Asistan, the project list and search from Beyin.
class AnaIskele extends StatelessWidget {
  const AnaIskele({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    // Back on any tab but Bugün goes to Bugün first; only from Bugün does it leave the app.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (c) => BildirimSayisiViewModel(repo: c.read<BildirimRepository>(), esitleyici: c.read<Esitleyici>())..yukle(),
        ),
        ChangeNotifierProvider(
          create: (c) => AsistanSayisiViewModel(repo: c.read<AsistanRepository>(), esitleyici: c.read<Esitleyici>())..yukle(),
        ),
      ],
      child: PopScope(
        canPop: navigationShell.currentIndex == 0,
        onPopInvokedWithResult: (popOldu, _) {
          if (!popOldu) navigationShell.goBranch(0);
        },
        child: Builder(builder: _iskele),
      ),
    );
  }

  Widget _iskele(BuildContext context) {
    final tema = Theme.of(context);
    final bekleyen = context.watch<AsistanSayisiViewModel>().bekleyen;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        labelTextStyle: WidgetStateProperty.resolveWith(
          (durumlar) => tema.textTheme.labelMedium?.copyWith(
            fontSize: 11,
            color: durumlar.contains(WidgetState.selected) ? tema.colorScheme.onSurface : tema.colorScheme.onSurfaceVariant,
            fontWeight: durumlar.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        selectedIndex: navigationShell.currentIndex,
        // Tapping the current tab goes back to its first screen.
        onDestinationSelected: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
        destinations: [
          const NavigationDestination(icon: Icon(LucideIcons.calendarCheck), label: 'Bugün'),
          const NavigationDestination(icon: Icon(LucideIcons.calendarDays), label: 'Takvim'),
          NavigationDestination(
            icon: _AsistanDugmesi(secili: false, bekleyen: bekleyen),
            selectedIcon: _AsistanDugmesi(secili: true, bekleyen: bekleyen),
            label: 'Asistan',
          ),
          const NavigationDestination(icon: Icon(LucideIcons.target), label: 'Alışkanlıklar'),
          const NavigationDestination(icon: Icon(LucideIcons.brain), label: 'Beyin'),
        ],
      ),
    );
  }
}

/// The middle tab's icon: a filled round button in the theme's primary colour, so the assistant stands out from the others.
class _AsistanDugmesi extends StatelessWidget {
  const _AsistanDugmesi({required this.secili, this.bekleyen = 0});

  final bool secili;

  /// What waits on the person: a badge on the corner of the button.
  final int bekleyen;

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return Badge(
      isLabelVisible: bekleyen > 0,
      label: Text(bekleyen > 99 ? '99+' : '$bekleyen'),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: renk.primary,
          border: secili ? Border.all(color: renk.primary.withValues(alpha: 0.3), width: 4) : null,
        ),
        child: Icon(LucideIcons.sparkles, color: renk.onPrimary, size: 22),
      ),
    );
  }
}
