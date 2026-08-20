// E2E de cadastro e recuperação de senha — T1.10 da Fase 1
// (docs/002_conta_e_configuracoes).
//
// INSTRUMENTAÇÃO TEMPORÁRIA: este arquivo, os irmãos de `patrol_test/` e a
// dev_dependency `patrol` saem no wrap do E2E. Nada aqui é compilado no
// binário de produção (tudo fora de `lib/`).
//
// Não é chamado à mão: quem orquestra é `scripts/e2e-002-auth.sh`, chamado por
// `scripts/e2e-local.sh 002`. Ele passa a cena, o endereço gerado na execução e
// as URLs por `--dart-define`, e recolhe os PNGs pelo callback de captura.
//
// NENHUMA CENA AVANÇA PELO BANCO. Confirmar conta por `update` em auth.users,
// por chave de serviço ou por endpoint de admin provaria que o Postgres aceita
// escrita, não que uma pessoa consegue usar o app. A conta é criada pela tela
// de cadastro, confirmada pelo token que chegou na mensagem capturada e usada
// para entrar pela tela de entrar.
//
// O SERVIDOR RECUSA DOIS E-MAILS SEGUIDOS PARA O MESMO ENDEREÇO (janela de
// ~60s, `over_email_send_rate_limit`). Cada execução usa um endereço próprio,
// cadastra uma vez e pede recuperação uma vez; o espaçamento entre os dois
// envios é responsabilidade do orquestrador.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/app.dart';
import 'package:ganza/core/config/app_config.dart';
import 'package:ganza/injection.dart';
import 'package:ganza/modules/auth_module/presentation/login/widgets/login_error_banner.dart';
import 'package:ganza/modules/auth_module/presentation/login/widgets/login_form.dart';
import 'package:ganza/modules/auth_module/presentation/password_recovery/widgets/code_step_form.dart';
import 'package:ganza/modules/auth_module/presentation/password_recovery/widgets/failure_banner.dart';
import 'package:ganza/modules/auth_module/presentation/password_recovery/widgets/new_password_step_form.dart';
import 'package:ganza/modules/auth_module/presentation/password_recovery/widgets/password_recovery_request_form.dart';
import 'package:ganza/modules/auth_module/presentation/sign_up/widgets/sign_up_confirmation_notice.dart';
import 'package:ganza/modules/auth_module/presentation/sign_up/widgets/sign_up_form.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:patrol/patrol.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _cena = String.fromEnvironment('E2E_CENA');
const _evidenceUrl = String.fromEnvironment('E2E_EVIDENCE_URL');
const _mailpitUrl = String.fromEnvironment('E2E_MAILPIT_URL');
const _endereco = String.fromEnvironment('E2E_ENDERECO');

/// Credencial descartável de uma conta que só existe na stack local desta
/// rodada. Não vem por `--dart-define` de propósito: assim não passa pela
/// linha de comando que os logs da rodada registram.
const _senhaInicial = 'exemplo-local-primeira';
const _senhaNova = 'exemplo-local-trocada';

/// Curta de propósito: o servidor exige seis caracteres e a tela não valida
/// tamanho localmente, então este valor é o que produz a recusa de senha fraca
/// sem depender de nenhuma outra condição.
const _senhaCurta = 'curta';

const _emailNaoConfirmado = 'Confirme seu e-mail antes de entrar.';
const _credencialIncorreta = 'E-mail ou senha incorretos.';
const _sessaoExpirada = 'Sua sessão expirou. Entre de novo.';

/// Texto fixo da **FD-026** (`docs/002_conta_e_configuracoes/decisions.md`):
/// código errado e código vencido chegam com o mesmo `otp_expired` e a tela
/// não os separa. Asserido por extenso porque o print sozinho registra a
/// mensagem sem cobrá-la — mudar o texto tem de quebrar a cena.
const _codigoRecusado =
    'Código inválido ou vencido. Confira e digite de novo, ou volte '
    'para pedir um novo código.';

/// Segundo modo de falha do fluxo de recuperação (**CHG-007**,
/// `docs/002_conta_e_configuracoes/changes.md`). Asserido por extenso pela
/// mesma razão do código recusado: o print registra, a asserção cobra.
const _avisoDeSenhaCurta = 'A senha precisa ter pelo menos 6 caracteres.';

const _hostsDaStackLocal = {'127.0.0.1', 'localhost', '0.0.0.0', '10.0.2.2'};

