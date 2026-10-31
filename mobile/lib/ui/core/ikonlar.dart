import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The single list of habit icons. Keys are Lucide names ("book-open"); the
/// web uses the same keys. The package has no lookup by name, so the offered
/// icons are listed here, in the order the icon picker shows them.
const ikonlar = <String, IconData>{
  'book-open': LucideIcons.bookOpen,
  'book': LucideIcons.book,
  'glass-water': LucideIcons.glassWater,
  'droplet': LucideIcons.droplet,
  'coffee': LucideIcons.coffee,
  'cigarette': LucideIcons.cigarette,
  'footprints': LucideIcons.footprints,
  'bike': LucideIcons.bike,
  'dumbbell': LucideIcons.dumbbell,
  'brain': LucideIcons.brain,
  'flower-2': LucideIcons.flower2,
  'film': LucideIcons.film,
  'tv': LucideIcons.tv,
  'graduation-cap': LucideIcons.graduationCap,
  'headphones': LucideIcons.headphones,
  'music': LucideIcons.music,
  'pencil': LucideIcons.pencil,
  'languages': LucideIcons.languages,
  'moon': LucideIcons.moon,
  'sun': LucideIcons.sun,
  'pill': LucideIcons.pill,
  'heart': LucideIcons.heart,
  'apple': LucideIcons.apple,
  'wine': LucideIcons.wine,
  'smartphone': LucideIcons.smartphone,
  'target': LucideIcons.target,
  'flame': LucideIcons.flame,
  'star': LucideIcons.star,
};

const varsayilanIkon = 'target';

IconData lucideIkonu(String anahtar) => ikonlar[anahtar] ?? LucideIcons.circleDot;
