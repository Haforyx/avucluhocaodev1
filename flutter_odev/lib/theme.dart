import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const brandColor = Color(0xFF4F46E5);
const brandDeep = Color(0xFF312E81);
const accentColor = Color(0xFFF59E0B);
const appFontFamily = 'Nunito';

/// Marka gradyanı (karşılama kartı, giriş ekranı başlığı, avatar).
const brandGradient = LinearGradient(
  colors: [Color(0xFF7C3AED), brandColor, brandDeep],
  stops: [0, 0.5, 1],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Odak sayacının evrelere göre renkleri.
const focusColor = Color(0xFF4F46E5);
const breakColor = Color(0xFF10B981);

Color pageBackground(Brightness b) =>
    b == Brightness.light ? const Color(0xFFF5F6FB) : const Color(0xFF0D0E16);

ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final base = ColorScheme.fromSeed(seedColor: brandColor, brightness: brightness);
  final scheme = light
      ? base.copyWith(
          primary: brandColor,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFE6E7FD),
          onPrimaryContainer: const Color(0xFF1E1B4B),
          secondaryContainer: const Color(0xFFEEF0FB),
          onSecondaryContainer: const Color(0xFF26245A),
          tertiary: const Color(0xFFB45309),
          tertiaryContainer: const Color(0xFFFEF3C7),
          onTertiaryContainer: const Color(0xFF78350F),
          surface: Colors.white,
          onSurface: const Color(0xFF14152B),
          onSurfaceVariant: const Color(0xFF686B85),
          outline: const Color(0xFFD3D5E3),
          outlineVariant: const Color(0xFFE7E8F1),
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFF9F9FD),
          surfaceContainer: const Color(0xFFF1F2F8),
          surfaceContainerHigh: const Color(0xFFEAEBF4),
          surfaceContainerHighest: const Color(0xFFE2E4EF),
          inverseSurface: const Color(0xFF14152B),
          onInverseSurface: Colors.white,
        )
      : base.copyWith(
          primary: const Color(0xFFA5A8FF),
          onPrimary: const Color(0xFF14124A),
          primaryContainer: const Color(0xFF2D2A78),
          onPrimaryContainer: const Color(0xFFE0E0FF),
          secondaryContainer: const Color(0xFF22233D),
          onSecondaryContainer: const Color(0xFFDCDDF7),
          tertiary: const Color(0xFFFBBF24),
          surface: const Color(0xFF161725),
          onSurface: const Color(0xFFEAEBF5),
          onSurfaceVariant: const Color(0xFF9A9CB5),
          outline: const Color(0xFF3B3D55),
          outlineVariant: const Color(0xFF26283B),
          surfaceContainerLowest: const Color(0xFF0D0E16),
          surfaceContainerLow: const Color(0xFF13141F),
          surfaceContainer: const Color(0xFF1B1C2B),
          surfaceContainerHigh: const Color(0xFF222436),
          surfaceContainerHighest: const Color(0xFF2A2C40),
        );

  final background = pageBackground(brightness);
  final radius = BorderRadius.circular(14);
  final text = _textTheme(brightness, scheme);

  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: appFontFamily,
    textTheme: text,
    scaffoldBackgroundColor: background,
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      foregroundColor: scheme.onSurface,
      titleTextStyle: text.headlineSmall,
      systemOverlayStyle: light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: light ? Colors.white : scheme.surfaceContainer,
      border: border(scheme.outlineVariant),
      enabledBorder: border(light ? const Color(0xFFDCDEEA) : scheme.outlineVariant),
      focusedBorder: border(scheme.primary, 1.6),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 1.6),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
      floatingLabelStyle: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
      errorMaxLines: 2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: appFontFamily, fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: appFontFamily, fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontFamily: appFontFamily, fontWeight: FontWeight.w800),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      titleTextStyle: text.titleSmall,
      subtitleTextStyle: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: light ? 0.1 : 0.2),
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
          size: 24,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: appFontFamily,
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
          color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      showCheckmark: false,
      backgroundColor: scheme.surface,
      selectedColor: scheme.primary,
      side: WidgetStateBorderSide.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? BorderSide(color: scheme.primary)
            : BorderSide(color: scheme.outlineVariant),
      ),
      labelStyle: WidgetStateTextStyle.resolveWith(
        (s) => TextStyle(
          fontFamily: appFontFamily,
          fontWeight: FontWeight.w700,
          color: s.contains(WidgetState.selected) ? scheme.onPrimary : scheme.onSurface,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        textStyle: const TextStyle(fontFamily: appFontFamily, fontWeight: FontWeight.w700),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: text.titleLarge,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: scheme.outline,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: text.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(
        fontFamily: appFontFamily,
        color: scheme.onInverseSurface,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide(color: scheme.outline, width: 1.6),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

TextTheme _textTheme(Brightness brightness, ColorScheme scheme) {
  final typography = Typography.material2021(platform: TargetPlatform.android);
  final colors = brightness == Brightness.light ? typography.black : typography.white;
  final base = typography.englishLike.merge(colors).apply(
        fontFamily: appFontFamily,
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      );

  // Sayılar alt alta düzgün hizalansın diye sabit genişlikli rakamlar.
  TextStyle? s(TextStyle? style, FontWeight weight, [double letterSpacing = 0]) => style?.copyWith(
        fontWeight: weight,
        letterSpacing: letterSpacing,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  return base.copyWith(
    displayLarge: s(base.displayLarge, FontWeight.w800, -1.5),
    displayMedium: s(base.displayMedium, FontWeight.w800, -1.2),
    displaySmall: s(base.displaySmall, FontWeight.w800, -1),
    headlineLarge: s(base.headlineLarge, FontWeight.w800, -0.8),
    headlineMedium: s(base.headlineMedium, FontWeight.w800, -0.6),
    headlineSmall: s(base.headlineSmall, FontWeight.w800, -0.4),
    titleLarge: s(base.titleLarge, FontWeight.w800, -0.2),
    titleMedium: s(base.titleMedium, FontWeight.w800),
    titleSmall: s(base.titleSmall, FontWeight.w700),
    bodyLarge: s(base.bodyLarge, FontWeight.w600),
    bodyMedium: s(base.bodyMedium, FontWeight.w600),
    bodySmall: s(base.bodySmall, FontWeight.w600),
    labelLarge: s(base.labelLarge, FontWeight.w700),
    labelMedium: s(base.labelMedium, FontWeight.w700),
    labelSmall: s(base.labelSmall, FontWeight.w700),
  );
}