final _config = AppConfig.fromEnvironment();

void main() {
  patrolTest('cena $_cena', ($) async {
    final tester = $.tester;

    _recusarAlvoRemoto('SUPABASE_URL', _config.supabaseUrl);
    _recusarAlvoRemoto('E2E_MAILPIT_URL', _mailpitUrl);
    expect(
      _endereco,
      isNotEmpty,
      reason: 'faltou --dart-define E2E_ENDERECO com o endereço da execução',
    );

    await _subirApp(tester);

    switch (_cena) {
      case 'criar_conta':
        await _cenaCriarConta(tester);
      case 'entrar_sem_confirmar':
        await _cenaEntrarSemConfirmar(tester);
      case 'confirmar_e_entrar':
        await _cenaConfirmarEEntrar(tester);
      case 'recuperar_senha':
        await _cenaRecuperarSenha(tester);
      default:
        fail('cena desconhecida: "$_cena"');
    }
  });
}

/// Primeira coisa que o roteiro faz, antes de subir o Supabase e antes de tocar
/// em qualquer conta: ele cria conta de verdade, confirma e-mail de verdade e
/// troca senha de verdade. Só a stack descartável de `scripts/local-supabase.sh`
/// é alvo legítimo — HML e produção nunca.
void _recusarAlvoRemoto(String rotulo, String url) {
  final alvo = Uri.tryParse(url);
  final local =
      alvo != null &&
      alvo.scheme == 'http' &&
      _hostsDaStackLocal.contains(alvo.host);
  if (local) return;

  fail(
    'E2E recusado: $rotulo aponta para fora da stack local descartável '
    '("$url"). Este roteiro cria conta, confirma e-mail e troca senha de '
    'verdade — rodá-lo contra HML ou produção mexeria em conta real. '
    'Hosts aceitos, sobre http: ${_hostsDaStackLocal.join(', ')}.',
  );
}

Future<void> _subirApp(WidgetTester tester) async {
  await initializeDateFormatting('pt_BR');
  expect(_config.isComplete, isTrue, reason: 'faltou --dart-define-from-file');

  await Supabase.initialize(
    url: _config.supabaseUrl,
    publishableKey: _config.supabaseAnonKey,
  );

  // Toda cena começa na tela de entrar. O supabase_flutter restaura do disco a
  // sessão que a cena anterior deixou no aparelho, e sem isto a cena seguinte
  // nasceria dentro do app.
  final auth = Supabase.instance.client.auth;
  if (auth.currentSession != null) {
    await auth.signOut();
  }

  registerDependencies(_config);
  await tester.pumpWidget(const GanzaApp());
  await _aguardar(tester, _botaoEntrar);
}

Future<void> _cenaCriarConta(WidgetTester tester) async {
  await _tocar(tester, find.widgetWithText(TextButton, 'Criar conta'));
  await _aguardar(tester, find.byType(SignUpForm));

  final formulario = find.byType(SignUpForm);
  await _preencher(tester, _campoDe(formulario, 'E-mail'), _endereco);
  await _preencher(tester, _campoDe(formulario, 'Senha'), _senhaInicial);
  await _preencher(
    tester,
    _campoDe(formulario, 'Confirmar senha'),
    _senhaInicial,
  );

  await _tocar(tester, find.widgetWithText(FilledButton, 'Criar conta'));
  await _aguardar(tester, find.byType(SignUpConfirmationNotice));

  expect(find.text('Verifique seu e-mail'), findsOneWidget);
  expect(find.textContaining(_endereco), findsOneWidget);
  expect(
    find.byTooltip('Sair'),
    findsNothing,
    reason: 'cadastro não dá sessão',
  );
  await _capturar(tester, '10_conta_criada_confirme_email');

  final mensagem = await _mensagemCapturada(tester, tipo: 'signup');
  expect(
    _tokenDoLink(mensagem),
    isNotNull,
    reason: 'a mensagem de confirmação não trouxe o token do link',
  );
  expect(
    _codigoDeSeisDigitos(mensagem),
    isNotNull,
    reason: 'a mensagem de confirmação não trouxe o código',
  );
}

