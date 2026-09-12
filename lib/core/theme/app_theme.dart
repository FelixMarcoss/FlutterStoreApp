import 'package:flutter/material.dart';

/// Cores centralizadas do app — nunca usar `Color(0xFF...)` direto nos widgets.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0B3D91);
  static const Color primaryDark = Color(0xFF072859);
  static const Color background = Color(0xFFF4F6F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color stroke = Color(0xFFE0E4EA);
  static const Color textPrimary = Color(0xFF1B1F27);
  static const Color textSecondary = Color(0xFF5A6472);

  /// Ladrão com histórico confirmado — o nível de risco mais alto.
  static const Color danger = Color(0xFFD32F2F);
  static const Color dangerBackground = Color(0xFFFDE8E8);

  /// Pessoa suspeita, sem confirmação de furto anterior.
  static const Color warning = Color(0xFFE68A00);
  static const Color warningBackground = Color(0xFFFFF3E0);

  /// Pessoa nova, sem histórico no sistema.
  static const Color neutral = Color(0xFF546E7A);
  static const Color neutralBackground = Color(0xFFECEFF1);

  static const Color success = Color(0xFF2E7D32);
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.stroke),
      ),
    ),
  );
}
