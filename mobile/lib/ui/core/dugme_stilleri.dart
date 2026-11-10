import 'package:flutter/material.dart';

/// The small buttons of dense places (cards in the feed, the "Dünden kaldı" strip): compact, small text. The visual height is 36;
/// the theme's tap target padding keeps the touch area at 48 dp.
ButtonStyle kompaktDugme(BuildContext context) => ButtonStyle(
      visualDensity: VisualDensity.compact,
      minimumSize: const WidgetStatePropertyAll(Size(48, 36)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
      textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13)),
    );

/// The same, tonal: a soft tint of the primary colour instead of the theme's solid ink fill (which a tonal button would
/// otherwise inherit from `filledButtonTheme`).
ButtonStyle kompaktTonalDugme(BuildContext context) {
  final renk = Theme.of(context).colorScheme;
  return kompaktDugme(context).copyWith(
    backgroundColor: WidgetStatePropertyAll(renk.primary.withValues(alpha: 0.16)),
    foregroundColor: WidgetStatePropertyAll(renk.primary),
  );
}
