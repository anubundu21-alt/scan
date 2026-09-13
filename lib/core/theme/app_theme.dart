import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scan2/core/theme/brand.dart';

/// The visual system for the whole app.
///
/// There used to be two of these. The welcome, onboarding and account screens
/// were built from the Scanella design pack — its green, its ink navy, its
/// wordmark — and then the app the customer actually lives in fell back to a
/// separately seeded Material palette in a different colour, with the platform's
/// default type face. Crossing from the intro into the library changed the
/// product's identity, which is exactly the seam that makes an app read as
/// assembled rather than designed.
///
/// So the tokens in [Brand] are now the single source, and this file turns
/// them into a [ThemeData] for both brightnesses. Three things carry the
/// weight: one bundled type face at every size, one green, and paper — white
/// surfaces on a tinted canvas with hairline borders instead of Material's
/// drop shadows.
class AppTheme {
  const AppTheme._();

  // Built once. These are read on every rebuild of the app root, and the
  // editor screen wraps itself in [dark] on every frame it paints.
  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  /// Light: ink on paper. Surfaces are white, the page behind them is the
  /// faintly tinted canvas, and separation comes from a hairline rather than a
  /// shadow.
  static const _light = ColorScheme(
    brightness: Brightness.light,
    primary: Brand.accent,
    onPrimary: Colors.white,
    primaryContainer: Brand.accentWash,
    onPrimaryContainer: Brand.accentDark,
    secondary: Brand.ink,
    onSecondary: Colors.white,
    secondaryContainer: Brand.accentTint,
    onSecondaryContainer: Brand.ink,
    tertiary: Brand.amber,
    onTertiary: Color(0xFF3A2400),
    error: Brand.pdfRed,
    onError: Colors.white,
    errorContainer: Color(0xFFFFE6E3),
    onErrorContainer: Color(0xFF7A1109),
    surface: Brand.surface,
    onSurface: Brand.ink,
    onSurfaceVariant: Brand.grey,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFFBFCFE),
    surfaceContainer: Brand.canvas,
    surfaceContainerHigh: Color(0xFFF1F4FA),
    surfaceContainerHighest: Color(0xFFE9EEF7),
    outline: Brand.outlineStrong,
    outlineVariant: Brand.outline,
    inverseSurface: Brand.ink,
    onInverseSurface: Brand.canvas,
    inversePrimary: Brand.accentLight,
    shadow: Brand.ink,
    scrim: Color(0xFF060B18),
  );

  /// Dark: the same navy the light theme writes with, used as the paper. A
  /// neutral grey dark mode would read as a different app.
  static const _dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Brand.accentLight,
    onPrimary: Color(0xFF05122E),
    primaryContainer: Color(0xFF0F1D3D),
    onPrimaryContainer: Color(0xFFC6D3EF),
    secondary: Brand.paperOnDark,
    onSecondary: Brand.inkCanvas,
    secondaryContainer: Color(0xFF23324E),
    onSecondaryContainer: Brand.paperOnDark,
    tertiary: Color(0xFFFFC46B),
    onTertiary: Color(0xFF3A2400),
    error: Color(0xFFFF7A70),
    onError: Color(0xFF4A0A05),
    errorContainer: Color(0xFF6E1912),
    onErrorContainer: Color(0xFFFFDAD5),
    surface: Brand.inkSurface,
    onSurface: Brand.paperOnDark,
    onSurfaceVariant: Brand.greyOnDark,
    surfaceContainerLowest: Color(0xFF070D19),
    surfaceContainerLow: Color(0xFF101A2B),
    surfaceContainer: Brand.inkCanvas,
    surfaceContainerHigh: Brand.inkSurfaceHigh,
    surfaceContainerHighest: Color(0xFF223047),
    outline: Color(0xFF3C4A66),
    outlineVariant: Brand.inkOutline,
    inverseSurface: Brand.paperOnDark,
    onInverseSurface: Brand.ink,
    inversePrimary: Brand.accent,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = isLight ? _light : _dark;
    final canvas = isLight ? Brand.canvas : Brand.inkCanvas;

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: Brand.font,
    );

    return base.copyWith(
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      textTheme: _textTheme(base.textTheme, scheme),
      // No ripple anywhere. A ripple starts where you touched and spreads
      // over about a quarter of a second — it reports that a tap happened
      // rather than answering the finger that made it, and it is the single
      // loudest "this is an Android app" tell on an iPhone. Controls that
      // matter press and spring instead (see PressableScale); the rest keep
      // Material's pressed-state tint, which is instant.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: canvas,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: Brand.font,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: scheme.onSurface,
        ),
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: isLight ? Colors.white : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Brand.radiusCard),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          textStyle: const TextStyle(
            fontFamily: Brand.font,
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Brand.radiusButton),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: const TextStyle(
            fontFamily: Brand.font,
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Brand.radiusButton),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
            fontFamily: Brand.font,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        showCheckmark: false,
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primary,
        labelStyle: TextStyle(
          fontFamily: Brand.font,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: Brand.font,
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: scheme.onPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 24),
        extendedTextStyle: const TextStyle(
          fontFamily: Brand.font,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: TextStyle(
          fontFamily: Brand.font,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: Brand.font,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.35,
          color: scheme.onSurfaceVariant,
        ),
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: isLight ? Colors.white : scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 70,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isLight ? Colors.white : scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Brand.radiusSheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isLight ? Colors.white : scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
          fontFamily: Brand.font,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: scheme.onSurface,
        ),
        contentTextStyle: TextStyle(
          fontFamily: Brand.font,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          height: 1.4,
          color: scheme.onSurfaceVariant,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(16),
        elevation: 0,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          fontFamily: Brand.font,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: scheme.outlineVariant,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return isLight ? const Color(0xFFF3F5F9) : scheme.outline;
          }
          return states.contains(WidgetState.selected)
              ? Colors.white
              : (isLight ? Colors.white : scheme.onSurfaceVariant);
        }),
        // A disabled switch that is on still has to look off-limits. Painting
        // it in full brand green next to a greyed-out label says the row is
        // both active and unavailable at once.
        trackColor: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          if (states.contains(WidgetState.disabled)) {
            return selected
                ? scheme.primary.withValues(alpha: 0.30)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.6);
          }
          return selected ? scheme.primary : scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return states.contains(WidgetState.disabled)
              ? scheme.outlineVariant.withValues(alpha: 0.5)
              : scheme.outlineVariant;
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primary,
          selectedForegroundColor: scheme.onPrimary,
          foregroundColor: scheme.onSurfaceVariant,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: const TextStyle(
            fontFamily: Brand.font,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayShape: SliderComponentShape.noOverlay,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isLight ? Colors.white : scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        textStyle: TextStyle(
          fontFamily: Brand.font,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: TextStyle(
          fontFamily: Brand.font,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: scheme.onInverseSurface,
        ),
      ),
    );
  }

  /// The type scale.
  ///
  /// Headings are heavy and tightly tracked; body copy sits at medium weight
  /// with open line height. The jump between the two is deliberate — a scale
  /// where every step is one size apart reads as a wireframe.
  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    TextStyle? h(TextStyle? style, double size, double tracking) =>
        style?.copyWith(
          fontSize: size,
          fontWeight: FontWeight.w800,
          letterSpacing: tracking,
          height: 1.15,
          color: scheme.onSurface,
        );

    TextStyle? t(TextStyle? style, double size, FontWeight weight) =>
        style?.copyWith(
          fontSize: size,
          fontWeight: weight,
          letterSpacing: -0.2,
          height: 1.25,
          color: scheme.onSurface,
        );

    TextStyle? b(TextStyle? style, double size, Color color) => style?.copyWith(
      fontSize: size,
      fontWeight: FontWeight.w500,
      height: 1.45,
      letterSpacing: 0,
      color: color,
    );

    return base.copyWith(
      displayLarge: h(base.displayLarge, 46, -1.4),
      displayMedium: h(base.displayMedium, 40, -1.2),
      displaySmall: h(base.displaySmall, 34, -1.0),
      headlineLarge: h(base.headlineLarge, 30, -0.9),
      headlineMedium: h(base.headlineMedium, 26, -0.7),
      headlineSmall: h(base.headlineSmall, 22, -0.5),
      titleLarge: t(base.titleLarge, 20, FontWeight.w800),
      titleMedium: t(base.titleMedium, 17, FontWeight.w700),
      titleSmall: t(base.titleSmall, 15.5, FontWeight.w700),
      bodyLarge: b(base.bodyLarge, 17, scheme.onSurface),
      bodyMedium: b(base.bodyMedium, 15.5, scheme.onSurface),
      bodySmall: b(base.bodySmall, 14, scheme.onSurfaceVariant),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: scheme.onSurface,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: scheme.onSurfaceVariant,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
