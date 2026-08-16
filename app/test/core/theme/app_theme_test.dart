import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/theme/theme.dart';

void main() {
  group('AppTheme', () {
    // `context.ganza` faz `!` na extensão. Se um tema esquecer de registrá-la,
    // toda tela que usa cor de estado quebra em runtime, não na compilação.
    test('os dois temas registram GanzaColors', () {
      expect(AppTheme.light.extension<GanzaColors>(), isNotNull);
      expect(AppTheme.dark.extension<GanzaColors>(), isNotNull);
    });

    test('o tema claro e o escuro têm superfícies distintas', () {
      expect(
        AppTheme.light.colorScheme.surface,
        isNot(AppTheme.dark.colorScheme.surface),
      );
    });

    test('o primário é o ocre nos dois temas — a cor do instrumento', () {
      expect(AppTheme.light.colorScheme.primary, AppColors.ocre);
      expect(AppTheme.dark.colorScheme.primary, AppColors.ocre);
    });

    test('botões respeitam o alvo mínimo de toque', () {
      final estilo = AppTheme.light.filledButtonTheme.style;
      final tamanho = estilo?.minimumSize?.resolve({});
      expect(tamanho?.height, AppSpacing.touchTarget);
    });

    test('valor monetário usa algarismos tabulares', () {
      expect(
        AppTypography.valor.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });
  });
}
