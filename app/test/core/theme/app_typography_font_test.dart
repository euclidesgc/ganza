// Prova com a fonte REAL bundled (não o fallback de teste do Flutter): os
// algarismos tabulares só valem se o `.ttf` carregou de verdade, e o peso
// só sai certo se o eixo `wght` variou de fato — as duas coisas que o
// fallback do sistema não garante.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/theme/theme.dart';

Future<void> _carregarFonteReal(String familia, String asset) async {
  final loader = FontLoader(familia)..addFont(rootBundle.load(asset));
  await loader.load();
}

double _largura(String texto, TextStyle estilo) {
  final painter = TextPainter(
    text: TextSpan(text: texto, style: estilo),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

/// Conta pixels que não são o fundo branco puro — proxy de "quanto traço a
/// fonte pintou" para provar que o eixo de peso realmente moveu o glifo.
Future<int> _coberturaDeTinta(TextStyle estilo, String texto) async {
  final painter = TextPainter(
    text: TextSpan(
      text: texto,
      style: estilo.copyWith(color: const Color(0xFF000000)),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
  painter.paint(canvas, Offset.zero);
  final image = await recorder.endRecording().toImage(
    painter.width.ceil().clamp(1, 4000),
    painter.height.ceil().clamp(1, 4000),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final data = bytes!.buffer.asUint8List();
  var tinta = 0;
  for (var i = 0; i < data.length; i += 4) {
    if (data[i] != 255 || data[i + 1] != 255 || data[i + 2] != 255) tinta++;
  }
  return tinta;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _carregarFonteReal(
      AppTypography.familiaCorpo,
      'assets/fonts/IBMPlexSans.ttf',
    );
    await _carregarFonteReal(
      AppTypography.familiaTitulo,
      'assets/fonts/Fraunces.ttf',
    );
  });

  group('algarismos tabulares com a fonte carregada de verdade', () {
    test(
      'valores de mesma contagem de dígitos ocupam a mesma largura (valor)',
      () {
        final pequeno = _largura('111,11', AppTypography.valor);
        final grande = _largura('999,99', AppTypography.valor);
        expect(pequeno, grande);
      },
    );

    test(
      'valores de mesma contagem de dígitos ocupam a mesma largura (valorGrande)',
      () {
        final a = _largura('1.234.567,89', AppTypography.valorGrande);
        final b = _largura('7.654.321,00', AppTypography.valorGrande);
        expect(a, b);
      },
    );

    test(
      'sanidade: mais dígitos é mais largura — a métrica não é um no-op',
      () {
        final curto = _largura('1,00', AppTypography.valor);
        final longo = _largura('111,00', AppTypography.valor);
        expect(longo, greaterThan(curto));
      },
    );
  });

  group('o eixo de peso (wght) realmente varia com FontVariation', () {
    test(
      'titleLarge (Fraunces, semibold) pinta mais que o mesmo texto no wght mínimo',
      () async {
        // Comparador construído do zero, sem `copyWith` sobre um estilo que já
        // tem `fontWeight: w600` — misturar um `fontWeight` fixo com outro
        // `fontVariations` no mesmo TextStyle gera sinal ambíguo (os dois
        // tentam mover o mesmo eixo `wght`) e o teste deixa de provar algo
        // limpo.
        const texto = 'Ganza';
        final semibold = await _coberturaDeTinta(
          AppTypography.base.titleLarge!,
          texto,
        );
        const leveStyle = TextStyle(
          fontFamily: AppTypography.familiaTitulo,
          fontSize: 18,
          fontWeight: FontWeight.w100,
          fontVariations: [FontVariation.weight(100)],
        );
        final leve = await _coberturaDeTinta(leveStyle, texto);
        expect(semibold, greaterThan(leve));
      },
    );

    test(
      'valor (IBM Plex Sans, semibold) pinta mais que o mesmo texto regular',
      () async {
        const texto = '123,45';
        final semibold = await _coberturaDeTinta(AppTypography.valor, texto);
        const regularStyle = TextStyle(
          fontFamily: AppTypography.familiaCorpo,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          fontVariations: [FontVariation.weight(400)],
          fontFeatures: AppTypography.algarismosTabulares,
        );
        final regular = await _coberturaDeTinta(regularStyle, texto);
        expect(semibold, greaterThan(regular));
      },
    );
  });
}
