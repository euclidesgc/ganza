# 002 - Conta, configurações e chaves do usuário · Specs

Segundo item do roadmap por feature. Fonte do "o quê": [`01_prd.md`](01_prd.md) e `docs/plano.md` §6.11, §8 (F22, F23), §11.4. O fatiamento em fases, as tarefas e os DoD ficam em `03_plan.md`.

As decisões específicas estão em [`decisions.md`](decisions.md). O histórico
append-only de desvios e as reconciliações está em [`changes.md`](changes.md);
estas specs descrevem somente o estado final.

## 1. O que esta feature entrega

Quatro coisas que hoje não existem em nenhuma linha de código: **auth completo** (cadastro e recuperação de senha), **navegação com menu lateral e uma casca de Configurações**, **credencial de IA trazida pelo usuário** e **conexão bancária por usuário** — mais o **gating** que liga as duas últimas às telas que dependem delas.

```
App → GoTrue                     cadastro, recuperação por código, troca de senha
App → PostgREST + RLS            perfil, catálogo de provedores, estado da credencial e da conexão
App → Edge Function → Vault      gravar/testar/apagar a chave do usuário (a chave nunca volta)
App → Edge Function → provedor   conectar e desconectar banco (a credencial do projeto nunca sai do servidor)
```

A regra de corte entre os dois últimos trilhos é a do `CLAUDE.md`: leitura de dado do usuário vai direto pelo `supabase_flutter` sob RLS; escrita que exige segredo ou lógica passa pela Edge Function.

## 2. Estado atual do código — as âncoras

Levantado no repositório, não presumido. É contra isto que o plano fatia.

| Âncora | Estado hoje | Consequência |
|---|---|---|
| `app/lib/modules/auth_module/domain/repositories/auth_repository.dart` | contrato com **quatro** membros: `observeCurrentUser`, `currentUser`, `signIn`, `signOut` | cadastro, recuperação e troca de senha são membros novos, não adaptação |
| `app/lib/modules/auth_module/auth_module.dart` | exporta rota, DI e o contrato de sessão — `AuthenticatedUser`, `ObserveCurrentUser`, `GetCurrentUser` e `SignOut` (o `CLAUDE.md` fala em "três símbolos" e o arquivo exporta quatro; a exceção é a mesma) | tela nova que precise de use case do auth mora **dentro** do auth; a exceção não se amplia |
| `app/lib/app_router.dart` | router **plano**, sem `ShellRoute`; guarda binária `getIt<GetCurrentUser>()() != null`; `refreshListenable` é um único `ChangeNotifier` sobre o stream de sessão | menu lateral exige shell; recuperação de senha exige um **terceiro** estado na guarda; gating exige `Listenable.merge` |
| `app/lib/bootstrap.dart` | `Supabase.initialize` sem `authOptions` | valem os defaults `persistSession = true` e `autoRefreshToken = true`; access e refresh token ficam em `SharedPreferences` |
| `infra/local/docker-compose.yml`, `docs/deploy/coolify.md` | sem `GOTRUE_SESSIONS_TIMEBOX` e sem `GOTRUE_SESSIONS_INACTIVITY_TIMEOUT`. A stack local já roda `GOTRUE_MAILER_AUTOCONFIRM: 'false'` com capturador de e-mail (T1.5); na HML, `SMTP_HOST`/`SMTP_USER`/`SMTP_PASS` ainda vazios, e a virada entra no redeploy do SMTP | pelo código **a sessão não deveria cair** — e a T1.1 mediu que não cai; a recuperação se prova inteira na stack local, sem esperar a HML |
| `app/lib/core/` | tem `config`, `error`, `format`, `network`, `observability`, `theme`, `widgets` — **não tem `session/`** | escopo de recuperação e capacidades do usuário são pasta nova |
| `app/lib/core/widgets/widgets.dart` | exporta só `brand/brand.dart` e `pulse/pulse.dart` | menu lateral e campo de segredo entram como tiers novos, com barrel próprio |
| `app/lib/core/theme/app_theme.dart` | sem `DrawerThemeData`, `ListTileThemeData`, `SwitchThemeData` | sem tematizar, o menu vem com elevação e *surface tint* do M3, contra "material humilde" |
| `app/lib/core/theme/app_icons.dart` | cinco glifos Remix vendorizados (decisão **D22**) | a navegação e as configurações precisam de mais de dez tokens novos |
| `app/lib/modules/` | `areas_module`, `auth_module`, `transactions_module` | `settings_module` é módulo novo, pelo gabarito da skill `criar-modulo` |
| `app/patrol_test/` | `lista_transacoes_test.dart` e `registro_transacao_test.dart` navegam por `find.byTooltip('Ver transações')` | ao mover a ação da `AppBar` para o menu, os dois quebram — e nem `flutter test` nem `flutter analyze` cobrem `patrol_test/` |
| `supabase/migrations/` | `0001`…`0005`; `public.profiles` tem `id`, `timezone`, `locale`, `settings jsonb`, carimbos, RLS de dono | nome de exibição é coluna nova; o cofre já está habilitado desde a `0001` |
| `supabase/functions/` | `main`, `health`, `transactions` | `ai-credentials` e `bank-connections` são funções novas |
| `supabase/functions/main/index.ts` | monta o mesmo `envVars` para qualquer função despachada, incluindo `SUPABASE_SERVICE_ROLE_KEY` (decisão **D19**) | a primeira função que legitimamente precisa da chave de serviço chega nesta feature; o escopo por função deixa de ser opcional |
| `supabase/functions/transactions/handler.ts` | valida com predicados escritos à mão e monta a linha por **allowlist de campo** | é a forma a copiar; nenhuma dependência nova de validação entra em `supabase/functions/deno.json` |
| pipeline de IA | **não existe nada**: nem `messages`, nem `proposed_actions`, nem `ai_providers`/`ai_routes`/`ai_usage`, nem `ingest` | a defesa não endurece um pipeline existente — ela define a forma em que ele nasce |

