import 'package:equatable/equatable.dart';

enum Flavor { dev, prod }

class AppConfig extends Equatable {
  const AppConfig({
    required this.flavor,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  /// Lido de `--dart-define-from-file`. Nada aqui é segredo: a anon key é
  /// pública por desenho (quem protege é a RLS) e a URL é um endereço.
  /// Chave de terceiro nunca entra — o binário se descompila.
  ///
  /// Não existe `API_BASE_URL`: a D10 revogou o backend NestJS separado — a
  /// lógica de servidor são Edge Functions no próprio Supabase, alcançadas em
  /// `$SUPABASE_URL/functions/v1` (ver [dio_factory.dart]).
  factory AppConfig.fromEnvironment() {
    const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
    return AppConfig(
      flavor: flavor == 'prod' ? Flavor.prod : Flavor.dev,
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
  }

  final Flavor flavor;
  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get isComplete => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  @override
  List<Object?> get props => [flavor, supabaseUrl, supabaseAnonKey];
}
