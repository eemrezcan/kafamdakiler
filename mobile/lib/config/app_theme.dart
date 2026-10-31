import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Extra text styles of the web theme: serif for big headings (italic for
/// emphasis), mono for numbers and labels. Body text is Inter via [TextTheme].
@immutable
class KdYazi extends ThemeExtension<KdYazi> {
  const KdYazi({required this.mono, required this.serif, required this.serifItalik});

  /// Used when a theme without the extension is in effect (widget tests).
  static const varsayilan = KdYazi(
    mono: TextStyle(fontFamily: 'monospace'),
    serif: TextStyle(fontFamily: 'serif'),
    serifItalik: TextStyle(fontFamily: 'serif', fontStyle: FontStyle.italic),
  );

  static KdYazi of(BuildContext context) => Theme.of(context).extension<KdYazi>() ?? varsayilan;

  final TextStyle mono;
  final TextStyle serif;
  final TextStyle serifItalik;

  @override
  KdYazi copyWith({TextStyle? mono, TextStyle? serif, TextStyle? serifItalik}) => KdYazi(
        mono: mono ?? this.mono,
        serif: serif ?? this.serif,
        serifItalik: serifItalik ?? this.serifItalik,
      );

  @override
  KdYazi lerp(KdYazi? other, double t) => other == null
      ? this
      : KdYazi(
          mono: TextStyle.lerp(mono, other.mono, t)!,
          serif: TextStyle.lerp(serif, other.serif, t)!,
          serifItalik: TextStyle.lerp(serifItalik, other.serifItalik, t)!,
        );
}

/// Colours copied from the web theme tokens (backend/wwwroot/css/site.css, K-0022).
class AppTheme {
  const AppTheme._();

  static final light = _build(
    const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF5A3E9E), // --kd-violet
      onPrimary: Color(0xFFF6F3EE), // --kd-ink-text
      secondary: Color(0xFFB8366F), // --kd-pink
      onSecondary: Color(0xFFF6F3EE),
      error: Color(0xFFA3243B), // --kd-danger
      onError: Color(0xFFF6F3EE),
      surface: Color(0xFFFBF9F5), // --kd-surface-solid
      onSurface: Color(0xFF1C1A22), // --kd-text
      onSurfaceVariant: Color(0xFF6D6876), // --kd-text-muted
      outline: Color(0xFF9A95A3), // --kd-text-faint
      outlineVariant: Color(0x1F1C1828), // --kd-line
    ),
    background: const Color(0xFFF1EEE8), // --kd-bg
  );

  static final dark = _build(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFB6A8EF),
      onPrimary: Color(0xFF0A0A0F),
      secondary: Color(0xFFEF86B8),
      onSecondary: Color(0xFF0A0A0F),
      error: Color(0xFFF19AA6),
      onError: Color(0xFF0A0A0F),
      surface: Color(0xFF0C0D14),
      onSurface: Color(0xFFEBE9F2),
      onSurfaceVariant: Color(0xFF8E8A9C),
      outline: Color(0xFF615D6E),
      outlineVariant: Color(0x1AE8E4F5),
    ),
    background: const Color(0xFF05060A),
  );

  static ThemeData _build(ColorScheme scheme, {required Color background}) {
    final temel = ThemeData(brightness: scheme.brightness).textTheme;
    final serif = GoogleFonts.instrumentSerif(color: scheme.onSurface);
    final textTheme = GoogleFonts.interTextTheme(temel)
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        .copyWith(
          headlineMedium: serif.copyWith(fontSize: 32),
          headlineSmall: serif.copyWith(fontSize: 26),
          titleLarge: serif.copyWith(fontSize: 24),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      extensions: [
        KdYazi(
          mono: GoogleFonts.ibmPlexMono(color: scheme.onSurface),
          serif: serif,
          serifItalik: GoogleFonts.instrumentSerif(color: scheme.onSurface, fontStyle: FontStyle.italic),
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: serif.copyWith(fontSize: 26),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
