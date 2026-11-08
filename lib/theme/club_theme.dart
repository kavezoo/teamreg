import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClubTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: dark ? const Color(0xFFE0B56A) : const Color(0xFF6E3B24),
      brightness: brightness,
      primary: dark ? const Color(0xFFE0B56A) : const Color(0xFF6E3B24),
      onPrimary: dark ? const Color(0xFF2A1C0A) : const Color(0xFFFFF8EF),
      secondary: dark ? const Color(0xFF9DCFB0) : const Color(0xFF1E4A38),
      tertiary: dark ? const Color(0xFFE7C39A) : const Color(0xFF8A6A2F),
      surface: dark ? const Color(0xFF1C1814) : const Color(0xFFFFFBF6),
    );
    final background = dark ? const Color(0xFF100E0C) : const Color(0xFFF3EEE4);
    final bar = dark ? const Color(0xFF1A1613) : const Color(0xFF3E2618);
    final onBar = dark ? const Color(0xFFF6E7C8) : const Color(0xFFFFF8EF);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: bar,
        foregroundColor: onBar,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: onBar),
        actionsIconTheme: IconThemeData(color: onBar),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: dark ? Colors.transparent : Colors.black,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: dark ? Colors.transparent : Colors.black,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF26211C) : const Color(0xFFFFFDF9),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
        labelStyle: TextStyle(
          color: dark ? const Color(0xFFE0B56A) : const Color(0xFF6E3B24),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        floatingLabelStyle: TextStyle(
          color: dark ? const Color(0xFFE0B56A) : const Color(0xFF6E3B24),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        hintStyle: TextStyle(
          color: scheme.onSurface.withValues(alpha: 0.42),
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: dark ? const Color(0xFF5C4A32) : const Color(0xFFD7C4A8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: dark ? const Color(0xFF5C4A32) : const Color(0xFFD7C4A8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: dark ? const Color(0xFFE0B56A) : const Color(0xFF6E3B24), width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: onBar,
        unselectedLabelColor: onBar.withValues(alpha: 0.72),
        indicatorColor: dark ? const Color(0xFFE0B56A) : const Color(0xFFF3D7A1),
        dividerColor: Colors.transparent,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }
}
