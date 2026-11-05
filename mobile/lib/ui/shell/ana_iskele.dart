import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/kullanici_repository.dart';
import '../../routing/router.dart';

/// Bottom navigation: Bugün / Projeler / Yakalamalar / Ara / Profil, and the
/// "Yakala" button that opens the capture screen from any of them. The habit
/// list is opened from Profil, a Raf habit's shelf from the habit itself, as on
/// the web; there is no separate management tab either, management lives where
/// the work is (M07).
class AnaIskele extends StatelessWidget {
  const AnaIskele({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    // Capturing is for the Sahip role (K-0009), like the other write screens.
    final sahip = context.watch<KullaniciRepository>().sahip;
    // The button would float above the keyboard (the search field), covering the results.
    final klavyeAcik = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      body: navigationShell,
      floatingActionButton: sahip && !klavyeAcik
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Rotalar.yakala),
              icon: const Icon(LucideIcons.zap),
              label: const Text('Yakala'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        // Tapping the current tab goes back to its first screen.
        onDestinationSelected: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(LucideIcons.calendarCheck), label: 'Bugün'),
          NavigationDestination(icon: Icon(LucideIcons.folder), label: 'Projeler'),
          NavigationDestination(icon: Icon(LucideIcons.inbox), label: 'Yakalamalar'),
          NavigationDestination(icon: Icon(LucideIcons.search), label: 'Ara'),
          NavigationDestination(icon: Icon(LucideIcons.user), label: 'Profil'),
        ],
      ),
    );
  }
}