/// A confirmação de e-mail é obrigatória no servidor
/// (`GOTRUE_MAILER_AUTOCONFIRM` é `false`): a conta recém-criada existe e ainda
/// assim não entra. É o primeiro dos dois modos de falha da fase.
Future<void> _cenaEntrarSemConfirmar(WidgetTester tester) async {
  await _digitarCredencial(tester, _senhaInicial);
  await _tocar(tester, _botaoEntrar);

  await _aguardar(tester, _erroDaTelaDeEntrar(_emailNaoConfirmado));
  expect(find.byType(LoginForm), findsOneWidget);
  expect(find.byTooltip('Sair'), findsNothing);
  await _capturar(tester, '11_entrar_sem_confirmar');
}

Future<void> _cenaConfirmarEEntrar(WidgetTester tester) async {
  final mensagem = await _mensagemCapturada(tester, tipo: 'signup');
  await _confirmarPeloLinkDaMensagem(mensagem);

  await _entrar(tester, _senhaInicial);
  await _capturar(tester, '12_dentro_do_app_com_a_conta_nova');

  await _tocar(tester, find.byTooltip('Sair'));
  await _aguardar(tester, _botaoEntrar);

  // Depois de sair, o campo nasce com o último endereço usado. É por isso que
  // toda digitação neste roteiro limpa o campo antes: escrever por cima
  // produziria um endereço concatenado.
  expect(
    _textoDoCampo(tester, _campoDe(find.byType(LoginForm), 'E-mail')),
    _endereco,
  );
  await _capturar(tester, '13_email_lembrado_apos_sair');
}

Future<void> _cenaRecuperarSenha(WidgetTester tester) async {
  await _tocar(tester, find.widgetWithText(TextButton, 'Esqueci minha senha'));
  await _aguardar(tester, find.byType(PasswordRecoveryRequestForm));

  await _preencher(
    tester,
    _campoDe(find.byType(PasswordRecoveryRequestForm), 'E-mail'),
    _endereco,
  );
  await _tocar(tester, find.widgetWithText(FilledButton, 'Enviar código'));
  await _aguardar(tester, find.byType(CodeStepForm));

  final mensagem = await _mensagemCapturada(tester, tipo: 'recovery');
  final codigo = _codigoDeSeisDigitos(mensagem);
  expect(
    codigo,
    isNotNull,
    reason: 'a mensagem de recuperação não trouxe o código',
  );

  final errado = _codigoTrocado(codigo!);
  expect(errado, isNot(codigo));

  await _preencher(tester, _campoDoCodigo, errado);
  await _tocar(tester, find.widgetWithText(FilledButton, 'Confirmar'));
  await _aguardar(tester, _erroDaEtapaDoCodigo);

  expect(find.byType(CodeStepForm), findsOneWidget);
  expect(find.byType(NewPasswordStepForm), findsNothing);
  expect(_textoDoCampo(tester, _campoDoCodigo), errado);
  expect(_textoDoErro(tester, _erroDaEtapaDoCodigo), _codigoRecusado);
  expect(_textoDoErro(tester, _erroDaEtapaDoCodigo), isNot(_sessaoExpirada));
  await _capturar(tester, '14_codigo_errado_recusado');

  await _preencher(tester, _campoDoCodigo, codigo);
  await _tocar(tester, find.widgetWithText(FilledButton, 'Confirmar'));
  await _aguardar(tester, find.byType(NewPasswordStepForm));
  await _capturar(tester, '15_nova_senha_apos_codigo_certo');

  final etapaDaSenha = find.byType(NewPasswordStepForm);
  final campoDaSenhaNova = _campoDe(etapaDaSenha, 'Nova senha');
  final campoDaConfirmacao = _campoDe(etapaDaSenha, 'Confirme a nova senha');

  await _preencher(tester, campoDaSenhaNova, _senhaCurta);
  await _preencher(tester, campoDaConfirmacao, _senhaCurta);
  await _tocar(tester, find.widgetWithText(FilledButton, 'Salvar nova senha'));
  await _aguardar(tester, _erroDaEtapaDaSenha);

  expect(find.byType(NewPasswordStepForm), findsOneWidget);
  expect(_textoDoCampo(tester, campoDaSenhaNova), _senhaCurta);
  expect(_textoDoCampo(tester, campoDaConfirmacao), _senhaCurta);
  expect(_textoDoErro(tester, _erroDaEtapaDaSenha), _avisoDeSenhaCurta);
  expect(_textoDoErro(tester, _erroDaEtapaDaSenha), isNot(_sessaoExpirada));
  await _capturar(tester, '16_senha_nova_fraca_recusada');

  await _preencher(tester, campoDaSenhaNova, _senhaNova);
  await _preencher(tester, campoDaConfirmacao, _senhaNova);
  await _tocar(tester, find.widgetWithText(FilledButton, 'Salvar nova senha'));
  await _aguardarEntradaNoApp(tester);
  await _capturar(tester, '17_dentro_do_app_apos_trocar_a_senha');

  await _tocar(tester, find.byTooltip('Sair'));
  await _aguardar(tester, _botaoEntrar);

  await _digitarCredencial(tester, _senhaInicial);
  await _tocar(tester, _botaoEntrar);
  await _aguardar(tester, _erroDaTelaDeEntrar(_credencialIncorreta));
  expect(find.byTooltip('Sair'), findsNothing);
  await _capturar(tester, '18_senha_antiga_recusada');

  await _entrar(tester, _senhaNova);
  await _capturar(tester, '19_entrar_com_a_senha_nova');
}