## 3. Contratos

### 3.1 Auth — ampliação do contrato existente

`AuthRepository` ganha, além dos quatro membros atuais, todos devolvendo `Future<Either<Failure, …>>`:

| Membro | Para quê |
|---|---|
| `signUp` | criar conta |
| `resetPasswordForEmail` | pedir o código de recuperação |
| `verifyRecoveryCode` | conferir o código de seis dígitos |
| `updatePassword` | definir a senha **no fluxo de recuperação**, onde não há senha atual para pedir |
| `changePassword` | trocar a senha **logado**, confirmando a atual antes |

Os dois últimos coexistem de propósito: são fluxos diferentes com exigências diferentes. Um arquivo de use case por operação, cada um com um único método público `call()`.

**Os cinco membros não chegam na mesma fase, e isso é deliberado.** Os quatro primeiros são da **Fase 1** (tarefas T1.3, domain, e T1.6, data), porque é ela que entrega cadastro e recuperação; `changePassword` é da **Fase 3** (T3.3, T3.5, T3.7 e T3.8), porque só ali existe a tela de conta que o usa. Contrato ampliado em duas etapas, não em uma — quem ler só esta tabela conclui errado que a Fase 1 devia declarar os cinco.

A tradução de erro é feita pelo **código** do erro do GoTrue, nunca por busca de substring na mensagem em inglês — mensagem de provedor muda sem aviso e a busca por texto falha em silêncio. Cobertura mínima, com texto próprio em pt-BR e distinto entre si: `invalid_credentials`, `email_not_confirmed`, `user_already_exists`, `weak_password`, `over_email_send_rate_limit`, `signup_disabled`. Nenhum deles pode cair na mensagem de sessão expirada.

**`user_already_exists` é caso morto na configuração atual, e fica no código assim mesmo.** Medido em 20/08/2026: com a confirmação de e-mail exigida, repetir o cadastro do mesmo endereço devolve `200` sem `error_code` (ver §7.1) — o código nunca chega ao app. Ele permanece traduzido porque a configuração que o dispara existe, e apagá-lo é regressão silenciosa esperando a próxima virada de ambiente. **O que ele não pode ser é promessa de tela:** nenhuma interface desta feature exibe mensagem específica de "e-mail já cadastrado" (**FD-024**).

### 3.2 Perfil, credencial de IA e conexão bancária

Três contratos novos em `app/lib/modules/settings_module/domain/repositories/`, todos `abstract interface class` devolvendo `Future<Either<Failure, …>>`:

| Contrato | Operações |
|---|---|
| `ProfileRepository` | ler o perfil, atualizar o nome de exibição |
| `AiCredentialRepository` | ler o catálogo de provedores, ler a credencial do usuário, gravar a chave, remover |
| `BankConnectionRepository` | ler a conexão, iniciar a conexão, desconectar |

**A entidade que a tela exibe não pode nem representar o segredo.** `AiCredential` carrega provedor, modelo, quatro últimos dígitos e se está ativa — e **não tem campo para a chave**. A chave existe apenas como parâmetro de entrada do método que a envia.

O status da conexão bancária é `enum` fechado em arquivo próprio (`pendente`, `conectado`, `erro`, `desconectado`), espelhando a restrição do banco. Status desconhecido vindo do servidor vira `Failure`, nunca um valor padrão silencioso: padrão silencioso é como um estado novo do provedor chega à tela disfarçado de estado antigo.

### 3.3 Capacidades do usuário

`app/lib/core/session/` (pasta nova) abriga dois conceitos independentes do módulo de auth e do de configurações:

- **escopo de recuperação de senha** — booleano em memória, Dart puro, sem conhecer rota nem Supabase. É o que permite à guarda do router distinguir "tem sessão" de "tem sessão **porque acabou de validar um código de recuperação**".
- **capacidades** — valor imutável com dois booleanos (IA configurada, banco conectado), um contrato de fonte, e o cubit que router e menu compartilham. O cubit é `registerLazySingleton`, exceção deliberada ao padrão do repositório: com duas instâncias, o gate e o menu discordam.

