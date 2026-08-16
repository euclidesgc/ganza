import 'package:equatable/equatable.dart';

enum Flavor { dev, prod }

class AppConfig extends Equatable {
  const AppConfig({
    required this.flavor,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.apiBaseUrl,
  });

  /// Lido de `--dart-define-from-file`. Nada aqui é segredo: a anon key é
  /// pública por desenho (quem protege é a RLS) e as URLs são endereços.
  /// Chave de terceiro nunca entra — o binário se descompila.
  factory AppConfig.fromEnvironment() {
    const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
    return AppConfig(
      flavor: flavor == 'prod' ? Flavor.prod : Flavor.dev,
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    );
  }

  final Flavor flavor;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String apiBaseUrl;

  bool get isComplete =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      apiBaseUrl.isNotEmpty;

  @override
  List<Object?> get props => [flavor, supabaseUrl, supabaseAnonKey, apiBaseUrl];
}