/// O caminho que a pessoa percorre ao abrir a caixa de entrada e clicar no
/// link. O endereço impresso na mensagem é o do container
/// (`127.0.0.1:54321/verify`), que do emulador seria o próprio aparelho e nem
/// passa pelo Kong: o token é o que chegou na mensagem, e só a base troca para
/// a que o app já usa. Nada aqui é chamada administrativa — é a rota pública
/// que consome o token do e-mail.
Future<void> _confirmarPeloLinkDaMensagem(String mensagem) async {
  final token = _tokenDoLink(mensagem);
  expect(
    token,
    isNotNull,
    reason: 'a mensagem capturada não trouxe o token do link',
  );

  final destino = Uri.parse(
    '${_config.supabaseUrl}/auth/v1/verify',
  ).replace(queryParameters: {'token': token!, 'type': 'signup'});

  final client = HttpClient();
  try {
    final request = await client.getUrl(destino);
    request.followRedirects = false;
    final response = await request.close();
    await response.drain<void>();
    expect(
      response.statusCode,
      303,
      reason: 'o GoTrue não aceitou o token da mensagem capturada',
    );

    final retorno = Uri.parse(response.headers.value('location') ?? '');
    final parametros = Uri.splitQueryString(retorno.fragment);
    expect(
      parametros['error_code'] ?? parametros['error'],
      isNull,
      reason: 'o GoTrue recusou o token da mensagem capturada',
    );
  } finally {
    client.close(force: true);
  }

  debugPrint('CONFIRMACAO cena=$_cena via=link-da-mensagem-capturada');
}

/// Espera a mensagem chegar ao capturador local e devolve o corpo em texto. A
/// seleção é pelo `type=` do link e não pelo assunto: o assunto vem do template
/// em inglês do GoTrue e muda entre versões.
Future<String> _mensagemCapturada(
  WidgetTester tester, {
  required String tipo,
}) async {
  final prazo = DateTime.now().add(const Duration(seconds: 120));
  while (DateTime.now().isBefore(prazo)) {
    final caixa = await _json(
      Uri.parse('$_mailpitUrl/api/v1/messages?limit=50'),
    );
    for (final bruto in (caixa['messages'] as List<dynamic>?) ?? const []) {
      final resumo = bruto as Map<String, dynamic>;
      final destinatarios = (resumo['To'] as List<dynamic>).map(
        (contato) => (contato as Map<String, dynamic>)['Address'] as String,
      );
      if (!destinatarios.contains(_endereco)) continue;

      final completa = await _json(
        Uri.parse('$_mailpitUrl/api/v1/message/${resumo['ID']}'),
      );
      final texto = (completa['Text'] as String?) ?? '';
      if (texto.contains('type=$tipo')) return texto;
    }
    await tester.pump(const Duration(seconds: 2));
  }

  fail('nenhuma mensagem "$tipo" chegou ao capturador para $_endereco em 120s');
}

Future<Map<String, dynamic>> _json(Uri destino) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(destino);
    final response = await request.close();
    final corpo = await response.transform(utf8.decoder).join();
    expect(
      response.statusCode,
      200,
      reason:
          'o capturador respondeu ${response.statusCode} em ${destino.path}',
    );
    return jsonDecode(corpo) as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}