**O cubit falha fechado.** Fonte que devolva `Left` resulta em capacidade `false`, nunca `true`. Erro de leitura abrindo o chat é a falha que ninguém vê acontecer.

## 4. Edge Functions

### 4.1 `ai-credentials` — o desenho de dois passos

A extensão `supabase_vault` já está habilitada em `supabase/migrations/0001_habilitar_extensoes.sql`. `anon` e `authenticated` não têm `USAGE` no schema `vault`, e `vault` não está em `PGRST_DB_SCHEMAS` — o PostgREST nem o expõe. Mas **o cofre é um key-value cifrado global ao projeto, sem noção de dono**: quem sabe um uuid de segredo e tem a chave de serviço decifra qualquer um.

Por isso o isolamento entre usuários **não vem do cofre**. Ele vem da ordem:

1. resolver o `secret_ref` **com o JWT do usuário**, deixando a RLS filtrar;
2. **só então** abrir cliente de serviço para decifrar **aquele uuid**, que já veio filtrado.

A vulnerabilidade real é pular o passo 1 e montar a consulta de serviço a partir de um identificador vindo do corpo da requisição. Inverter a ordem dos dois passos tem de **quebrar um teste**, não passar despercebido.

A ponte para o cofre é uma função `security definer` no schema `public`, com `execute` só para `service_role` e `search_path` fixado: `service_role` tem `SELECT`/`DELETE` em `vault.secrets` e `EXECUTE` nas funções do cofre, mas **não** tem `INSERT` nem `UPDATE` diretos. A alternativa — a função abrir conexão direta pelo `SUPABASE_DB_URL`, como faz `supabase/functions/health/handler.ts` — foi recusada: essa conexão entra como `postgres`, exatamente o cenário que a pendência **P8** de `docs/decisions.md` manda evitar.

Nem a chave em claro nem o `secret_ref` aparecem em resposta ou em log. O corpo de sucesso traz provedor, modelo e os quatro últimos caracteres.

### 4.2 `bank-connections` — aqui não há chave do usuário

O provedor bancário autentica o **projeto** com um par de credenciais, não cada pessoa com a sua. É segredo do ganzá: vive em env do Coolify e da função, nunca em tabela, nunca no cofre por usuário, nunca no app. **Toda a maquinaria de cofre, ponte `security definer` e gatilho de limpeza da credencial de IA não se aplica aqui** — quem a reaproveitar está guardando um segredo global num lugar por usuário.

O que é por usuário é a **referência** que o provedor devolve, guardada em `public.bank_connections` sob RLS de dono. Escrita com o cliente criado a partir do `Authorization` da requisição, nunca com a chave de serviço.

**Sem webhook nesta feature.** O status é lido sob demanda, sempre com o JWT do usuário na frente. Webhook seria a primeira escrita **sem usuário na frente**, que é exatamente o gatilho nomeado pela **P8** para criar um role dedicado no Postgres. Adiar um adia o outro, de propósito.

Configuração ausente responde `503` com mensagem de configuração, nunca `500` nem exceção crua.

### 4.3 Escopo de ambiente por função

`supabase/functions/main/index.ts` passa a montar `envVars` **por função**, a partir de um módulo puro e testável. `SUPABASE_SERVICE_ROLE_KEY` chega a `ai-credentials` e não chega a `transactions` nem a `health`. É a resolução da decisão **D19**, e ela deixa de ser adiável nesta feature porque é aqui que nasce a primeira função que legitimamente precisa da chave.

## 5. Modelo de dados

Os números das migrations são fixados em `03_plan.md` — os fragmentos de planejamento reivindicaram `0006`/`0007` em duas frentes diferentes, e quem consolidar renumera **uma vez**, ajustando junto os caminhos literais dos blocos DoD. Aqui ficam as tabelas e o que cada decisão custa.

### 5.1 `public.profiles` — o nome vai em coluna, não em `settings`

`profiles` já tem `settings jsonb not null default '{}'`. A régua:

| Vai em coluna própria | Vai em `settings jsonb` |
|---|---|
| atributo escalar lido a cada abertura do app, com restrição de tipo ou de tamanho, ou que precise de índice/consulta | preferência opcional, sem restrição, lida com o perfil inteiro e nunca consultada isoladamente |

`display_name` é lido no cabeçalho do menu a cada abertura: vira `text` nulável. `settings` continua reservado para preferências que ainda não existem — e nenhuma delas nasce nesta feature.

O `user_metadata` do GoTrue **não serve como fonte**: a pessoa o escreve sem validação e o PostgREST não o alcança em consulta. Ele serve como *carona* — o gatilho `public.handle_new_user()` (hoje em `supabase/migrations/0003_criar_perfil_e_areas_padrao_no_signup.sql`, inserindo só `profiles (id)`) é substituído para copiar o nome do metadado do cadastro **quando a chave existir**. Sem a chave, a coluna nasce nula e a pessoa a preenche na tela de Conta.

### 5.2 `public.ai_provider_kinds` — catálogo global

Que provedores a pessoa pode trazer chave para. É catálogo, não dado de usuário: sem `user_id`, semeado pela própria migration.

