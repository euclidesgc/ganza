import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'ganza_colors.dart';

/// Material humilde: superfície chapada, sem sombra pesada nem brilho. Se
/// parecer caro demais, errou o instrumento.
abstract final class AppTheme {
  static ThemeData get light => _build(
    brightness: Brightness.light,
    scheme: const ColorScheme.light(
      primary: AppColors.ocre,
      onPrimary: AppColors.palha,
      secondary: AppColors.latao,
      onSecondary: AppColors.couro,
      surface: AppColors.palha,
      onSurface: AppColors.couro,
      error: AppColors.terracota,
      onError: AppColors.palha,
    ),
    ganza: const GanzaColors(
      done: AppColors.verdeSeco,
      doneSoft: Color(0xFFDCE3D3),
      overdue: AppColors.terracota,
      overdueSoft: Color(0xFFF0D6CE),
      forecast: AppColors.latao,
      elevatedSurface: AppColors.palhaEscurecida,
      outline: AppColors.cascaClara,
      mutedInk: AppColors.couroSuave,
    ),
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    scheme: const ColorScheme.dark(
      primary: AppColors.ocre,
      onPrimary: AppColors.couro,
      secondary: AppColors.latao,
      onSecondary: AppColors.couro,
      surface: AppColors.couro,
      onSurface: AppColors.palha,
      error: AppColors.terracota,
      onError: AppColors.palha,
    ),
    ganza: const GanzaColors(
      done: AppColors.verdeSeco,
      doneSoft: Color(0xFF2C3527),
      overdue: AppColors.terracota,
      overdueSoft: Color(0xFF3D231C),
      forecast: AppColors.latao,
      elevatedSurface: AppColors.casca,
      outline: Color(0xFF4A4038),
      mutedInk: Color(0xFFA79C8E),
    ),
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required GanzaColors ganza,
  }) {
    final texts = AppTypography.base.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: texts,
      extensions: [ganza],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: texts.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: ganza.elevatedSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.borderMd,
          side: BorderSide(color: ganza.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.borderCapsule,
          ),
          textStyle: texts.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
          side: BorderSide(color: ganza.outline),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.borderCapsule,
          ),
          textStyle: texts.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ganza.elevatedSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.borderMd,
          borderSide: BorderSide(color: ganza.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.borderMd,
          borderSide: BorderSide(color: ganza.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.borderMd,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      dividerTheme: DividerThemeData(color: ganza.outline, space: 1),
      drawerTheme: DrawerThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        minTileHeight: AppSpacing.touchTarget,
        iconColor: scheme.onSurface,
        textColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : ganza.mutedInk,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.secondary
              : ganza.outline,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}
