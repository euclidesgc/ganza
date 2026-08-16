import 'package:flutter/material.dart';

abstract final class AppTypography {
  /// Fraunces nos títulos: traço levemente irregular, combina com o material
  /// artesanal do instrumento.
  static const familiaTitulo = 'Fraunces';

  /// IBM Plex Sans no corpo e nos números. A escolha é pelos algarismos
  /// tabulares: coluna de valores que dança entre linhas é bug visual.
  static const familiaCorpo = 'IBMPlexSans';

  static const List<FontFeature> algarismosTabulares = [
    FontFeature.tabularFigures(),
  ];

  static const TextTheme base = TextTheme(
    displayLarge: TextStyle(
      fontFamily: familiaTitulo,
      fontSize: 34,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    displayMedium: TextStyle(
      fontFamily: familiaTitulo,
      fontSize: 28,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
    headlineMedium: TextStyle(
      fontFamily: familiaTitulo,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    titleLarge: TextStyle(
      fontFamily: familiaTitulo,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    titleMedium: TextStyle(
      fontFamily: familiaCorpo,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    bodyLarge: TextStyle(fontFamily: familiaCorpo, fontSize: 16, height: 1.5),
    bodyMedium: TextStyle(fontFamily: familiaCorpo, fontSize: 14, height: 1.5),
    bodySmall: TextStyle(fontFamily: familiaCorpo, fontSize: 12, height: 1.4),
    labelLarge: TextStyle(
      fontFamily: familiaCorpo,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
  );

  static const TextStyle valor = TextStyle(
    fontFamily: familiaCorpo,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    fontFeatures: algarismosTabulares,
  );

  static const TextStyle valorGrande = TextStyle(
    fontFamily: familiaCorpo,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    fontFeatures: algarismosTabulares,
  );
}
