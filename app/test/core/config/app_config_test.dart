import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('isComplete só quando as três informações estão presentes', () {
      const completo = AppConfig(
        flavor: Flavor.dev,
        supabaseUrl: 'http://exemplo',
        supabaseAnonKey: 'chave',
        apiBaseUrl: 'http://api',
      );
      expect(completo.isComplete, isTrue);

      expect(
        const AppConfig(
          flavor: Flavor.dev,
          supabaseUrl: '',
          supabaseAnonKey: 'chave',
          apiBaseUrl: 'http://api',
        ).isComplete,
        isFalse,
      );

      expect(
        const AppConfig(
          flavor: Flavor.dev,
          supabaseUrl: 'http://exemplo',
          supabaseAnonKey: '',
          apiBaseUrl: 'http://api',
        ).isComplete,
        isFalse,
      );
    });

    // Se isto passar a devolver `true` sem dart-define, o bootstrap deixa de
    // barrar um build mal configurado e o app sobe apontando para lugar nenhum.
    test('fromEnvironment sem dart-define devolve config incompleta', () {
      expect(AppConfig.fromEnvironment().isComplete, isFalse);
    });
  });
}