**A política que satisfaz o gate de RLS do CI para tabela de catálogo global** é uma só:

```sql
create policy ai_provider_kinds_readable on public.ai_provider_kinds
  for select to authenticated using (true);
```

Ela passa nos três gates do job "Banco" de `.github/workflows/ci.yml`: a tabela tem RLS ligada; tem política (RLS ligada sem política nenhuma bloqueia tudo em silêncio, e é o segundo gate); e `using (true)` não chama nenhuma função do schema `auth`, então o gate de *initialization plan* nem se aplica. **Nenhuma política de escrita** — com RLS ligada e sem política de `insert`/`update`/`delete`, o Postgres nega por padrão, e é assim que um catálogo fica somente leitura sem uma linha a mais.

### 5.3 `public.ai_user_credentials` — dado do usuário

Uma linha por par (usuário, provedor): `unique (user_id, provider_kind_id)`. Guarda o modelo escolhido, se está ativa, os **quatro últimos caracteres** da chave e o `secret_ref` — o uuid do segredo no cofre. **A chave em claro não fica em nenhuma coluna legível.**

RLS de dono no padrão de `supabase/migrations/0005_otimizar_politicas_rls.sql`: `user_id = (select auth.uid())` no `using` **e** no `with check`, com a chamada dentro de um `select` (decisão **D17**).

Um gatilho `before delete` apaga o segredo correspondente em `vault.secrets`. Não é regra de negócio em plpgsql: é integridade referencial que **nenhuma FK consegue expressar**, porque `vault.secrets` não aceita chave estrangeira para `auth.users` — sem o gatilho, o `on delete cascade` da conta apaga a credencial e deixa um segredo cifrado e eterno. Resolver por construção vale mais que um procedimento que alguém precisa lembrar de rodar.

### 5.4 `public.bank_connections` — dado do usuário

Identificador da conexão no provedor (único no banco), instituição, status em conjunto fechado (`pending`, `connected`, `error`, `disconnected`), instante da última sincronização e carimbos. RLS de dono no mesmo padrão. Apagar a conta apaga a conexão.

### 5.5 O que a defesa da camada de IA acrescenta

Tabelas que nascem já com a forma defensiva, em vez de nascerem permissivas e serem endurecidas depois:

| Tabela | O que fixa |
|---|---|
| `public.messages` | `origin` em lista fechada (`user_typed`, `bank_sync`, `ocr`, `transcript`, `email`, `calendar`) — a **procedência** que o card vai precisar mostrar; teto de tamanho do conteúdo |
| `public.proposed_actions` | `kind` em lista fechada **só** de `create_*`/`attach_*` — nenhum verbo de alteração, porque a intenção `update` não existe neste produto (`docs/plano.md` §6.2); teto de propostas por mensagem; `check` proibindo a chave `user_id` dentro do `payload` |
| `public.ai_providers` / `public.ai_routes` | roteamento de `task_type` (`docs/plano.md` §6.11): `secret_ref` guarda **nome de segredo do cofre**, com `check` de formato que recusa algo parecido com uma chave; `fallback_provider_id` obrigatório e diferente do provedor |
| `public.ai_usage` | custo e latência, **sem nenhuma coluna de conteúdo**; `cost_micros` inteiro; `content_sha256` para correlacionar reincidência sem guardar o texto; `message_id` **sem** FK, porque apagar a mensagem não pode apagar o registro contábil |

`public.ai_provider_kinds` e `public.ai_providers`/`ai_routes` **são coisas diferentes** e o nome parecido convida à fusão errada: o primeiro é catálogo de *origem de chave do usuário*; os outros dois são roteamento de tarefa. Coexistem e nenhum referencia o outro nesta feature. Registrado em [`decisions.md`](decisions.md) antes da migration, de propósito.

`supabase/ci-bootstrap.sql` precisa ganhar o stand-in de `auth.role()`: ele tem o de `auth.uid()` e não o de `auth.role()`, e a decisão **D12** já anotou que a primeira migration com política sobre `auth.role()` amplia o bootstrap junto. As políticas de `ai_providers`/`ai_routes` são essa primeira migration.

`category_hints` **não ganha tabela aqui** — `categories` não existe. O que se fixa agora é a **normalização determinística** que gera a chave (charset `[a-z0-9 ]`, teto de 64 caracteres) e a regra de quem pode escrevê-la.

## 6. Navegação e gating

### 6.1 A casca

Não existe navegação nenhuma para reaproveitar: nem menu lateral, nem barra inferior, nem *rail*. As únicas saídas da tela inicial são dois `IconButton` na `AppBar` da `AreasPage` e o botão flutuante da lista de transações.

A casca é um `ShellRoute` restrito aos **destinos de topo**, com o menu no `Scaffold` do shell. `/transacoes/nova` e os destinos sob `/configuracoes/` ficam empilhados **fora** dele, para a `AppBar` de cada um manter o botão de voltar.

