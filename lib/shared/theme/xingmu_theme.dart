import 'package:flutter/material.dart';

abstract final class XingmuTheme {
  static const Color seedColor = Color(0xFF765CFF);
  static const Color accentColor = Color(0xFF39D7F5);
  static const Color purpleGlow = Color(0xFF815CFF);
  static const Color cyanGlow = Color(0xFF49D9FF);
  static const Color deepNavy = Color(0xFF07101E);
  static const Color nearBlack = Color(0xFF040814);
  static const Color glassSurface = Color(0xE612192A);
  static const Color glassBorder = Color(0xFF2D3857);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final generated = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final scheme = generated.copyWith(
      primary: isDark ? purpleGlow : const Color(0xFF5F46D7),
      onPrimary: Colors.white,
      primaryContainer: isDark
          ? const Color(0xFF27205C)
          : const Color(0xFFE6E0FF),
      onPrimaryContainer: isDark
          ? const Color(0xFFEAE5FF)
          : const Color(0xFF20115F),
      secondary: isDark ? cyanGlow : const Color(0xFF007F9A),
      onSecondary: isDark ? nearBlack : Colors.white,
      secondaryContainer: isDark
          ? const Color(0xFF102E43)
          : const Color(0xFFD2F4FF),
      onSecondaryContainer: isDark
          ? const Color(0xFFD7F7FF)
          : const Color(0xFF003642),
      tertiary: isDark ? const Color(0xFFC866FF) : const Color(0xFF8246A4),
      surface: isDark ? const Color(0xFF0A1020) : const Color(0xFFF7F8FD),
      surfaceContainerLowest: isDark ? nearBlack : Colors.white,
      surfaceContainerLow: isDark
          ? const Color(0xFF0C1323)
          : const Color(0xFFF1F3FA),
      surfaceContainer: isDark
          ? const Color(0xFF11192B)
          : const Color(0xFFECEFF7),
      surfaceContainerHigh: isDark
          ? const Color(0xFF172137)
          : const Color(0xFFE4E8F2),
      surfaceContainerHighest: isDark
          ? const Color(0xFF1D2942)
          : const Color(0xFFDCE1EC),
      onSurface: isDark ? const Color(0xFFF5F7FF) : const Color(0xFF171A25),
      onSurfaceVariant: isDark
          ? const Color(0xFFA9B3C9)
          : const Color(0xFF596174),
      outline: isDark ? const Color(0xFF69748C) : const Color(0xFF747B8D),
      outlineVariant: isDark ? glassBorder : const Color(0xFFD3D8E5),
      error: isDark ? const Color(0xFFFF7086) : const Color(0xFFBA1A1A),
    );
    final baseText = ThemeData(brightness: brightness).textTheme;
    final textTheme = baseText.copyWith(
      headlineMedium: baseText.headlineMedium?.copyWith(
        height: 1.14,
        fontWeight: FontWeight.w800,
        letterSpacing: -.65,
      ),
      headlineSmall: baseText.headlineSmall?.copyWith(
        fontSize: 26,
        height: 1.18,
        fontWeight: FontWeight.w800,
        letterSpacing: -.45,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(fontSize: 16, height: 1.55),
      bodyMedium: baseText.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? nearBlack : const Color(0xFFF5F7FC),
      canvasColor: isDark ? nearBlack : const Color(0xFFF5F7FC),
      visualDensity: VisualDensity.standard,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: isDark
            ? const Color(0xF2050A16)
            : const Color(0xF7FFFFFF),
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isDark ? glassSurface : Colors.white,
        shadowColor: isDark ? const Color(0x552754FF) : Colors.black12,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .88)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xF20B1120) : Colors.white,
        indicatorColor: isDark
            ? purpleGlow.withValues(alpha: .28)
            : scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? (isDark ? const Color(0xFF9FC8FF) : scheme.primary)
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? (isDark ? const Color(0xFF8FB6FF) : scheme.primary)
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: isDark ? const Color(0xFF09101E) : Colors.white,
        indicatorColor: isDark
            ? purpleGlow.withValues(alpha: .24)
            : scheme.primaryContainer,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF111A2C) : Colors.white,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: .72),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? cyanGlow : scheme.primary,
            width: 1.7,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          foregroundColor: isDark ? const Color(0xFFDCE4FF) : scheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? const Color(0xFF9FC8FF) : scheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF151D31) : Colors.white,
        selectedColor: isDark
            ? const Color(0xFF2A235F)
            : scheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF172038)
            : const Color(0xFF252838),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF0B1222) : Colors.white,
        modalBackgroundColor: isDark ? const Color(0xFF0B1222) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF10182A) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? cyanGlow : scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
    );
  }
}
