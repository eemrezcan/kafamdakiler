import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Extra text styles of the web theme (K-0022 addendum): one font, Inter.
/// [sayi] has equal-width digits for numbers and readings; [baslik] is the
/// bold heading style.
@immutable
class KdYazi extends ThemeExtension<KdYazi> {
  const KdYazi({required this.sayi, required this.baslik});

  /// Used when a theme without the extension is in effect (widget tests).
  static const varsayilan = KdYazi(
    sayi: TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
    baslik: TextStyle(fontWeight: FontWeight.w600),
  );

  static KdYazi of(BuildContext context) => Theme.of(context).extension<KdYazi>() ?? varsayilan;

  final TextStyle sayi;
  final TextStyle baslik;

  @override
  KdYazi copyWith({TextStyle? sayi, TextStyle? baslik}) => KdYazi(
        sayi: sayi ?? this.sayi,
        baslik: baslik ?? this.baslik,
      );

  @override
  KdYazi lerp(KdYazi? other, double t) => other == null
      ? this
      : KdYazi(
          sayi: TextStyle.lerp(sayi, other.sayi, t)!,
          baslik: TextStyle.lerp(baslik, other.baslik, t)!,
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
    final baslik = GoogleFonts.inter(color: scheme.onSurface, fontWeight: FontWeight.w600, letterSpacing: -0.3);
    final textTheme = GoogleFonts.interTextTheme(temel)
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        .copyWith(
          headlineMedium: baslik.copyWith(fontSize: 28),
          headlineSmall: baslik.copyWith(fontSize: 22),
          titleLarge: baslik.copyWith(fontSize: 20),
        );

    // Web theme tokens that have no ColorScheme slot (site.css, K-0022).
    final koyu = scheme.brightness == Brightness.dark;
    final cizgiGuclu = koyu ? const Color(0x42E8E4F5) : const Color(0x471C1828); // --kd-line-strong
    final alanZemini = koyu ? const Color(0x06FFFFFF) : const Color(0x8CFFFFFF); // --kd-field-bg
    final mor = scheme.primary; // --kd-violet
    final morSecili = mor.withValues(alpha: 0.14);

    // The web's shapes: controls are squares with slightly rounded corners, cards a bit rounder.
    const kontrolKosesi = BorderRadius.all(Radius.circular(6));
    const kontrolSekli = RoundedRectangleBorder(borderRadius: kontrolKosesi);
    final dugmeYazisi = GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500);
    const dugmeBoyu = Size(48, 48);

    OutlineInputBorder alanCercevesi(Color renk, [double kalinlik = 1]) =>
        OutlineInputBorder(borderRadius: kontrolKosesi, borderSide: BorderSide(color: renk, width: kalinlik));

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      extensions: [
        KdYazi(
          sayi: GoogleFonts.inter(color: scheme.onSurface, fontFeatures: const [FontFeature.tabularFigures()]),
          baslik: baslik,
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: baslik.copyWith(fontSize: 22),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: morSecili,
        indicatorShape: kontrolSekli,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      // Primary action: solid ink (dark on the light theme, light on the dark one), as on the web.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.onSurface,
          foregroundColor: scheme.onPrimary,
          minimumSize: dugmeBoyu,
          shape: kontrolSekli,
          textStyle: dugmeYazisi,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: cizgiGuclu),
          minimumSize: dugmeBoyu,
          shape: kontrolSekli,
          textStyle: dugmeYazisi,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: mor, minimumSize: dugmeBoyu, shape: kontrolSekli, textStyle: dugmeYazisi),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(shape: kontrolSekli)),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(kontrolSekli),
          side: WidgetStatePropertyAll(BorderSide(color: cizgiGuclu)),
          minimumSize: const WidgetStatePropertyAll(dugmeBoyu),
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? morSecili : Colors.transparent),
          foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
          textStyle: WidgetStatePropertyAll(dugmeYazisi),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: kontrolKosesi, side: BorderSide(color: cizgiGuclu)),
        side: BorderSide(color: cizgiGuclu),
        selectedColor: morSecili,
        backgroundColor: Colors.transparent,
        showCheckmark: false,
        labelStyle: GoogleFonts.inter(color: scheme.onSurface, fontSize: 14),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: alanZemini,
        border: alanCercevesi(cizgiGuclu),
        enabledBorder: alanCercevesi(cizgiGuclu),
        focusedBorder: alanCercevesi(mor, 1.5),
        errorBorder: alanCercevesi(scheme.error),
        focusedErrorBorder: alanCercevesi(scheme.error, 1.5),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(linearTrackColor: scheme.outlineVariant, color: mor),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: scheme.outlineVariant)),
      ),
      // Like the web's "Kaydedildi" toast: a light surface with a hairline, not a dark bar.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surface,
        contentTextStyle: GoogleFonts.inter(color: scheme.onSurface, fontSize: 14),
        actionTextColor: mor,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: cizgiGuclu)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: mor,
        dividerColor: scheme.outlineVariant,
        labelStyle: dugmeYazisi,
      ),
    );
  }
}
