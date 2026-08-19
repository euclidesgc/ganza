# 001 - Cadastro manual ponta a ponta · Plano

Fatiamento e execução. O "o quê" está em [`02_specs.md`](02_specs.md), o contrato do pronto em [`01_prd.md`](01_prd.md), as decisões desta feature em [`decisions.md`](decisions.md), os desvios em [`changes.md`](changes.md), e o item canônico está no [`docs/roadmap.md`](../roadmap.md). **Este plano não inventa escopo: ele distribui o DoD entre as fases e acrescenta o que falta para cada fase se sustentar sozinha.**

Estado: **Fase 4 aguardando merge** · branch `feature/GZ-17-registrar-transacao` (de `develop`) · T4.1–T4.7 concluídas, E2E da rodada 02 verde e atestado pelo dev, DoD fechado e [PR #20](https://github.com/euclidesgc/ganza/pull/20) com os cinco jobs verdes; **próximo passo: mergear o PR 4 e começar a Fase 5**.

---

## Gauntlet

**Referência:** [`01_prd.md`](01_prd.md), [`02_specs.md`](02_specs.md),
[`decisions.md`](decisions.md), [`changes.md`](changes.md), este plano,
`CLAUDE.md` e as decisões transversais em [`docs/decisions.md`](../decisions.md).

**Rubrica binária:** cada fase só passa quando contrato/DoD, arquitetura,
invariantes de produto, segurança e evidência E2E aplicável estiverem `pass`.
Resultado subjetivo, impressão geral ou nota não são critérios de aprovação.

**Invariantes bloqueantes:** RLS comprovada, nenhuma credencial no cliente,
dinheiro em centavos inteiros, função com JWT do usuário e nenhuma gravação sem
confirmação quando a feature passar a ter ingestão por IA.

**Provas:** cada crítico devolve `pass` ou `fail`, evidência reproduzível,
arquivo/linha e ação corretiva. QA executa os comandos; CISO e crítico
integrador revisam sem editar a fatia implementada.

**Limites:** no máximo 3 rodadas e 45 minutos por fase. Uma reprovação retorna
ao executor; ao atingir o limite, o tech-manager registra o dossiê e aguarda
decisão humana. Depois de consolidar tarefas paralelas, o crítico integrador
revisa as dependências cruzadas antes do fechamento.

**Evidência E2E:** fica em `e2e/round_NN/`. Cada `report.md` liga cada passo a
um print, log ou saída de comando. O E2E roda somente contra a stack
local, por `patrol test`.

---

## 1. Decisões travadas antes de começar

As decisões A1–A7 e seus impactos são a fonte de verdade em
[`decisions.md`](decisions.md). Decisões globais continuam em
[`../decisions.md`](../decisions.md). Desvio posterior é registrado em
[`changes.md`](changes.md) antes da reconciliação deste plano.

---

## 2. Âncoras no código existente

O que imitar, e onde. Levantado pelo grafo antes de escrever este plano.

**App (`app/lib/`)**
- Gabarito do módulo: `app/lib/modules/areas_module/` — barrel público expondo só rotas e DI, `domain/`, `data/`, `presentation/<feature>/`. **Não há `datasources/`**: o `AreasRepositoryImpl` recebe o `SupabaseClient` no construtor e fala com ele direto. O `transactions_module` copia essa forma.
- Leitura: `areas_repository_impl.dart` faz `_client.from('areas').select(...).isFilter(...).order(...)` **sem filtro por `user_id`** — quem filtra é a RLS. A leitura de `transactions` segue igual.
- Validação de model: zard, em `abstract final class AreaModel` com só estáticos, `_schema.safeParse(...)` → `Either<Failure, Area>`; o helper privado `_withoutNulls` existe porque o `.nullable()` do zard não aceita `null` real — **`area_id` nulo vai precisar dele**.
- Estado: `sealed class AreasState` + `final class` por estado, via `part of` no cubit; guarda `if (isClosed) return;` depois de todo `await`.
- Página: `StatelessWidget` + `static Widget pageBuilder` — único ponto que toca o `get_it`.
- Registro: `app/lib/injection.dart` (`registerDependencies`) e `app/lib/app_router.dart` (`routes: [...]`), que só importam barrels públicos.
- Sessão: não existe wrapper. Token é `getIt<SupabaseClient>().auth.currentSession?.accessToken`; usuário é `getIt<GetCurrentUser>()()` → `AuthenticatedUser?`. A guarda de rota do `app_router.dart` já manda para `/entrar` quando a sessão cai — é o que atende o caso "JWT expirado durante o preenchimento" do `01_prd.md`.
- Erros: `sealed class Failure` em `app/lib/core/error/failure.dart` (`NetworkFailure`, `NotFoundFailure`, `ValidationFailure`, `AuthFailure`, `PermissionFailure`, `UnexpectedFailure`). O tradutor único é a função de topo `failureFromException(Object)` em **`app/lib/core/network/failure_from_exception.dart`** (mora em `core/network`, não em `core/error`).
- **Não existe formatador de moeda nem de data, nem helper de centavos.** `intl: ^0.20.2` está no `pubspec.yaml` e não é usado em uma única linha. Tudo isso nasce nesta feature.
- Tema: `app/lib/core/theme/` com `AppSpacing`, `AppRadii`, `AppDurations`, `AppTypography`, `GanzaColors` (`ThemeExtension`) e a extensão de contexto (`.theme`, `.texts`, `.colors`, `.ganza`). `scripts/gates_guard.sh` reprova qualquer literal de estilo fora dessa pasta.

**Backend (`supabase/functions/`)**
- `main/index.ts` roteia por `pathname.split('/')[0]`, cria um `userWorker` em `/home/deno/functions/<nome>` e repassa a requisição. `const PUBLICAS = new Set(['health'])` — `transactions` **não** entra aí. **Não há tratamento de `OPTIONS` nem header CORS em lugar nenhum do repo.**
- `health/` é o gabarito: `index.ts` com só `Deno.serve(handler)`, `handler.ts` exportando o comportamento, `index_test.ts` com `@std/assert`.
- `deno.json`: `imports` com `@std/assert`, `@std/http/status` e `postgres`; `fmt` com `lineWidth: 100` e `singleQuote: true`. **A task `check` lista os arquivos um a um** — os novos precisam ser adicionados nela, senão o CI passa sem checar tipo nenhum.
- Publicar é `scripts/deploy-functions.sh`: `tar` sobre ssh para o volume do Coolify + `docker restart` do edge-runtime. **Não é auto-deploy** — é um comando manual que toca a VPS de produção.

**Banco (`supabase/migrations/`)**
- Existem `0001_habilitar_extensoes.sql`, `0002_criar_profiles_e_areas.sql`, `0003_criar_perfil_e_areas_padrao_no_signup.sql`. O próximo é `0004`.
- Formato da política, literal de `0002`:
  ```sql
  alter table public.areas enable row level security;

  create policy areas_owner on public.areas
    for all
    using (user_id = auth.uid())
    with check (user_id = auth.uid());
  ```
- **Não existe trigger de `updated_at`** no repositório: as tabelas têm a coluna com `default now()` e nada a atualiza. `transactions` segue a mesma convenção — criar o trigger agora seria escopo novo, e F21 (edição) é Fase 3.

**CI (`.github/workflows/ci.yml`)** — 4 jobs, disparados por `paths-filter`: `changes`, `app` (`dart format --set-exit-if-changed`, `flutter analyze`, `scripts/gates_guard.sh`, `flutter test -r compact`), `functions` (`deno fmt --check`, `deno lint`, `deno task check`, `deno task test`), `migrations` (aplica `ci-bootstrap.sql` + todas as migrations num `supabase/postgres:15.8.1.085` vazio, depois **gate de RLS ligada** e **gate de política existente**, ambos inline no yml).

---

## 3. Schema fechado — `supabase/migrations/0004_criar_transactions.sql`

Fechado pelo PM. **Não reabrir**; transcrito aqui para que a Fase 1 não precise de outro documento.

| Coluna | Definição |
|---|---|
| `id` | `uuid primary key default gen_random_uuid()` |
| `user_id` | `uuid not null default auth.uid() references auth.users(id) on delete cascade` |
| `area_id` | `uuid references public.areas(id) on delete set null` (**nulável**) |
| `direction` | `text not null check (direction in ('in','out'))` |
| `amount` | `bigint not null check (amount > 0)` — **centavos** |
| `description` | `text not null check (char_length(btrim(description)) > 0)` |
| `occurred_at` | `timestamptz not null default now()` |
| `source` | `text not null default 'manual' check (source in ('manual','chat','bank_sync'))` |
| `reconciliation_status` | `text not null default 'pending' check (reconciliation_status in ('pending','matched','standalone','ignored'))` |
| `created_at` | `timestamptz not null default now()` |
| `updated_at` | `timestamptz not null default now()` |

```sql
create index transactions_user_occurred_idx
  on public.transactions (user_id, occurred_at desc, created_at desc);

alter table public.transactions enable row level security;

create policy transactions_owner on public.transactions
  for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
```

---

## 4. Ritual de fechamento de fase (vale para todas)

Escrito uma vez para não se repetir em cinco lugares. **Nenhuma fase avança sem os quatro passos.**

1. O especialista dono implementa; `especialista-*` executa, o tech-lead não escreve código.
2. **QA roda `revisar-fase`** contra este plano e as regras do `CLAUDE.md`.
3. **CISO revisa o diff** da fase (sem `Write` — aponta, não conserta).
4. **`fechar-etapa` roda o DoD da fase, linha por linha, de verdade.** Só então: PR com o DoD no corpo e o resultado de cada linha → CI verde → merge em `develop` → próxima fase.

`CHANGELOG.md` (seção `Unreleased`) é atualizado **no mesmo PR** da mudança, em toda fase.

---

## 5. Fases

### Fase 1 — Migration `transactions` + docs vivas · PR 1

Branch: `feature/GZ-14-migration-transactions` (já criada). A migration fica
isolada em seu PR e é provada primeiro em banco local vazio.

**Tarefas**

- [x] **T1.1** — `supabase/migrations/0004_criar_transactions.sql` conforme o §3 deste plano, via skill `criar-migration`. Zero comentário na mecânica; comentário só no *porquê* de `area_id` ser nulável e de `amount` ser `bigint`. · camada **migration** · `especialista-backend`
- [x] **T1.2** — `docs/001_cadastro_manual/{02_specs.md,01_prd.md,03_plan.md}` entram neste PR. · camada **docs** · `tech-lead`
- [x] **T1.3** — `docs/roadmap.md`: F0.9 para `[-]`, registro das decisões A1/A2/A3 na tabela de decisões travadas (viraram **D13**, **D14** e **D15**) e baixa da **P5** condicionada à T3.2. Fechou junto o que saiu das cancelas desta fase: **D12** (o stand-in de `auth.uid()`), a correção do texto da **P8**, a dívida de FK×RLS na Fase 1 do roadmap e o item de CORS na Fase 8. · camada **docs** · `tech-lead`

Sequenciais. Não marco `[paralela]` aqui: são três tarefas curtas e duas escritas simultâneas na mesma working directory se atropelam — o custo de worktree não se paga.

O desvio da Fase 1 sobre o stand-in de `auth.uid()` está registrado como
[`CHG-001`](changes.md#chg-001---stand-in-de-authuid-alinhado-ao-formato-real-do-gotrue).
Este plano já descreve a prova corrigida.

**DoD da Fase 1**

- [x] Num Postgres vazio local (`supabase/postgres:15.8.1.085`), `ci-bootstrap.sql` + as quatro migrations em ordem com `ON_ERROR_STOP=1` terminam **sem erro**. O `ci.yml` roda `psql -q`, que não imprime nada — **quem prova é o código de saída, não a saída**: rodar exatamente como o CI e checar `echo $?` → `0` em cada arquivo. Depois, com os objetos já no lugar: `psql -tAc "select to_regclass('public.transactions')"` → `transactions` e `psql -tAc "select policyname from pg_policies where tablename='transactions'"` → `transactions_owner`. Colar as três saídas no PR.
- [x] Gate de RLS: `select tablename from pg_tables where schemaname='public' and rowsecurity = false` devolve **0 linhas**.
- [x] Gate de política: a consulta de tabela-com-RLS-sem-política do `ci.yml` devolve **0 linhas**.
- [x] Cada `check` rejeita, com `ERROR: new row ... violates check constraint`: `amount = 0`, `amount = -1`, `direction = 'x'`, `description = '   '`. Quatro comandos, quatro erros — colar a saída no PR.
- [x] RLS provada em três comandos, **nesta ordem**, com a sessão montada na forma real do GoTrue — `set local request.jwt.claims = '{"sub":"<uuid do dono>","role":"authenticated"}'`, que é a que o stand-in do `ci-bootstrap.sql` passou a ler (**D12**):
  1. **Antes de inserir**, `select auth.uid()` devolve o uuid do dono, **não NULL**. Esta linha existe para impedir a prova falso-positiva: com `auth.uid()` NULL a política rejeitaria o próprio dono, e a negação do item 3 pareceria funcionar pelo motivo errado.
  2. `insert` como `anon`, **sem** `request.jwt.claims`, é negado: `ERROR: new row violates row-level security policy for table "transactions"`.
  3. `insert` do dono é aceito, e `user_id` vem do `auth.uid()` e não do payload — **inclusive** quando o `insert` traz explicitamente o `user_id` de outra conta. Conferir com `select user_id from public.transactions order by created_at desc limit 1`.
- [x] `select indexdef from pg_indexes where indexname = 'transactions_user_occurred_idx'` devolve a definição com `occurred_at DESC, created_at DESC`.
- [x] **Job "Banco" verde no CI do PR.** *(linha 1 do DoD do roadmap)*

---

### Fase 2 — Edge Function `transactions` + testes Deno + publicação · PR 2

Branch: `feature/GZ-15-edge-function-transactions`. Contrato em `02_specs.md` §4.

**Tarefas**

- [x] **T2.1** — `supabase/functions/transactions/handler.ts`: `export default async function handler(req: Request): Promise<Response>`. Só `POST` (senão `405`). Checa `Authorization` na borda **antes de tocar no banco** (senão `401`, mesmo com `VERIFY_JWT` desligado). Cria o client com o **JWT do usuário**, nunca `service_role`. Valida `direction ∈ {in,out}`, `amount` número **inteiro** `> 0`, `description` string com 1..200 após `trim`, `occurred_at` opcional e ISO-8601 parseável. `201` com a linha criada. Nenhum `any` atravessa; `area_id` e `user_id` **não** fazem parte do payload aceito. · camada **backend** · `especialista-backend`
- [x] **T2.2** — `supabase/functions/transactions/index.ts` com `Deno.serve(handler)` e nada mais. · camada **backend** · `especialista-backend`
- [x] **T2.3** — `supabase/functions/transactions/handler_test.ts` cobrindo `201`, os seis `400` (`invalid_json`, `invalid_direction`, `invalid_amount` para não-inteiro e para `<= 0`, `invalid_description` vazia e >200, `invalid_occurred_at`), `401` e `405`, e o caso "payload com `user_id` alheio não muda o dono". **É a única bateria de teste escrita fora da fase final**, porque o DoD do roadmap a exige nominalmente. · camada **backend** · `especialista-backend`
- [x] **T2.4** — Alinhar `supabase/functions/main/index.ts` ao contrato de erro `{"error":{"code":"...","message":"..."}}` (decisão **A5**) e acrescentar `transactions/index.ts` e `transactions/handler.ts` à task `check` do `deno.json`. · camada **backend** · `especialista-backend`
- [x] **T2.5** — Depois do merge em `develop`, publicar a função na HML pelo
  fluxo de deploy. Isso não é prova E2E nem smoke remoto; a validação completa
  ocorre localmente antes do PR. · camada **infra** · `especialista-infra`

Sequenciais: T2.3 depende do handler; T2.5 depende do merge.

**DoD da Fase 2 — antes do PR**

- [x] `deno fmt --check`, `deno lint` e `deno task check` verdes em `supabase/functions/` (o `check` já listando os arquivos novos).
- [x] `deno task test` verde, cobrindo valor não-inteiro (`45.5`) e `direction` fora de `in|out` virando `400`. *(linha 2 do DoD do roadmap)*
- [x] **Cada teste de validação visto falhando sem a validação**: comentar a regra, rodar, colar o `FAILED`, restaurar. Um por regra, não uma amostra. *(segunda metade da linha 2 do roadmap)*
- [x] Com a função servida localmente (`deno serve` apontando `SUPABASE_URL` para o Supabase real) e um JWT de sessão: `POST` do caminho feliz devolve **`201`** com `id`, `source: "manual"`, `reconciliation_status: "pending"` e `amount` inteiro; **sem `Authorization`** devolve **`401`** com corpo `{"error":{"code":"unauthorized",...}}`.
- [x] O `401` sem `Authorization` é comprovadamente da função ou do roteador, **não do Kong**: a requisição vai com `apikey` e sem `Authorization`, e o corpo devolvido é o do contrato.
- [x] `select user_id, amount, source from public.transactions order by created_at desc limit 1` mostra o `user_id` do JWT mesmo quando o payload trouxe `user_id` alheio.
- [x] Job "Edge Functions" verde no CI do PR.

**DoD da Fase 2 — depois do merge (bloqueia o início da Fase 3)**

- [x] `curl -sf https://supabase.ganza.bmjtech.duckdns.org/functions/v1/health` devolve `{"status":"ok","database":"reachable"}` — o restart do runtime não derrubou nada.
- [x] `curl -X POST https://supabase.ganza.bmjtech.duckdns.org/functions/v1/transactions` com `apikey` + JWT da conta **cria a linha e devolve `201`**; a mesma chamada **sem `Authorization`** devolve **`401`**. *(linha 3 do DoD do roadmap — só passa com a função no ar)*
- [x] `GET https://…/rest/v1/transactions` **anônimo** (só `apikey`) devolve `[]`; com o `Authorization` do dono devolve a transação criada acima. *(linha 4 do DoD do roadmap — a RLS provada pelo caminho real)*

A linha criada aqui **fica no banco de propósito**: é o dado que a Fase 3 vai exibir na tela.

---

### Fase 3 — Leitura: lista de transações no app · PR 3

Branch: `feature/GZ-16-listar-transacoes`. Módulo novo `app/lib/modules/transactions_module/`, no gabarito da skill `criar-modulo` (referência, não execução cega). **Leitura vem antes da escrita** porque a linha plantada pelo `curl` da Fase 2 já está no banco: esta fase tem o que mostrar sem depender do formulário.

**Frente A e frente B rodam em paralelo, em worktrees isolados.** Arquivos disjuntos, nenhuma espera resultado da outra.

- [x] **T3.1** `[paralela · frente A · worktree]` — `app/lib/core/format/`: `money_formatter.dart` (centavos `int` → `R$ 45,00`, `−R$ 45,00` com o menos tipográfico, milhar pt-BR, **sem `double` em nenhuma linha**) e `date_formatter.dart` (`15/08, sexta`, minúsculo; ano diferente do corrente vira `15/08/2025, sexta`; **nunca** "hoje"/"ontem"). Barrel `format.dart`. Inclui `initializeDateFormatting('pt_BR')` no `bootstrap.dart` — sem isso o `EEEE` não sai em português. · camada **core** · `especialista-infra`
- [x] **T3.2** `[paralela · frente A · worktree]` — Fontes: baixar Fraunces e IBM Plex Sans (SIL OFL) para `app/assets/fonts/`, declarar no `pubspec.yaml` e ligar em `core/theme/app_typography.dart`, com `FontFeature.tabularFigures()` no estilo de valor monetário. Encerra a **P5** do roadmap. · camada **core/tema** · `especialista-infra`
- [x] **T3.3** `[paralela · frente B · worktree]` — `domain/`: `Transaction` (`Equatable`, imutável, sem `fromMap`), `TransactionDirection` como enum fechado com o valor de fio `'in'`/`'out'`, `abstract interface class TransactionsRepository` com `Future<Either<Failure, List<Transaction>>> list()`, e o use case `ListTransactions` com `call()`. Barrel `domain.dart`. · camada **domain** · `especialista-dominio`

Consolidar as duas frentes na branch da fase antes de seguir. Daqui em diante é sequencial — cada tarefa depende da anterior.

- [x] **T3.4** — `data/models/transaction_model.dart`: `abstract final class` só com estáticos, `safeParse` do zard → `Either<Failure, Transaction>`, `amount` como `z.int()` (payload com `amount` string é `ValidationFailure`, não crash), e o tratamento de `area_id` nulo pelo mesmo caminho do `_withoutNulls` do `AreaModel`. · camada **data** · `especialista-dados`
- [x] **T3.5** — `data/repositories/transactions_repository_impl.dart`: recebe o `SupabaseClient` no construtor, `from('transactions').select(...)` **sem filtro de `user_id`** (quem filtra é a RLS), `.order('occurred_at', ascending: false).order('created_at', ascending: false)`. Único `try/catch`, `failureFromException`. · camada **data** · `especialista-dados`
- [x] **T3.6** — `presentation/transactions_list/`: `TransactionsListCubit` + estado `sealed` (`Loading`, `Loaded`, `Empty`, `LoadFailed`) via `part of`, guarda `isClosed`; `TransactionsListPage` (`StatelessWidget` + `static Widget pageBuilder`); `widgets/` com a linha da transação (descrição em uma linha com reticências, data explícita, valor à direita com algarismos tabulares e prefixo textual `−`/`+` **além** da cor), o estado vazio ("Nenhuma transação registrada.", sem ilustração e sem entusiasmo) e o estado de erro com "tentar de novo". Zero literal de estilo. · camada **presentation** · `especialista-apresentacao`
- [x] **T3.7** — `transactions_routes.dart` (`/transacoes`), `transactions_injection.dart`, barrel `transactions_module.dart`, registro em `app/lib/injection.dart` e `app/lib/app_router.dart`, e o ponto de entrada na `AppBar` da `AreasPage` (decisão **A6** — só a ação, nada de dashboard). · camada **presentation/infra** · `especialista-apresentacao`
- [x] **T3.8** — E2E: QA roda `instrumentar-e2e` (gate do CISO **antes**) por
  `patrol test`, com `PatrolJUnitRunner`, AndroidX Orchestrator e
  `MainActivityTest.java` versionado em `androidTest`; cada cenário salva
  asserções, print e log no marcador exato, encaminhado por `adb reverse`
  inclusive na indisponibilidade do Supabase local por `iptables`,
  imediatamente após a asserção visual, em
  `docs/001_cadastro_manual/e2e/round_01/`, com `README.md` descrevendo a
  evidência. · `qa` + `ciso`

**DoD da Fase 3**

- [x] `dart format --set-exit-if-changed`, `flutter analyze` e `scripts/gates_guard.sh` verdes; `flutter test -r compact` continua verde com a suíte que já existe (nenhum teste novo nesta fase).
- [x] `e2e/round_01/` — print do **estado vazio** da lista, numa conta sem transação, mostrando "Nenhuma transação registrada.". *(`02_estado_vazio.png`)*
- [x] `e2e/round_01/` — print da lista **com a transação criada pelo `curl` da Fase 2**, na mesma imagem: descrição, data no formato `15/08, sexta` e valor `−R$ 45,00` alinhado à direita. *(linhas 6 e 7 do DoD do roadmap; `03_lista_carregada.png` — datas reais `14/08, sexta` e `15/08, sábado` cobrem as duas metades da forma, ver README da rodada)*
- [x] `e2e/round_01/` — print com um valor grande (`R$ 1.234.567,89`) e um de dois dígitos **na mesma lista**, provando que a coluna de valores não dança entre linhas. É o teste real dos algarismos tabulares, e não fecha sem a T3.2. *(`04_algarismos_tabulares.png`)*
- [x] `e2e/round_01/` — **erro de leitura e lista vazia em prints distintos**, provando que os dois estados são visualmente diferentes: o `01_prd.md` exige que uma falha nunca se disfarce de "nada aqui". Induzido derrubando a rede do emulador. *(`01_erro_de_leitura.png` + `02_estado_vazio.png`)*
- [x] O E2E é atestado pelo **dev humano**, não pelo QA. O `report.md` da rodada nomeia cada passo, comando e evidência.
- [x] Job "App" verde no CI do PR.

---

### Fase 4 — Escrita: formulário → Edge Function → lista · PR 4

Branch: `feature/GZ-17-registrar-transacao`. Fecha o ciclo: a mesma tela que lê passa a escrever.

- [x] **T4.1** `[paralela · frente A · worktree]` — `app/lib/core/format/cents_input.dart`: acumulação de dígitos → centavos (`"4500"` → `4500`), máximo 9 dígitos inteiros. **Nunca `double.parse(x) * 100`** — é a invariante nº 2 do `02_specs.md` e o bug que só aparece meses depois num total que não bate. · camada **core** · `especialista-infra`
- [x] **T4.2** `[paralela · frente A · worktree]` — `app/lib/core/network/failure_from_exception.dart` aprende `FunctionException`: `400` → `ValidationFailure`, `401` → `AuthFailure`, `403` → `PermissionFailure`, demais → `UnexpectedFailure`; falha de transporte continua `NetworkFailure`. Decisão **A4**. · camada **core** · `especialista-infra`
- [x] **T4.3** `[paralela · frente B · worktree]` — `domain/`: entidade de entrada `NewTransaction`, método `create(NewTransaction)` no contrato do repositório e use case `CreateTransaction`. · camada **domain** · `especialista-dominio`

Consolidar; daqui em diante sequencial.

- [x] **T4.4** — `TransactionModel.toPayload(NewTransaction)` (só `direction`, `amount`, `description`, `occurred_at`; **nunca** `user_id` nem `area_id`) e o `create` no `TransactionsRepositoryImpl` via `client.functions.invoke('transactions', body: …)`, com o `201` voltando pelo mesmo `safeParse` da leitura. · camada **data** · `especialista-dados`
- [x] **T4.5** — `presentation/new_transaction/`: cubit + estado `sealed`, e a página com os quatro campos na ordem do `02_specs.md` §6.1 — seletor **Despesa**/**Receita** com rótulo textual sempre visível (default Despesa), campo monetário pt-BR com dígitos entrando pela direita, descrição de até 200 caracteres travada na digitação, e seletor de data com default hoje e **futuro bloqueado na UI** (a função aceita; a Fase 3 do produto não pode herdar a trava). Botão **Registrar** desabilitado enquanto inválido **e** enquanto o envio está em voo. Em erro, o formulário **preserva o que foi digitado**. Rebuild escopado — o campo de valor não reconstrói a tela a cada tecla. · camada **presentation** · `especialista-apresentacao`
- [x] **T4.6** — Navegação e refetch: rota `/transacoes/nova`, entrada a partir da lista, e o retorno ao `201` **refazendo a leitura** pelo PostgREST em vez de inserir o item localmente — o refetch é a prova do caminho de volta. · camada **presentation** · `especialista-apresentacao`
- [x] **T4.7** — E2E Patrol rodada 2 (gate do CISO antes), pela mesma ponte
  JUnit versionada e callback de captura por `adb reverse`, com asserções,
  prints e logs imediatamente posteriores à asserção; a falha de transporte
  bloqueia o Supabase local por `iptables`, em `e2e/round_02/`. · `qa` + `ciso`

**DoD da Fase 4**

- [x] `dart format`, `flutter analyze`, `gates_guard.sh` e `flutter test -r compact` verdes.
- [x] `e2e/round_02/` — sequência do caminho feliz: formulário preenchido (`Almoço`, `R$ 45,00`, data de ontem) → lista com a linha nova no topo. Registrada **pelo app**, não por `curl`.
- [x] `select amount, source, direction, user_id, area_id from public.transactions order by created_at desc limit 1` logo após o print: `amount` inteiro em centavos (`4500`, nunca `4499`), `source = 'manual'`, `user_id` da conta e **`area_id` nulo** — a decisão A1 verificada, não assumida.
- [x] `e2e/round_02/` — **cada modo de falha em estado visualmente distinto**: (a) envio sem rede → mensagem curta **com os campos ainda preenchidos**; (b) sessão expirada → o app vai para o login, não mostra erro genérico. Dois prints, dois estados diferentes.
- [x] `e2e/round_02/` — print do botão **Registrar** desabilitado durante o envio. Toque duplo não gera duas linhas: confirmado por `select count(*)` antes e depois.
- [x] Nenhuma transação foi gravada sem toque explícito em Registrar — invariante nº 1 do `CLAUDE.md`, verificada com `select count(*)` antes de abrir o formulário e depois de abandoná-lo preenchido.
- [x] E2E atestado pelo **dev humano**; `report.md` da rodada nomeando cada passo e o que cada imagem prova.
- [x] Job "App" verde no CI do PR. *(PR #20 — os cinco jobs verdes)*

---

### Fase 5 — Bateria automatizada e fechamento · PR 5

Branch: `feature/GZ-18-testes-cadastro-manual`. **Só começa depois do E2E das Fases 3 e 4 atestado pelo dev.** É aqui que os testes Dart nascem — não antes.

- [ ] **T5.1** — Segundo gate do CISO (depois da limpeza do E2E). · `ciso`
- [ ] **T5.2** — `escrever-testes`, conforme o inventário do `01_prd.md` §7: *domain* (use cases devolvendo `Either`), *data* (`safeParse` com payload válido, `amount` como string, `direction` desconhecida, `area_id` nulo), *core* (dígitos→centavos, centavos→`R$`, formatador de data com e sem ano), *cubit* (`bloc_test` de envio e de listagem, os três desfechos cada), *widget* (formulário: desabilitado inválido, desabilitado em voo, dados preservados após erro) e *widget* (**estado vazio da lista**). `test/` espelha `lib/`; `mocktail` + `bloc_test`; zero `build_runner`. · camada **testes** · `qa`
- [ ] **T5.3** — `manter-docs-vivas`: `final_report.md`, roadmap (F0.9 → `[x]`, P5 baixada), `CHANGELOG.md`, `README`. · camada **docs** · `qa`
- [ ] **T5.4** — atualizar `changes.md` para cada desvio aprovado durante as
  fases e reconciliar PRD, specs e plano na mesma tarefa. Sem novo desvio, não
  há nova entrada. · `tech-lead`
- [ ] **T5.5** — **Reescopo do E2E, decidido com a bateria da T5.2 já escrita.**
  Cena que só assere lógica não precisa de aparelho e paga o preço mais caro do
  projeto: no harness atual cada uma custa ~2,5 min de emulador, contra
  segundos em widget test. Candidatas medidas na rodada 02: campos preservados
  após erro, botão desabilitado enquanto inválido e em voo, descrição travada
  em 200 caracteres. **Permanecem no E2E** as provas que só o aparelho dá —
  renderização (algarismos tabulares), fuso do dispositivo, navegação real e o
  caminho de rede real. Encolher o roteiro **altera linhas do DoD das Fases 3 e
  4**, então a decisão entra em `changes.md` antes da mudança e vale das
  próximas features em diante — a evidência já colhida não é refeita. Depende
  da [`D20`](../decisions.md) (harness sem recompilação por cena) estar
  aplicada, senão o ganho se mistura com o do build. · camada **testes/docs** ·
  `qa` + `tech-lead`

**DoD da Fase 5**

- [ ] `flutter test -r compact` verde, **incluindo o widget test do formulário e o do estado vazio da lista**. *(linha 5 do DoD do roadmap)*
- [ ] Os testes de invariante de dinheiro vistos **falhando sem a mudança**: trocar a conversão de centavos por `double.parse(x) * 100` faz o teste do conversor falhar; colar o `FAILED` e restaurar.
- [ ] O widget test do estado vazio visto falhando quando o texto do estado vazio é removido.
- [ ] Os quatro jobs do CI verdes no PR.
- [ ] `docs/roadmap.md` com F0.9 em `[x]` e a **P5** fora da lista de pendências.

---

## 6. Rastreabilidade — as 7 linhas do DoD do roadmap

| # | Linha do DoD do roadmap | Fase que fecha |
|---|---|---|
| 1 | `0004_criar_transactions.sql` aplica limpo no CI, com RLS e política — job "Banco" verde | **1** |
| 2 | `deno task test` cobre a função; valor não-inteiro e `direction` inválida viram 400, com os testes vistos falhando | **2** (pré-PR) |
| 3 | `curl -X POST …/functions/v1/transactions` com JWT cria e devolve 201; sem `Authorization` devolve 401 | **2** (pré-PR, stack local) |
| 4 | `GET /rest/v1/transactions` anônimo devolve `[]` e com a sessão do dono devolve a transação | **2** (pré-PR, stack local) |
| 5 | `flutter test -r compact` verde, incluindo widget test do formulário e do estado vazio | **5** |
| 6 | E2E no emulador com print da transação na lista, em `e2e/round_01/`, atestado pelo dev | **3** (rodada_01) e reforçada na **4** (rodada_02, registro feito pelo app) |
| 7 | Valor com algarismos tabulares e data explícita, conferido no print | **3** |

---

## 7. Riscos e dependências que o DoD do roadmap não cobre

| # | Risco | Onde dói | Tratamento neste plano |
|---|---|---|---|
| X1 | **Sem CORS em nenhuma Edge Function.** Não há `OPTIONS` nem `Access-Control-Allow-*` no repo. O app é Android **e** Web (D2 — um `lib/`, dois alvos). No emulador Android o POST passa; no Chrome ele morre no preflight. | Fase 2, e só aparece quando alguém rodar `flutter run -d chrome` | **Não tratado nesta feature** — o E2E é Android e ampliar aqui é escopo novo. **Já registrado**: virou o primeiro item da Fase 8 (Web) do `docs/roadmap.md`, bloqueando o resto daquela fase. |
| X2 | **O `401` pode vir do Kong, não da função.** O gateway do Supabase self-hosted exige `apikey`; uma requisição sem nenhum header devolve `401` do Kong e a prova fecharia pelo motivo errado. | Fase 2 | Virou linha explícita do DoD da Fase 2: a chamada vai **com `apikey` e sem `Authorization`**, e o corpo tem que ser o do contrato. |
| X3 | **`deno task check` lista arquivos um a um.** Função nova esquecida na task passa pelo CI sem checagem de tipo nenhuma. | Fase 2 | Tarefa T2.4. |
| X4 | **Sem idempotência de servidor.** O botão desabilitado cobre o toque duplo, mas se a resposta se perder na rede a duplicata é possível. | Fase 4 | Limitação **conhecida e aceita** (`01_prd.md` §4). Não vira tarefa; vira linha do `final_report.md`. |
| X5 | **`updated_at` não é atualizado por nada** — nem aqui nem nas tabelas existentes. | F21, Fase 3 do produto | Fora de escopo por consistência com o repo. Registrado para quando a edição existir. |
| X6 | **O E2E pode apontar acidentalmente para HML.** Isso escreveria dados de teste fora do ambiente descartável. | Fases 2, 3 e 4 | `scripts/e2e-local.sh` e os roteiros específicos recusam host não local; `reset` e `down` removem containers, volumes e dados da rodada. |
| X7 | **O deploy da função pode reiniciar o edge-runtime da HML.** Não é prova de feature e pode indisponibilizar o endpoint por segundos. | Fase 2, T2.5 | O deploy ocorre apenas após merge em `develop`; não há smoke remoto obrigatório nesta rodada. |
| X8 | **`intl` nunca foi inicializado neste app.** `DateFormat('EEEE', 'pt_BR')` sem `initializeDateFormatting` lança em runtime, e o widget test passaria mesmo assim se o teste inicializar por conta própria. | Fase 3 | Embutido na T3.1, e o print do E2E é o que prova de verdade — um `LocaleDataException` apareceria na tela, não no teste. |

---

## 8. Progresso

Legenda: `[ ]` não iniciada · `[-]` em andamento · `[x]` mergeada em `develop`.

- [x] **Fase 1** — Migration + docs vivas · PR 1 — mergeada (PR #15).
- [x] **Fase 2** — Edge Function + testes Deno · PR 2 — mergeada (PR #17).
  DoD pré-PR verde na stack local; o merge em `develop` alimenta a HML sem
  E2E com escrita ou smoke remoto obrigatório.
- [x] **Fase 3** — Leitura: lista de transações · PR 3 — mergeada (PR #19).
  Job "App" verde no CI do PR; evidência em `e2e/round_01/`, que
  [`CHG-008`](changes.md#chg-008---evidência-da-rodada-01-precede-o-harness-patrol-local)
  registra como rodada histórica, cuja prova visual a rodada 02 refaz sob o
  harness Patrol local.
- [-] **Fase 4** — Escrita: formulário → Edge Function · PR 4 — T4.1–T4.7
  concluídas. E2E da rodada 02 verde em 30 min 33 s, com as dez cenas e o
  atestado do dev; DoD fechado, PR #20 com os cinco jobs do CI verdes.
  **Ressalva:** o gate do CISO desta fase não deixou veredito registrado — o
  diff de T4.1–T4.6 não tem revisão de segurança documentada, e o D19 do
  `../decisions.md` veio do gate de uma fase anterior.
- [ ] **Fase 5** — Bateria automatizada + fechamento · PR 5
