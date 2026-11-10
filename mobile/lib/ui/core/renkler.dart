import 'package:flutter/material.dart';

/// Habit colour keys sent to the API (`renk`), with the same values as the web
/// theme (`--kd-hue-*` in backend/wwwroot/css/site.css, K-0022): a darker set for
/// the light theme, a lighter set for the dark theme.
const _acikRenkler = <String, Color>{
  'violet': Color(0xFF5A3E9E),
  'pink': Color(0xFFB8366F),
  'blue': Color(0xFF2F62B5),
  'teal': Color(0xFF1F7F7A),
  'green': Color(0xFF3B7A3F),
  'amber': Color(0xFFA8681A),
  'red': Color(0xFFB5361F),
  'slate': Color(0xFF5B6475),
};

const _koyuRenkler = <String, Color>{
  'violet': Color(0xFFB6A8EF),
  'pink': Color(0xFFEF86B8),
  'blue': Color(0xFF8FB4F2),
  'teal': Color(0xFF7FD3CC),
  'green': Color(0xFF9AD39D),
  'amber': Color(0xFFF0C070),
  'red': Color(0xFFF4826C),
  'slate': Color(0xFFAAB3C5),
};

/// The valid colour keys, in picker order.
final renkAnahtarlari = _acikRenkler.keys.toList(growable: false);

const varsayilanRenk = 'violet';

/// The colour of a habit for the current light/dark theme; unknown keys fall
/// back to the theme primary.
Color aliskanlikRengi(BuildContext context, String anahtar) {
  final tema = Theme.of(context);
  final renkler = tema.brightness == Brightness.dark ? _koyuRenkler : _acikRenkler;
  return renkler[anahtar] ?? tema.colorScheme.primary;
}

/// A habit card's surface: the theme surface with a little of the habit colour
/// (9% light, 12% dark, as on the web), so text keeps the theme colours.
Color kartZemini(BuildContext context, Color renk) {
  final tema = Theme.of(context);
  final oran = tema.brightness == Brightness.dark ? 0.12 : 0.09;
  return Color.lerp(tema.colorScheme.surface, renk, oran)!;
}

/// A habit card's border: the theme hairline with 28% of the habit colour.
Color kartCercevesi(BuildContext context, Color renk) =>
    Color.lerp(Theme.of(context).colorScheme.outlineVariant, renk, 0.28)!;

/// "Goal reached" green of the web theme (`--kd-ok`).
Color tamamRengi(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF7FD0A0) : const Color(0xFF2F7D4F);

/// The amber of "this waits on you" (approval cards): the habit palette's amber of the current theme.
Color uyariRengi(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? _koyuRenkler['amber']! : _acikRenkler['amber']!;