**Armadilha que o guard não pega:** `Scaffold` com `drawer:` injeta um `DrawerButton` com glifo do Material, e `scripts/gates_guard.sh` **não tem checagem de ícone nenhuma** — medido em 20/08/2026, o Gate 4 dele cobre `Color(0x`, `Colors.<nome>`, `fontSize`, `circular(` e `EdgeInsets`, e nada de ícone. Cada página de topo declara `leading:` com token de `app/lib/core/theme/app_icons.dart`. É gate, não recomendação: a prova é `rtk proxy grep -rnE '(^|[^A-Za-z])Icons\.' app/lib` vazio — **com a âncora**, porque sem ela o padrão casa `Icons.` dentro de `AppIcons.` e acusa as 13 linhas legítimas que o repositório já tem. A checagem entra no guard pela tarefa **T2.9** do [`03_plan.md`](03_plan.md).

Rotas novas: `/configuracoes`, `/configuracoes/conta`, `/configuracoes/ia`, `/configuracoes/banco` no `settings_module`, e `/configuracoes/conta/senha` **dentro do `auth_module`** — a tela de troca de senha precisa de use case interno do auth, e ampliar a exceção documentada do barrel para caber mais um símbolo custaria mais que declarar a rota do lado certo. O `settings_module` navega pelo **nome** da rota, que já é público. Todas com constante de `path` e de `name`, nenhuma com `extra:`.

### 6.2 Os três pontos de aplicação do gate, e só três

| Ponto | Papel |
|---|---|
| `redirect` do `createRouter()` em `app/lib/app_router.dart` | o gate **duro** — é ele que torna deep link e menu antigo seguros |
| `refreshListenable`, que passa a ser `Listenable.merge` entre o notificador de sessão e o cubit de capacidades | sem ele o `redirect` não reavalia quando a IA acaba de ser configurada, e a pessoa fica presa na tela que preencheu |
| `BlocSelector` no item do menu | mostra apagado com o motivo — apresentação, não autorização |

**Anti-padrão proibido por escrito: `if (aiConfigured)` no corpo de página.** Tela alcançável é tela funcional; quem barra é o router. A prova é por grep: as únicas árvores que mencionam a capacidade são `app/lib/core/session/`, `app/lib/core/widgets/navigation/` e `app/lib/app_router.dart`.

O destino protegido hoje é o item de chat do menu, que existe apagado desde a casca. Item desabilitado anuncia o motivo por `Semantics`, senão o leitor de tela lê um item morto.

### 6.3 O terceiro estado da guarda

A guarda atual é binária e manda todo mundo com sessão para a raiz. Tanto o `AuthChangeEvent.passwordRecovery` do GoTrue quanto a verificação do código de recuperação **entregam uma sessão válida** — sem um terceiro estado, a pessoa digita o código certo, é logada e **nunca vê o campo de nova senha**. O escopo em memória de `app/lib/core/session/` resolve isso sem nenhuma dependência do contrato de auth, que é o que permite construí-lo em paralelo.

## 7. Cadastro, confirmação de e-mail e recuperação de senha

### 7.1 Cadastro e confirmação de e-mail

**O cadastro não termina dentro do app — termina na caixa de entrada.** Com a confirmação de e-mail exigida (**FD-022**), `signUp` devolve a conta criada **sem sessão** e com `email_confirmed_at` nulo. O app não tem para onde navegar: não há sessão, e a guarda de rota manda para a tela de entrar. **Duas réguas governam essa tela**, e as duas são de produto, não de implementação:

1. **Nunca afirmar que a conta está pronta para usar.** O desfecho de sucesso do cadastro é uma mensagem que diz o que falta — confirmar o endereço — e onde procurar. Sem ela, a pessoa toca "criar conta", vê a tela não mudar e conclui que falhou.
2. **Nunca revelar se o endereço já tinha conta.** O texto de sucesso é **o mesmo** para endereço novo e para endereço repetido.

A segunda régua nasceu de medição, não de gosto. **Medido contra o GoTrue da stack local em 20/08/2026:** repetir o cadastro do mesmo endereço, fora da janela de reenvio, devolve `HTTP 200` com `identities` preenchido e **sem** `error_code` — resposta **idêntica** à do cadastro novo. O app não consegue distinguir os dois casos pelo caminho do erro, e a única forma de conseguir seria consultar a existência do e-mail antes de cadastrar, o que é erguer de propósito um **oráculo de enumeração de contas** num app que guarda extrato bancário. A mensagem única é escolha (**FD-024**).

**A confirmação acontece fora do app, e isso é desenho, não omissão.** Não existe tela de código de confirmação — o que chega na mensagem é aberto pela pessoa, no cliente de e-mail dela, e quem verifica é o próprio GoTrue. O app tem duas responsabilidades e só duas: dizer que a confirmação falta, e aceitar a entrada depois que ela ocorrer. É por isso que a decisão **D25** (código digitado em vez de deep link) **não se aplica aqui**: ela existe para trazer a sessão de volta ao app na recuperação de senha; na confirmação não há sessão para trazer — a pessoa confirma e **entra normalmente**, pela tela de entrar. Espelhar a tela de OTP aqui seria escopo novo sem problema para resolver.

