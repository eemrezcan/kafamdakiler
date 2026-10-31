import 'package:flutter/material.dart';

/// Habit colour keys sent to the API (`renk`). The contract only shows
/// "violet"; the web must offer the same keys.
const renkAnahtarlari = <String, Color>{
  'violet': Color(0xFF7B5CC4),
  'pink': Color(0xFFD14A8A),
  'blue': Color(0xFF3F7BD1),
  'teal': Color(0xFF2A9D8F),
  'green': Color(0xFF4E9A51),
  'amber': Color(0xFFD99A1E),
  'red': Color(0xFFCB4B4B),
  'slate': Color(0xFF64748B),
};

const varsayilanRenk = 'violet';

/// The colour of a habit; unknown keys fall back to the theme primary.
Color aliskanlikRengi(BuildContext context, String anahtar) =>
    renkAnahtarlari[anahtar] ?? Theme.of(context).colorScheme.primary;
