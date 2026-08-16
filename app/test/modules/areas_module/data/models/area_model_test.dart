import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/error/failure.dart';
import 'package:ganza/modules/areas_module/data/models/area_model.dart';

void main() {
  Map<String, dynamic> linhaValida() => {
    'id': '11111111-1111-1111-1111-111111111111',
    'slug': 'rotina-pessoal',
    'name': 'Rotina pessoal',
    'position': 0,
    'is_system': true,
    'icon': null,
    'color': null,
  };

  group('AreaModel', () {
    test('linha do PostgREST vira entidade', () {
      final resultado = AreaModel.fromMap(linhaValida());
      final area = resultado.getOrElse(
        (_) => throw StateError('esperava sucesso'),
      );

      expect(area.slug, 'rotina-pessoal');
      expect(area.name, 'Rotina pessoal');
      expect(area.isSystem, isTrue);
      expect(area.icon, isNull);
    });

    // Se a migration renomear uma coluna, isto precisa falhar aqui — e não
    // virar `null` silencioso três telas adiante.
    test('coluna faltando vira ValidationFailure, não nulo silencioso', () {
      final semNome = linhaValida()..remove('name');
      expect(
        AreaModel.fromMap(semNome).getLeft().toNullable(),
        isA<ValidationFailure>(),
      );
    });

    test('tipo trocado vira ValidationFailure', () {
      final posicaoTexto = linhaValida()..['position'] = 'primeiro';
      expect(
        AreaModel.fromMap(posicaoTexto).getLeft().toNullable(),
        isA<ValidationFailure>(),
      );
    });
  });
}
