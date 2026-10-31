import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Bottom navigation: Bugün / Alışkanlıklar / Raf / Profil. There is no
/// separate management tab; management lives where the work is (M07).
class AnaIskele extends StatelessWidget {
  const AnaIskele({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        // Tapping the current tab goes back to its first screen.
        onDestinationSelected: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(LucideIcons.calendarCheck), label: 'Bugün'),
          NavigationDestination(icon: Icon(LucideIcons.target), label: 'Alışkanlıklar'),
          NavigationDestination(icon: Icon(LucideIcons.libraryBig), label: 'Raf'),
          NavigationDestination(icon: Icon(LucideIcons.user), label: 'Profil'),
        ],
      ),
    );
  }
}
