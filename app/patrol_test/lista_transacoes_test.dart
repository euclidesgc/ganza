// E2E da listagem de transações — T3.8 da Fase 3
// (docs/001_cadastro_manual).
//
// INSTRUMENTAÇÃO TEMPORÁRIA: este arquivo e a dev_dependency `patrol` saem no
// wrap do E2E. Nada aqui é compilado no binário de produção (fora de `lib/`).
//
// Não é chamado à mão: quem orquestra é
// `docs/001_cadastro_manual/e2e_shots.sh`, que passa a cena por
// `--dart-define` e recolhe PNG e log pelo Patrol.
//
// A sessão entra por `recoverSession` com um JWT emitido fora do app, porque a
// senha do dono não está (e não deve estar) ao alcance do QA. O caminho de
// rede daqui para a frente é o real: PostgREST local, RLS de verdade.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/app.dart';
import 'package:ganza/core/config/app_config.dart';
import 'package:ganza/injection.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:patrol/patrol.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _cena = String.fromEnvironment('E2E_CENA');
const _arquivo = String.fromEnvironment('E2E_ARQUIVO');
const _evidenceUrl = String.fromEnvironment('E2E_EVIDENCE_URL');
const _jwt = String.fromEnvironment('E2E_JWT');
const _userId = String.fromEnvironment('E2E_USER_ID');
const _email = String.fromEnvironment('E2E_EMAIL');

const _vazio = 'Nenhuma transação registrada.';
const _tentarDeNovo = 'Tentar de novo';

void main() {
  patrolTest('cena $_cena', ($) async {
    final tester = $.tester;
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
        expect(find.text('14/08, sexta'), findsNWidgets(2));

        // Fuso. A linha está guardada em 2026-08-16T01:30:00+00:00, que em
        // America/Sao_Paulo é 22:30 do dia 15 — o dia que o usuário viveu.
        // Formatar em UTC (o bug corrigido em fc78ab3) daria '16/08, domingo';
        // por isso a ausência dessa string é asserção, não observação.
        expect(find.text('Venda de sábado à noite'), findsOneWidget);
        expect(find.text('15/08, sábado'), findsOneWidget);
        expect(find.text('16/08, domingo'), findsNothing);

        // Valor grande e valor curto na MESMA lista, com sinais opostos: é o
        // par que denuncia fonte sem algarismo tabular e coluna que dança.
        expect(find.text('+R\$ 1.234.567,89'), findsOneWidget);
        expect(find.text('Café'), findsOneWidget);
        expect(find.text('−R\$ 7,00'), findsOneWidget);

        // A metade do prefixo `−`/`+` "além da cor" que a máquina consegue
        // afirmar: o sinal está no texto, as duas cores são diferentes entre
        // si, e o estilo do valor carrega algarismos tabulares. Se as cores
        // são as certas e a coluna não dança é o olho que julga, no print.
        final entrada = _estiloDoValor(tester, '+R\$ 1.234.567,89');
        final saida = _estiloDoValor(tester, '−R\$ 7,00');
        expect(entrada.color, isNotNull);
        expect(entrada.color, isNot(saida.color));
        expect(
          entrada.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
        expect(
          saida.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );

        expect(find.text(_vazio), findsNothing);
        expect(find.text(_tentarDeNovo), findsNothing);

      default:
        fail('cena desconhecida: "$_cena"');
    }

    await _capturarEvidencia(tester, _arquivo);
  });
}

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

Future<void> _capturarEvidencia(WidgetTester tester, String nome) async {
  expect(_evidenceUrl, isNotEmpty, reason: 'faltou E2E_EVIDENCE_URL');
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('$_evidenceUrl/$nome'));
    final response = await request.close();
    expect(response.statusCode, 204, reason: 'falhou a captura $nome');
  } finally {
    client.close(force: true);
  }
}

/// Entra pela porta que o usuário usa — o botão da `AppBar` da AreasPage
/// (decisão A6) — e não por injeção de rota: o caminho é parte do que se prova.
Future<void> _irParaTransacoes(WidgetTester tester) async {
  await _aguardar(tester, find.byTooltip('Ver transações'));
  await tester.tap(find.byTooltip('Ver transações'));
  await _aguardar(tester, find.text('Transações'));

  // A rota é empilhada (`pushNamed`, fix 96ff5b5), não trocada: sem pilha o
  // `AppBar` não gera o leading e a tela vira um beco sem saída. Vale para as
  // três cenas — a entrada é a mesma.
  expect(find.byType(BackButton), findsOneWidget);
}

/// O estilo efetivamente aplicado ao `Text` do valor — é onde moram a cor da
/// direção e os algarismos tabulares.
TextStyle _estiloDoValor(WidgetTester tester, String texto) {
  final estilo = tester.widget<Text>(find.text(texto)).style;
  expect(estilo, isNotNull, reason: 'valor "$texto" sem estilo');
  return estilo!;
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
