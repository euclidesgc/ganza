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

  /// Fraunces e IBM Plex Sans são variable fonts: um único arquivo cobre
  /// toda a faixa de peso (eixo `wght`). `fontWeight` sozinho até funciona
  /// no engine atual quando a família tem **uma** entrada no `pubspec.yaml`
  /// (verificado por renderização real), mas depende de o engine mapear
  /// `FontWeight` → eixo — comportamento não documentado como contrato e
  /// que pode variar entre motor nativo (Android) e CanvasKit (Web). Quem
  /// move o eixo de forma garantida e explícita é `FontVariation`, por
  /// isso ele acompanha todo `fontWeight` abaixo.
  static const _pesoRegular = [FontVariation.weight(400)];
  static const _pesoSemiBold = [FontVariation.weight(600)];

  static const TextTheme base = TextTheme(
    displayLarge: TextStyle(
      fontFamily: familiaTitulo,
      fontSize: 34,
      fontWeight: FontWeight.w600,
      fontVariations: _pesoSemiBold,
      height: 1.2,
    ),
    displayMedium: TextStyle(
      fontFamily: familiaTitulo,
      fontSize: 28,
      fontWeight: FontWeight.w600,
      fontVariations: _pesoSemiBold,
      height: 1.2,
    ),
    headlineMedium: TextStyle(
      fontFamily: familiaTitulo,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      fontVariations: _pesoSemiBold,
      height: 1.3,
    ),
    titleLarge: TextStyle(
      fontFamily: familiaTitulo,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      fontVariations: _pesoSemiBold,
      height: 1.3,
    ),
    titleMedium: TextStyle(
      fontFamily: familiaCorpo,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      fontVariations: _pesoSemiBold,
      height: 1.4,
    ),
    bodyLarge: TextStyle(
      fontFamily: familiaCorpo,
      fontSize: 16,
      fontVariations: _pesoRegular,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontFamily: familiaCorpo,
      fontSize: 14,
      fontVariations: _pesoRegular,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontFamily: familiaCorpo,
      fontSize: 12,
      fontVariations: _pesoRegular,
      height: 1.4,
    ),
    labelLarge: TextStyle(
      fontFamily: familiaCorpo,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      fontVariations: _pesoSemiBold,
      height: 1.2,
    ),
  );

  static const TextStyle valor = TextStyle(
    fontFamily: familiaCorpo,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    fontVariations: _pesoSemiBold,
    fontFeatures: algarismosTabulares,
  );

  static const TextStyle valorGrande = TextStyle(
    fontFamily: familiaCorpo,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    fontVariations: _pesoSemiBold,
    fontFeatures: algarismosTabulares,
  );
}