**Consequência para o E2E:** o roteiro faz o que o navegador da pessoa faria — extrai da mensagem capturada o que ela traz e completa a verificação por ali —, e **nunca** avança marcando a conta como confirmada no banco. Confirmar por SQL prova que o banco aceita `update`, não que alguém consegue usar o app. Detalhe que engana quem for depurar: `GOTRUE_SITE_URL` vale `http://127.0.0.1:3000` na stack local, endereço onde não há nada servindo — o redirecionamento **depois** da verificação falha, e isso é irrelevante, porque a conta já foi confirmada quando o GoTrue processou o pedido. Não é bug a consertar.

**A janela de reenvio é curta e visível.** Duas tentativas seguidas do mesmo endereço batem em `over_email_send_rate_limit`, com janela de cerca de 60 segundos. Isso não é erro de duplicidade e não pode ser exibido como falha do cadastro: o texto diz que o pedido foi recente e que basta esperar. Vale para quem toca o botão duas vezes e vale para o roteiro de E2E, que **não repete cadastro em sequência**.

### 7.2 Recuperação de senha

**Por código de seis dígitos digitado, não por deep link.** O caminho OTP (`verifyOTP` com `OtpType.recovery`) custa **uma tela a mais** e **zero** configuração de plataforma. O deep link PKCE custa `intent-filter` `VIEW`/`BROWSABLE` no `AndroidManifest.xml` **por flavor** — e hoje só existem os source sets `main/`, `debug/` e `profile/`, com `applicationIdSuffix = ".dev"` fazendo o esquema diferir entre dev e prod —, mais `GOTRUE_URI_ALLOW_LIST` e `GOTRUE_SITE_URL` no servidor, que valem `http://127.0.0.1:3000` nos dois ambientes. Nenhuma dessas peças é testável no CI, e todas quebram calado.

**O código recusado é o desfecho mais provável desta tela, e tem texto fixo.** O GoTrue devolve `otp_expired` tanto para código inexistente quanto para código vencido — o mesmo código para os dois —, e a tela **não tenta separá-los**: distinguir diria a quem chuta se um código já foi válido, o que é oráculo de força bruta sobre seis dígitos (**FD-026**, mesmo princípio da **FD-025**). A mensagem cobre os dois casos e nomeia as duas saídas: **"Código inválido ou vencido. Confira e digite de novo, ou volte para pedir um novo código."** Ela diz "volte para pedir" porque a tela do código não tem reenvio — quem precisa de outro código usa o botão "Cancelar e voltar para o login" (`cancel_recovery_link.dart`), a única saída dessa etapa; se o reenvio virar botão, o texto muda junto. Pedir outro dentro de 60 segundos esbarra em `over_email_send_rate_limit`, que tem mensagem própria e distinta. **O fluxo tem dois modos de falha que a pessoa alcança sozinha, e são estes:** código recusado, aqui, e **senha nova fraca**, no passo seguinte — cada um com mensagem própria e ação corretiva legível. O pedido de recuperação para endereço que nunca teve conta **não é um deles**: por anti-enumeração ele responde igual ao de endereço existente (**FD-024**, **FD-025**), e cobrar dele um estado distinto seria pedir o oposto do que a segurança garante. Já o limite de reenvio é falha de ambiente, não do fluxo, e o roteiro de E2E é desenhado para não encostar nele. **Nenhum desfecho desta tela pode cair na mensagem genérica de erro inesperado nem na de sessão expirada:** foi exatamente o que aconteceu enquanto `otp_expired` não estava traduzido, e o texto genérico escondia a única ação corretiva que a pessoa tinha.

**A etapa de nova senha tem saída própria: "Sair sem trocar a senha"** (`sign_out_without_changing_password_link.dart`, montado por `new_password_step_form.dart`). Ela existe porque essa etapa não tem botão de cancelar: o `verifyOTP` do passo anterior já autenticou a sessão, e sem uma saída explícita a pessoa ficaria presa entre digitar a senha nova ou fechar o app com uma sessão de recuperação ligada. Ao tocar, o fluxo encerra a sessão (`signOut`) antes de desligar o escopo de recuperação, e devolve a pessoa à tela de entrar: a sessão fica encerrada, e a senha antiga continua valendo — nada foi trocado. O resíduo de matar o app nessa etapa em vez de usar o botão, e a razão de ficar aceito em vez de fechado, estão em **FD-029** (`decisions.md`).

O lado Dart do deep link já está pronto (`detectSessionInUri = true` por default), então trocar depois é barato e a tela de código continua valendo como caminho alternativo. **Limitação conhecida e aceita:** o GoTrue manda o link junto do código, e quem clicar cai no navegador sem voltar para o app — o texto do e-mail e a tela instruem a digitar.

