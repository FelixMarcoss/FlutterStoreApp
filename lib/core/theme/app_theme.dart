import 'package:flutter/material.dart';

/// Cores centralizadas do app — nunca usar `Color(0xFF...)` direto nos widgets.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2F6FD1);
  static const Color primaryDark = Color(0xFF214F9B);
  static const Color brandStart = Color(0xFF3B82F6);
  static const Color brandEnd = Color(0xFF60A5FA);
  static const Color background = Color(0xFF0B1016);
  static const Color surface = Color(0xFF141B24);
  static const Color surfaceElevated = Color(0xFF1B2530);
  static const Color stroke = Color(0xFF2B3745);
  static const Color textPrimary = Color(0xFFF3F6FA);
  static const Color textSecondary = Color(0xFFA9B4C0);

  /// Suspeito classificado no nível de risco mais alto.
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerStrong = Color(0xFFB3262D);
  static const Color dangerBackground = Color(0xFF3A1B20);

  /// Pessoa suspeita, sem confirmação de furto anterior.
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBackground = Color(0xFF382A17);

  /// Pessoa nova, sem histórico no sistema.
  static const Color neutral = Color(0xFF06B6D4);
  static const Color neutralBackground = Color(0xFF253039);

  /// Ação de confirmação inspirada na identidade visual do painel FaceTrack.
  static const Color action = Color(0xFF14C8BB);
  static const Color actionDark = Color(0xFF073C3A);

  static const Color success = Color(0xFF58D07D);
}

ThemeData buildAppTheme() {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        brightness: Brightness.dark,
      ).copyWith(
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.danger,
        onError: AppColors.textPrimary,
        outline: AppColors.stroke,
        surfaceContainerHighest: AppColors.surfaceElevated,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: ThemeData.dark().textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceElevated,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textSecondary),
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
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.surfaceElevated,
        disabledForegroundColor: AppColors.textSecondary,
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
    dividerTheme: const DividerThemeData(color: AppColors.stroke),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(color: AppColors.textPrimary),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceElevated,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.actionDark,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.action
              : AppColors.textSecondary,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? AppColors.action
              : AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