final _padraoToken = RegExp(r'[?&]token=([A-Za-z0-9_-]+)');
final _padraoLink = RegExp(r'https?://\S+');
final _padraoCodigo = RegExp(r'(?<![0-9])[0-9]{6}(?![0-9])');

String? _tokenDoLink(String mensagem) =>
    _padraoToken.firstMatch(mensagem)?.group(1);

/// Os links saem antes da busca: o token do e-mail é hexadecimal e um trecho
/// dele passaria por código de seis dígitos.
String? _codigoDeSeisDigitos(String mensagem) =>
    _padraoCodigo.firstMatch(mensagem.replaceAll(_padraoLink, ' '))?.group(0);

/// Errado por construção, sem literal no roteiro: cada dígito anda uma casa,
/// então nenhum dos seis coincide com o que chegou na mensagem.
String _codigoTrocado(String codigo) => codigo
    .split('')
    .map((digito) => ((int.parse(digito) + 1) % 10).toString())
    .join();

Future<void> _entrar(WidgetTester tester, String senha) async {
  await _digitarCredencial(tester, senha);
  await _tocar(tester, _botaoEntrar);
  await _aguardarEntradaNoApp(tester);
}

Future<void> _digitarCredencial(WidgetTester tester, String senha) async {
  final formulario = find.byType(LoginForm);
  await _preencher(tester, _campoDe(formulario, 'E-mail'), _endereco);
  await _preencher(tester, _campoDe(formulario, 'Senha'), senha);
}

Future<void> _aguardarEntradaNoApp(WidgetTester tester) async {
  await _aguardar(tester, find.byTooltip('Sair'));
  await _aguardarSumir(tester, find.byType(CircularProgressIndicator));
  await tester.pump(const Duration(milliseconds: 400));
}

/// O campo de e-mail da tela de entrar nasce com o último endereço usado
/// (`LastSignedInEmail`): sem limpar antes, a digitação concatenaria os dois e
/// o endereço enviado ao servidor não seria o desta execução.
Future<void> _preencher(WidgetTester tester, Finder campo, String texto) async {
  await _limpar(tester, campo);
  await tester.enterText(campo, texto);
  await tester.pump();
  expect(_textoDoCampo(tester, campo), texto);
}

Future<void> _limpar(WidgetTester tester, Finder campo) async {
  tester.widget<TextField>(campo).controller?.clear();
  await tester.pump();
  expect(_textoDoCampo(tester, campo), isEmpty);
}

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pump();
  await tester.tap(alvo);
  await tester.pump();
}

Finder _campoDe(Finder escopo, String rotulo) => find.descendant(
  of: escopo,
  matching: find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == rotulo,
  ),
);

Finder get _campoDoCodigo =>
    _campoDe(find.byType(CodeStepForm), 'Código de verificação');

Finder get _botaoEntrar => find.widgetWithText(FilledButton, 'Entrar');

Finder _erroDaTelaDeEntrar(String mensagem) => find.descendant(
  of: find.byType(LoginErrorBanner),
  matching: find.text(mensagem),
);

/// O `FailureBanner` fica sempre montado e vira `SizedBox.shrink()` sem
/// mensagem — o que prova que o erro apareceu é existir texto dentro dele.
Finder _erroDaEtapa(Finder etapa) => find.descendant(
  of: find.descendant(of: etapa, matching: find.byType(FailureBanner)),
  matching: find.byType(Text),
);

Finder get _erroDaEtapaDoCodigo => _erroDaEtapa(find.byType(CodeStepForm));

Finder get _erroDaEtapaDaSenha =>
    _erroDaEtapa(find.byType(NewPasswordStepForm));

String? _textoDoErro(WidgetTester tester, Finder erro) =>
    tester.widget<Text>(erro).data;

String? _textoDoCampo(WidgetTester tester, Finder campo) =>
    tester.widget<TextField>(campo).controller?.text;

Future<void> _capturar(WidgetTester tester, String nome) async {
  expect(_evidenceUrl, isNotEmpty, reason: 'faltou E2E_EVIDENCE_URL');
  await tester.pump(const Duration(milliseconds: 300));

  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('$_evidenceUrl/$nome'));
    final response = await request.close();
    await response.drain<void>();
    expect(response.statusCode, 204, reason: 'falhou a captura $nome');
  } finally {
    client.close(force: true);
  }

  debugPrint(
    'EVIDENCIA cena=$_cena print=$nome.png em=${DateTime.now().toIso8601String()}',
  );
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