**SMTP.** Provedor: **Gmail com App Password**. O domínio do projeto é `supabase.ganza.bmjtech.duckdns.org` e o DuckDNS não permite registro SPF, DKIM ou DMARC — o que elimina Resend, Brevo, SES e Postmark, todos condicionados a domínio verificado. Criar a conta é do humano e bloqueia **apenas** a validação do fluxo num ambiente real. A stack local instala um capturador de e-mail em `infra/local/docker-compose.yml`, com o comando de leitura documentado em `infra/local/README.md`, e é dele que o E2E lê o código.

## 8. Segurança da camada de IA — a forma em que o pipeline nasce

O que substitui filtro de palavra e "detector de injection" é **privilégio zero da saída do modelo**: não importa o que o modelo diga, o caminho de escrita é código determinístico, com conjunto fechado de ações e de campos, atrás de confirmação humana. Uma defesa que funciona mesmo com o modelo **inteiramente** controlado pelo atacante é a única que se prova com teste; um filtro só se prova contra os exemplos que alguém pensou em escrever.

Módulos novos em `supabase/functions/_shared/`, todos com teste e **sem nenhuma dependência nova** em `supabase/functions/deno.json`:

| Módulo | O que garante |
|---|---|
| `ai/prompt_envelope.ts` | instrução e dado em campos **separados**, nunca uma string concatenada; conteúdo de terceiro delimitado por nonce gerado por chamada; caracteres invisíveis e de sobrescrita bidirecional removidos; teto de tamanho por fonte e no total |
| `ai/proposal_schema.ts` | validação estrita da saída do modelo: raiz precisa ser **lista**; `kind` em conjunto fechado; campo fora da allowlist **rejeita a proposta inteira**, não sanea; nenhum id de linha (`area_id`, `category_id`) vindo do modelo, porque FK não é filtrada por RLS (decisão **D13**) |
| `ai/normalize_description.ts` | chave de aprendizado determinística, charset e comprimento fechados — texto de 4 000 caracteres com instruções embutidas vira 64 caracteres inertes, e homoglifo ou zero-width não cria chave gêmea |
| `ai/limits.ts` | teto de entrada (`413`), de taxa e de custo por usuário (`429`), apurado sobre `ai_usage` **com o JWT do usuário**, deixando a RLS escopar; recusa registrada onde o custo é visível |
| `ai/proposal_writer.ts` | o **único** caminho de escrita derivado do modelo: alcança `proposed_actions` e nada mais; a tabela final só é alcançada por confirmação, que **revalida o payload lido do banco** e monta a linha por allowlist |
| `observability/ai_event.ts` | registro com struct fechada de escalares e hash do conteúdo — não existe campo de texto livre por onde conteúdo passe |

Nenhum desses módulos alcança `Deno.env`. Não é estilo: enquanto a chave de serviço estiver no ambiente de todo worker (**D19**), um caminho de erro que serialize o ambiente é a rota curta de "vazar segredo pelo modelo".

A prova negativa da fase é um corpus adversarial versionado passando pelo pipeline inteiro contra o Postgres local e `select count(*) from public.transactions` devolvendo `0`.

## 9. Decisões tomadas aqui (com a fonte)

| # | Decisão | Fonte |
|---|---|---|
| 1 | ~~A Fase 1 **mede** a persistência de sessão antes de implementar "lembrar"~~ **Medido em 20/08/2026 (T1.1):** a sessão **não cai** — sobrevive a `force-stop` e a `reboot`, e o app sequer chama o servidor ao reabrir. **"Lembrar login" saiu do escopo** (**FD-023**); no lugar entrou a **T1.12**, que preenche de volta só o e-mail, em memória | `bootstrap.dart` sem `authOptions` + ausência de timeout nos dois ambientes; evidência em `e2e/round_01/` |
| 2 | Recuperação por código de seis dígitos, não por deep link | custo de configuração de plataforma não testável no CI |
| 3 | O nome vai em `display_name`, não em `settings jsonb` | escalar lido a cada abertura; `jsonb` trocaria tipo e restrição por nada |
| 4 | O e-mail é somente leitura | ~~confirmação automática ligada e sem SMTP: trocar sem prova de posse tranca a pessoa para fora~~ **A razão técnica caiu com a FD-022** (o servidor passou a exigir prova de posse de endereço novo). A decisão não muda, e o motivo agora é **escopo**: nenhuma fase desta feature entrega o fluxo de troca de e-mail, e reabri-lo é chamada do dono do produto (**FD-014**) |
| 5 | Troca de senha logado exige a senha atual | o app guarda extrato bancário; aparelho destravado não pode bastar para tomar a conta |
| 6 | A tela de senha mora no `auth_module`, com rota `/configuracoes/conta/senha` | manter o barrel do auth como está custa menos que ampliar a exceção documentada |
| 7 | Isolamento da chave é o desenho de dois passos, não o cofre | o cofre é global ao projeto e não tem noção de dono |
| 8 | Ponte para o cofre é função `security definer`, não conexão direta | conexão direta entra como `postgres` — o que a **P8** manda evitar |
| 9 | Gatilho `before delete` limpa o segredo no cofre | `vault.secrets` não aceita FK para `auth.users`; segredo órfão é cifrado e eterno |
| 10 | O gate mora no router; corpo de página nunca decide se a tela funciona | tela alcançável é tela funcional; a prova é por grep |
| 11 | Item indisponível aparece **apagado com o motivo**, nunca escondido | "o app não insiste" (§11.4) não é "o app engana" |
| 12 | Sem BYOK no provedor bancário: credencial é do projeto, em env | o provedor autentica o projeto, não a pessoa |
| 13 | Sem webhook nesta feature | seria a primeira escrita sem usuário na frente, que dispara a **P8** |
| 14 | Defesa contra injeção é privilégio zero, não filtro nem classificador | paráfrase é infinita; classificador por modelo é um modelo lendo o texto do atacante |
| 15 | `ai_provider_kinds` ≠ `ai_providers`/`ai_routes` | catálogo de origem de chave do usuário vs. roteamento de `task_type` |

