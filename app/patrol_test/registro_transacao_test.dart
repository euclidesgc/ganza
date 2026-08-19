// E2E do registro de transação pelo app — T4.7 da Fase 4
// (docs/001_cadastro_manual).
//
// INSTRUMENTAÇÃO TEMPORÁRIA: este arquivo, o irmão
// `lista_transacoes_test.dart` e a dev_dependency `patrol` saem no wrap do
// E2E. Nada aqui é compilado no binário de produção (tudo fora de `lib/`).
//
// Não é chamado à mão: quem orquestra é
// `docs/001_cadastro_manual/e2e_registro_shots.sh`, que passa a cena e os
// valores esperados por `--dart-define` codificados em base64 e recolhe PNGs
// pelo Patrol.
//
// O registro é feito PELO APP: o campo de valor recebe dígito a dígito, a data
// sai do seletor e o botão Registrar é tocado pelo Patrol. Nenhuma linha desta
// rodada nasce de `curl` — as duas linhas antigas que a lista já mostra são
// semeadas pelo script justamente para que a linha do app dispute o topo.
//
// Rota empilhada: com o formulário aberto, a lista continua montada embaixo.
// Por isso as asserções do formulário são escopadas em `NewTransactionForm` —
// sem isso, a mensagem de erro da lista offline responderia pela do formulário
// e a prova fecharia sozinha.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/app.dart';
import 'package:ganza/core/config/app_config.dart';
import 'package:ganza/core/theme/theme.dart';
import 'package:ganza/injection.dart';
import 'package:ganza/modules/transactions_module/presentation/new_transaction/widgets/new_transaction_error_banner.dart';
import 'package:ganza/modules/transactions_module/presentation/new_transaction/widgets/new_transaction_form.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:patrol/patrol.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _cena = String.fromEnvironment('E2E_CENA');
const _evidenceUrl = String.fromEnvironment('E2E_EVIDENCE_URL');
const _jwt = String.fromEnvironment('E2E_JWT');
const _jwtExpirado = String.fromEnvironment('E2E_JWT_EXPIRADO');
const _userId = String.fromEnvironment('E2E_USER_ID');
const _email = String.fromEnvironment('E2E_EMAIL');

/// O que o formulário recebe e o que a tela tem de mostrar depois. Vem do
/// script para que o esperado seja calculado FORA do app — um oráculo que não
/// é o próprio formatador sob prova.
const _descricaoBase64 = String.fromEnvironment('E2E_DESCRICAO_B64');
const _digitos = String.fromEnvironment('E2E_DIGITOS');
const _valorNoCampoBase64 = String.fromEnvironment('E2E_VALOR_CAMPO_B64');
const _valorNaListaBase64 = String.fromEnvironment('E2E_VALOR_LISTA_B64');
const _diaDeOntem = String.fromEnvironment('E2E_DIA_ONTEM');
const _dataDeOntemBase64 = String.fromEnvironment('E2E_DATA_ONTEM_B64');
const _seedRecenteBase64 = String.fromEnvironment('E2E_SEED_RECENTE_B64');
const _seedAntigaBase64 = String.fromEnvironment('E2E_SEED_ANTIGA_B64');

const _semConexao = 'Sem conexão com o servidor.';
const _erroGenerico = 'Algo deu errado. Tente de novo.';
const _sessaoExpirada = 'Sua sessão expirou. Entre de novo.';

