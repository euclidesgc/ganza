// E2E da listagem de transações — T3.8 da Fase 3 (docs/01-cadastro-manual).
//
// INSTRUMENTAÇÃO TEMPORÁRIA: este arquivo, `test_driver/integration_test.dart`
// e as dev_dependencies `integration_test`/`flutter_driver` saem no wrap do
// E2E. Nada aqui é compilado no binário de produção (fora de `lib/`).
//
// Não é chamado à mão: quem orquestra é `docs/01-cadastro-manual/e2e_shots.sh`,
// que passa a cena por `--dart-define` e recolhe o print pelo driver.
//
// A sessão entra por `recoverSession` com um JWT emitido fora do app, porque a
// senha do dono não está (e não deve estar) ao alcance do QA. O caminho de
// rede daqui para a frente é o real: PostgREST de produção, RLS de verdade.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/app.dart';
import 'package:ganza/core/config/app_config.dart';
import 'package:ganza/injection.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _cena = String.fromEnvironment('E2E_CENA');
const _arquivo = String.fromEnvironment('E2E_ARQUIVO');
const _jwt = String.fromEnvironment('E2E_JWT');
const _userId = String.fromEnvironment('E2E_USER_ID');
const _email = String.fromEnvironment('E2E_EMAIL');

const _vazio = 'Nenhuma transação registrada.';
const _tentarDeNovo = 'Tentar de novo';

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cena $_cena', (tester) async {
    await _subirApp(tester);
    await _irParaTransacoes(tester);

    switch (_cena) {
      case 'erro':
        // O estado de erro tem de aparecer COM a saída; a ausência do texto
        // do vazio é a prova de que uma falha não se disfarça de "nada aqui".
        await _aguardar(tester, find.text(_tentarDeNovo));
        expect(find.text(_vazio), findsNothing);

      case 'vazio':
        await _aguardar(tester, find.text(_vazio));
        expect(find.text(_tentarDeNovo), findsNothing);

      case 'lista':
        await _aguardar(tester, find.text('Almoço'));
        expect(find.text('−R\$ 45,00'), findsOneWidget);
        expect(find.text('14/08, sexta'), findsOneWidget);

        // Valor grande e valor curto na MESMA lista: é o par que denuncia
        // fonte sem algarismo tabular.
        expect(find.text('Reforma da cozinha'), findsOneWidget);
        expect(find.text('−R\$ 1.234.567,89'), findsOneWidget);
        expect(find.text('Café'), findsOneWidget);
        expect(find.text('−R\$ 7,00'), findsOneWidget);
        expect(find.text('15/08, sábado'), findsNWidgets(2));

        expect(find.text(_vazio), findsNothing);
        expect(find.text(_tentarDeNovo), findsNothing);

      default:
        fail('cena desconhecida: "$_cena"');
    }

    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot(_arquivo);
  });
}

/// Repete o que `bootstrap.dart` faz, menos o `runZonedGuarded` — o binding do
/// integration_test já nasceu na zona raiz, e `runApp` dentro de outra zona
/// aborta com "Zone mismatch" antes de qualquer tela subir.
Future<void> _subirApp(WidgetTester tester) async {
  await initializeDateFormatting('pt_BR');

  final config = AppConfig.fromEnvironment();
  expect(config.isComplete, isTrue, reason: 'faltou --dart-define-from-file');

  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabaseAnonKey,
  );
  registerDependencies(config);

  await Supabase.instance.client.auth.recoverSession(
    jsonEncode({
      'access_token': _jwt,
      'token_type': 'bearer',
      'expires_in': 43200,
      'user': {
        'id': _userId,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': _email,
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': '2026-01-01T00:00:00Z',
      },
    }),
  );

  await tester.pumpWidget(const GanzaApp());
}

/// Entra pela porta que o usuário usa — o botão da `AppBar` da AreasPage
/// (decisão A6) — e não por injeção de rota: o caminho é parte do que se prova.
Future<void> _irParaTransacoes(WidgetTester tester) async {
  await _aguardar(tester, find.byTooltip('Ver transações'));
  await tester.tap(find.byTooltip('Ver transações'));
  await _aguardar(tester, find.text('Transações'));
}

/// `pumpAndSettle` não serve aqui: o `CircularProgressIndicator` do estado de
/// carregamento nunca "assenta", e a espera morreria no timeout justamente na
/// cena de erro — a que mais demora.
Future<void> _aguardar(
  WidgetTester tester,
  Finder alvo, {
  Duration limite = const Duration(seconds: 90),
}) async {
  final prazo = DateTime.now().add(limite);
  while (DateTime.now().isBefore(prazo)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (alvo.evaluate().isNotEmpty) return;
  }
  fail('não apareceu em ${limite.inSeconds}s: $alvo');
}
