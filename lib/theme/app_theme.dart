import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Design tokens (Workout / Fitness tracker aesthetic) ──────────────────────
class AppColors {
  AppColors._();

  // Canvas & surfaces
  static const canvas     = Color(0xFF06060B);
  static const surface1   = Color(0xFF101018);
  static const surface2   = Color(0xFF18182A);
  static const surface3   = Color(0xFF222236);
  static const border     = Color(0xFF2A2A3C);
  static const borderLight= Color(0xFF35354A);

  // Text hierarchy
  static const textPrimary   = Color(0xFFF0F0F5);
  static const textSecondary = Color(0xFF9898B0);
  static const textMuted     = Color(0xFF5C5C78);

  // Accent – electric mint (workout green)
  static const accent     = Color(0xFF00E599);
  static const accentDim  = Color(0x2200E599);  // 13 %

  // Status
  static const success = Color(0xFF00E599);
  static const error   = Color(0xFFFF4466);
  static const warning = Color(0xFFFFAA33);
  static const info    = Color(0xFF4A9DFF);

  // ── Per‑roadmap palette ────────────────────────────────────────────────────
  static const _roadmapPalette = <String, Color>{
    'sql':         Color(0xFF4A9DFF),
    'docker':      Color(0xFF2496ED),
    'python':      Color(0xFFFFD43B),
    'kubernetes':  Color(0xFF326CE5),
    'aws':         Color(0xFFFF9900),
    'frontend':    Color(0xFFE44D26),
    'backend':     Color(0xFF68BC71),
    'react':       Color(0xFF61DAFB),
    'javascript':  Color(0xFFF7DF1E),
    'typescript':  Color(0xFF3178C6),
    'java':        Color(0xFFED8B00),
    'golang':      Color(0xFF00ADD8),
    'rust':        Color(0xFFDEA584),
    'flutter':     Color(0xFF02569B),
    'devops':      Color(0xFFFF6B6B),
    'ai-engineer': Color(0xFFA855F7),
    'nodejs':      Color(0xFF68BC71),
    'angular':     Color(0xFFDD0031),
    'vue':         Color(0xFF42B883),
  };

  /// Fallback cycles through a fixed palette when the slug isn't known.
  static final _fallback = [
    const Color(0xFF4A9DFF),
    const Color(0xFFA855F7),
    const Color(0xFFFF6B6B),
    const Color(0xFF00ADD8),
    const Color(0xFFFFAA33),
    const Color(0xFF68BC71),
    const Color(0xFFE44D26),
    const Color(0xFF61DAFB),
  ];

  static Color roadmapColor(String id) {
    return _roadmapPalette[id.toLowerCase()] ??
        _fallback[id.hashCode.abs() % _fallback.length];
  }

  // ── Topic‑name display fixer ───────────────────────────────────────────────
  static const _abbreviations = {
    'sql', 'api', 'rest', 'css', 'html', 'json', 'xml', 'http', 'https',
    'url', 'uri', 'aws', 'gcp', 'oop', 'acid', 'orm', 'jwt', 'oauth',
    'saml', 'ldap', 'dns', 'tcp', 'udp', 'ip', 'ssh', 'ssl', 'tls',
    'cdn', 'ci', 'cd', 'ioc', 'di', 'mvc', 'mvvm', 'iam', 'vpc', 'rds',
    'ec2', 's3', 'ecs', 'eks', 'sns', 'sqs', 'cqrs', 'ddd', 'eda',
  };

  static String fixTopicName(String raw) {
    return raw.split(' ').map((w) {
      if (_abbreviations.contains(w.toLowerCase())) return w.toUpperCase();
      return w;
    }).join(' ');
  }
}

// ── Theme ────────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final base = ThemeData.dark();
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.canvas,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.accent,
        surface: AppColors.surface1,
        error: AppColors.error,
        onPrimary: AppColors.canvas,
        onSecondary: AppColors.canvas,
        onSurface: AppColors.textPrimary,
        outline: AppColors.border,
      ),
      textTheme: textTheme,
      cardTheme: CardTheme(
        color: AppColors.surface1,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.canvas,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface2,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}
