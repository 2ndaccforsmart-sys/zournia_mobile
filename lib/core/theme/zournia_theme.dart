// lib/core/theme/zournia_theme.dart
import 'package:flutter/material.dart';

class ZourniaTheme {
  // ── Light-mode tokens (Dashboard / SaaS surfaces) ─────────────────────────
  static const Color bgPrimary      = Color(0xFFF8F9FA);
  static const Color cardBg         = Colors.white;
  static const Color borderPrimary  = Color(0xFFE9ECEF);
  static const Color textPrimary    = Color(0xFF212529);
  static const Color textMuted      = Color(0xFF6C757D);
  static const Color accentGreen    = Color(0xFF2ECC71);

  // ── Dark-mode tokens (Shell / HUD Terminal void canvas) ───────────────────
  static const Color shellBg        = Color(0xFF080A0C);
  static const Color shellSurface   = Color(0xFF111316);
  static const Color shellCard      = Color(0xFF161A1F);
  static const Color shellBorder    = Color(0xFF252A32);
  static const Color shellBorderSub = Color(0xFF1C2028);
  static const Color shellText      = Color(0xFFE8ECF0);
  static const Color shellTextMuted = Color(0xFF5A6478);
  static const Color shellTextSub   = Color(0xFF8892A4);

  // ── Accent: Electric Teal — the signature AI-OS colour ───────────────────
  /// Primary interactive/brand accent — electric cyan-teal.
  static const Color shellAccent    = Color(0xFF00D4FF);
  /// A slightly dimmer accent for secondary contexts.
  static const Color shellAccentDim = Color(0xFF007A94);
  /// Success green used for pipeline completed states.
  static const Color shellGreen     = Color(0xFF00E676);
  /// Warning amber used for blocked / human-gate states.
  static const Color shellAmber     = Color(0xFFFFAB00);
  /// Danger red used for failed states and destructive actions.
  static const Color shellRed       = Color(0xFFFF1744);

  // ── Gradient helpers ──────────────────────────────────────────────────────
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF00D4FF), Color(0xFF0077FF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF0A0D12), Color(0xFF111316)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── ThemeData factories ───────────────────────────────────────────────────
  static ThemeData get lightTokens {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF00B4D8),
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: bgPrimary,
      fontFamily: 'Segoe UI',
    );
  }

  static ThemeData get darkTokens {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: shellAccent,
        surface: shellSurface,
        outline: shellBorder,
      ),
      scaffoldBackgroundColor: shellBg,
      fontFamily: 'Segoe UI',
      // Slider theme
      sliderTheme: const SliderThemeData(
        thumbColor: shellAccent,
        activeTrackColor: shellAccent,
        inactiveTrackColor: shellBorderSub,
        overlayColor: Color(0x1A00D4FF),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
        trackHeight: 2,
      ),
      // DropdownButton / DropdownMenu theme
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(color: shellTextSub, fontSize: 11, fontFamily: 'monospace'),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(shellCard),
        ),
      ),
      // Divider
      dividerColor: shellBorder,
      // PopupMenu
      popupMenuTheme: const PopupMenuThemeData(
        color: shellCard,
        textStyle: TextStyle(color: shellText, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          side: BorderSide(color: shellBorder),
        ),
      ),
    );
  }
}