## 10. Dependências humanas

Nenhuma é trabalho de agente. Cada uma exige conta externa ou decisão do humano, e o fatiamento isola o que depende delas. **B1 a B5 é a numeração provisória do rascunho; os rótulos definitivos são P9 a P13**, na mesma ordem, em [`03_plan.md`](03_plan.md) §1 — e é lá que o estado de cada uma se lê.

| # | O que falta | O que bloqueia |
|---|---|---|
| ~~B1~~ | ~~Conta de e-mail para SMTP (Gmail com App Password)~~ **Resolvida em 20/08/2026:** o App Password existe e as cinco variáveis entram na HML no redeploy da **FD-022** | nada mais. O E2E sempre usou o capturador local |
| ~~B2~~ | ~~Cadastro aberto com confirmação automática: aceitar a dívida ou desligar a confirmação~~ **Decidida em 20/08/2026 (FD-022):** cadastro aberto **com** confirmação de e-mail, `ENABLE_EMAIL_AUTOCONFIRM=false` | nada mais. A ordem da virada — as duas variáveis do GoTrue junto do SMTP — está em `docs/deploy/coolify.md` |
| B3 | Destino da branch `feature/GZ-20-lembrar-login` | nada. A abordagem está descartada por escrito, e a medição da T1.1 desmentiu a premissa dela (**FD-023**); apagar branch é irreversível e a ordem é do humano |
| B4 | Montar a chave-mestra do cofre em volume no servidor | **a primeira chave real de IA em produção**, e só isso |
| B5 | Conta e credenciais do provedor bancário | a fase de integração bancária inteira, do primeiro comando ao E2E |

## 11. Riscos

| # | Risco | Tratamento |
|---|---|---|
| X1 | **O cadastro tranca calado se a confirmação for desligada sem o e-mail sair.** O risco original — endereço inventado virando conta confirmada — morreu com a **FD-022**, que desligou a confirmação automática; o que ficou é o inverso: sem SMTP entregando, ninguém confirma e ninguém entra, e o `signup` continua respondendo `200` | As duas variáveis do GoTrue viram **no mesmo redeploy** das cinco de SMTP, nunca antes. Na stack local o modo de falha não existe: o capturador recebe todo e-mail |
| X2 | **O menu reintroduz o glifo do Material** pelo `DrawerButton` que o `Scaffold` injeta, e o guard não pega — ele não tem checagem de ícone | `leading:` explícito por token, e `rtk proxy grep -rnE '(^|[^A-Za-z])Icons\.' app/lib` vazio no DoD da fase (ancorado, senão casa `AppIcons.`); a checagem entra no guard pela **T2.9** |
| X3 | **`flutter test` não cobre `app/patrol_test/`**: a troca de navegação deixa o CI verde e o emulador vermelho | Instrumentar e executar em tarefas separadas, e os roteiros herdados verdes **na mesma rodada** |
| X4 | **A chave-mestra do cofre não está em volume**: recriar o contêiner do banco torna todo segredo indecifrável | Medir em produção sem mudar estado, reproduzir a falha na stack local, deixar o trecho de compose pronto — e nenhuma chave real em produção antes de **B4** |
| X5 | **Exclusão de conta deixaria segredo órfão no cofre** | Gatilho `before delete`, provado pelo caminho da conta e pela remoção temporária do gatilho |
| X6 | **Chave de serviço no ambiente de todo worker** (**D19**), com a primeira função que legitimamente precisa dela chegando agora | Escopo de `envVars` por função, com teste sobre módulo puro |
| X7 | **O gate protege um destino sem tela** e pode nascer inerte | Teste de widget que navega e assere o desvio, e que falha se a linha do `redirect` sair |
| X8 | **`scripts/local-supabase.sh up` não reaplica migrations num volume já inicializado** — uma migration nova pode ficar de fora e a prova de RLS passar contra o schema antigo | Toda tarefa de migration usa o caminho de reset, e toda prova de RLS confere `select auth.uid()` **antes** de contar linhas, para uma contagem zero nunca passar pelo motivo errado |
| X9 | **Escopo.** A casca de Configurações convida a crescer, e cada seção nova parece barata | A régua são os critérios de aceite do PRD: três seções, e o chat acende |
