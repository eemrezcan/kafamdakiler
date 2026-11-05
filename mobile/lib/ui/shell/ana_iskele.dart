import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/kullanici_repository.dart';
import '../../routing/router.dart';

/// Bottom navigation: Bugün / Alışkanlıklar / Yakalamalar / Profil, and the
/// "Yakala" button that opens the capture screen from any of them. A Raf habit's shelf is
/// opened from the habit itself, as on the web; there is no separate
/// management tab either, management lives where the work is (M07).
class AnaIskele extends StatelessWidget {
  const AnaIskele({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    // Capturing is for the Sahip role (K-0009), like the other write screens.
    final sahip = context.watch<KullaniciRepository>().sahip;
    return Scaffold(
      body: navigationShell,
      floatingActionButton: sahip
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
          NavigationDestination(icon: Icon(LucideIcons.target), label: 'Alışkanlıklar'),
          NavigationDestination(icon: Icon(LucideIcons.inbox), label: 'Yakalamalar'),
          NavigationDestination(icon: Icon(LucideIcons.user), label: 'Profil'),
        ],
      ),
    );
  }
}