void main() {
  final descricao = _decodeDefine(_descricaoBase64);
  final valorNoCampo = _decodeDefine(_valorNoCampoBase64);
  final valorNaLista = _decodeDefine(_valorNaListaBase64);
  final dataDeOntem = _decodeDefine(_dataDeOntemBase64);
  final seedRecente = _decodeDefine(_seedRecenteBase64);
  final seedAntiga = _decodeDefine(_seedAntigaBase64);

  patrolTest('cena $_cena', ($) async {
    final tester = $.tester;
    await _subirApp(tester);
    await _irParaTransacoes(tester);

    switch (_cena) {
      // Invariante nº 1 do CLAUDE.md: nada é gravado sem toque explícito em
      // Registrar. O formulário é preenchido por inteiro e abandonado pelo
      // botão de voltar; a contagem antes/depois é conferida pelo script.
      case 'abandono':
        await _abrirFormulario(tester);
        await _preencher(tester, descricao, valorNoCampo, dataDeOntem);
        await _capturarEvidencia(tester, '06_formulario_abandonado');

        await tester.tap(find.byType(BackButton));
        await _aguardarSumir(tester, find.byType(NewTransactionForm));
        expect(find.text('Transações'), findsOneWidget);

      // Caminho feliz: formulário preenchido → Registrar → lista com a linha
      // nova no topo. O topo é asserção de posição, não leitura do print.
      case 'feliz':
        await _aguardar(tester, find.text(seedRecente));
        await _abrirFormulario(tester);
        await _preencher(tester, descricao, valorNoCampo, dataDeOntem);
        await _capturarEvidencia(tester, '01_formulario_preenchido');

        await tester.tap(_botaoRegistrar);
        await _aguardar(tester, find.text(valorNaLista));
        await tester.pump(const Duration(milliseconds: 400));

        // O formulário saiu de cena (`pop`) e a lista foi refeita pelo
        // PostgREST — a descrição só existe uma vez, na linha nova.
        expect(find.byType(NewTransactionForm), findsNothing);
        expect(find.text(descricao), findsOneWidget);
        expect(find.text(dataDeOntem), findsOneWidget);

        final novaLinha = tester.getTopLeft(find.text(descricao)).dy;
        expect(
          novaLinha,
          lessThan(tester.getTopLeft(find.text(seedRecente)).dy),
        );
        expect(
          novaLinha,
          lessThan(tester.getTopLeft(find.text(seedAntiga)).dy),
        );

        await _capturarEvidencia(tester, '02_lista_com_a_linha_nova');

      // Botão desabilitado durante o envio + toque duplo. O segundo toque cai
      // num botão com `onPressed` nulo; que ele não virou linha é o `count`
      // que o script confere depois.
      case 'duplo':
        await _abrirFormulario(tester);
        await _preencher(tester, descricao, valorNoCampo, dataDeOntem);

        await tester.tap(_botaoRegistrar);
        await tester.pump();

        expect(_noFormulario(find.text('Registrando…')), findsOneWidget);
        expect(_noFormulario(find.text('Registrar')), findsNothing);
        expect(_widgetDoBotao(tester).onPressed, isNull);

        // O segundo toque do dedo apressado, no mesmo lugar.
        await tester.tap(_botaoEmVoo, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 50));
        expect(_widgetDoBotao(tester).onPressed, isNull);

        await _capturarEvidencia(tester, '05_botao_desabilitado_durante_envio');
        await _aguardar(tester, find.text(valorNaLista));

      // Falha (a): sem rede. Mensagem curta e específica no formulário, e o
      // que a pessoa digitou continua lá.
      case 'sem_rede':
        await _abrirFormulario(tester);
        await _preencher(tester, descricao, valorNoCampo, dataDeOntem);

        await tester.tap(_botaoRegistrar);
        await _aguardar(
          tester,
          find.descendant(
            of: find.byType(NewTransactionErrorBanner),
            matching: find.text(_semConexao),
          ),
        );

        expect(find.text(_erroGenerico), findsNothing);
        expect(find.byType(NewTransactionForm), findsOneWidget);
        expect(_campoValorWidget(tester).controller?.text, valorNoCampo);
        expect(_campoDescricaoWidget(tester).controller?.text, descricao);
        expect(_rotuloDaData(dataDeOntem), findsOneWidget);
        expect(_noFormulario(find.text('Registrar')), findsOneWidget);

        await _capturarEvidencia(tester, '03_sem_rede_campos_preservados');

      // Falha (b): sessão expirada. `setSession` com o access token vencido e
      // um refresh token que o GoTrue recusa é o mesmo caminho que o cliente
      // percorre sozinho quando o token vence — ele vê o `exp` no passado,
      // tenta renovar, leva 400, apaga a sessão e emite `signedOut`. O que se
      // prova aqui é a reação do app a esse evento.
      case 'sessao_expirada':
        await _abrirFormulario(tester);
        await _preencher(tester, descricao, valorNoCampo, dataDeOntem);

        try {
          await Supabase.instance.client.auth.setSession(
            'refresh-token-invalidado-pelo-e2e',
            accessToken: _jwtExpirado,
          );
        } on AuthException catch (_) {
          // Esperado: é a recusa do servidor que dispara o `signedOut`.
        }

        await _aguardar(tester, find.text('Entrar'));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('E-mail'), findsOneWidget);
        expect(find.text('Senha'), findsOneWidget);
        expect(find.byType(NewTransactionForm), findsNothing);
        expect(find.text('Transações'), findsNothing);
        expect(find.text(_erroGenerico), findsNothing);
        expect(find.text(_sessaoExpirada), findsNothing);

        await _capturarEvidencia(tester, '04_sessao_expirada_login');

      default:
        fail('cena desconhecida: "$_cena"');
    }
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

/// Entra pela porta que o usuário usa — o botão da `AppBar` da AreasPage
/// (decisão A6) — e não por injeção de rota.
Future<void> _irParaTransacoes(WidgetTester tester) async {
  await _aguardar(tester, find.byTooltip('Ver transações'));
  await tester.tap(find.byTooltip('Ver transações'));
  await _aguardar(tester, find.text('Transações'));
}

Future<void> _abrirFormulario(WidgetTester tester) async {
  await _aguardar(tester, find.byTooltip('Registrar transação'));
  await tester.tap(find.byTooltip('Registrar transação'));
  await _aguardar(tester, find.byType(NewTransactionForm));
  await tester.pump(const Duration(milliseconds: 400));

  // Default da decisão: Despesa, com rótulo textual visível.
  expect(find.text('Nova transação'), findsOneWidget);
  expect(_noFormulario(find.text('Despesa')), findsOneWidget);
  expect(_noFormulario(find.text('Receita')), findsOneWidget);
  expect(_widgetDoBotao(tester).onPressed, isNull, reason: 'vazio é inválido');
}

/// Preenche os quatro campos e confere que o botão só habilitou depois.
Future<void> _preencher(
  WidgetTester tester,
  String descricao,
  String valorNoCampo,
  String dataDeOntem,
) async {
  await _digitarValor(tester, _digitos);
  await tester.enterText(_campoDescricao, descricao);
  await tester.pump();
  await _escolherOntem(tester);

  expect(_campoValorWidget(tester).controller?.text, valorNoCampo);
  expect(_rotuloDaData(dataDeOntem), findsOneWidget);
  expect(_widgetDoBotao(tester).onPressed, isNotNull);
}

/// Dígito a dígito, entrando pela direita — é assim que o campo é usado, e é
/// o único jeito de exercitar o acumulador de centavos. Um `enterText` com o
/// texto inteiro pularia o formatador que está sob prova.
Future<void> _digitarValor(WidgetTester tester, String digitos) async {
  for (final digito in digitos.split('')) {
    final atual = _campoValorWidget(tester).controller?.text ?? '';
    await tester.enterText(_campoValor, '$atual$digito');
    await tester.pump();
  }
}

/// Ontem pelo seletor de data, como o usuário faria. O dia de amanhã não é
/// alcançável (trava de futuro da T4.5), então o toque é sempre para trás.
Future<void> _escolherOntem(WidgetTester tester) async {
  await tester.tap(_botaoDaData);
  await tester.pumpAndSettle();

  final dia = find.descendant(
    of: find.byType(DatePickerDialog),
    matching: find.text(_diaDeOntem),
  );
  expect(dia, findsOneWidget);
  await tester.tap(dia);
  await tester.pump();

  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Finder _noFormulario(Finder alvo) =>
    find.descendant(of: find.byType(NewTransactionForm), matching: alvo);

Finder get _botaoRegistrar =>
    _noFormulario(find.widgetWithText(FilledButton, 'Registrar'));

/// Em voo o botão troca de rótulo, então achar por texto não serve.
Finder get _botaoEmVoo => _noFormulario(find.byType(FilledButton));

Finder get _botaoDaData =>
    _noFormulario(find.widgetWithIcon(OutlinedButton, AppIcons.dateField));

Finder _rotuloDaData(String dataDeOntem) =>
    find.descendant(of: _botaoDaData, matching: find.text(dataDeOntem));

Finder get _campoValor => _noFormulario(
  find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == 'Valor',
  ),
);

Finder get _campoDescricao => _noFormulario(
  find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.labelText == 'Descrição',
  ),
);

TextField _campoValorWidget(WidgetTester tester) =>
    tester.widget<TextField>(_campoValor);

TextField _campoDescricaoWidget(WidgetTester tester) =>
    tester.widget<TextField>(_campoDescricao);

FilledButton _widgetDoBotao(WidgetTester tester) =>
    tester.widget<FilledButton>(_botaoEmVoo);

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

String _decodeDefine(String value) {
  if (value.isEmpty) {
    throw StateError('faltou parâmetro codificado do cenário');
  }
  return utf8.decode(base64Decode(value));
}

/// `pumpAndSettle` não serve aqui: o `CircularProgressIndicator` do estado de
/// carregamento nunca "assenta", e a espera morreria no timeout justamente na
/// cena que mais depende da rede.
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

Future<void> _aguardarSumir(
  WidgetTester tester,
  Finder alvo, {
  Duration limite = const Duration(seconds: 30),
}) async {
  final prazo = DateTime.now().add(limite);
  while (DateTime.now().isBefore(prazo)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (alvo.evaluate().isEmpty) return;
  }
  fail('não sumiu em ${limite.inSeconds}s: $alvo');
}
