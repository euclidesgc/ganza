# 007 - Agenda e Google Calendar · Plano

O contrato é [`01_prd.md`](01_prd.md), a especificação é [`02_specs.md`](02_specs.md), as decisões são [`decisions.md`](decisions.md), e desvios futuros entram em [`changes.md`](changes.md). Estado: **Fase 2 em fechamento** · branch `feature/GZ-62-fase2-oauth-calendar` · a Fase 1 foi mergeada em `develop` pelo PR #56 e as três tarefas da Fase 2 estão em `DoD: CUMPRIDO` · **próximo passo: corrigir o bloqueante de código apontado pelo crítico integrador, executar o DoD da Fase 2 pela `fechar-etapa` e abrir o PR 2**.

## Gauntlet

**Referência:** [`01_prd.md`](01_prd.md), [`02_specs.md`](02_specs.md), [`decisions.md`](decisions.md), [`changes.md`](changes.md), `CLAUDE.md`, `docs/plano.md` §6.10 e [`../decisions.md`](../decisions.md).

**Rubrica binária:** cada fase só passa com todas as tarefas em `DoD: CUMPRIDO`, QA/CISO/crítico integrador em `pass`, DoD da fase executado e cancela de máquina verde. Nota, maioria e impressão subjetiva não aprovam.

**Invariantes bloqueantes:** Google é fonte única, sem tabela/cache/sync de eventos; leitura percorre todos os calendários no horizonte -90/+365 dias; escrita só após confirmação e no alvo concreto; Flutter não chama Google nem vê segredo; refresh fica no Vault e PKCE fica nele somente até consumo ou purge físico; tabela nova tem RLS e policy. Fluxo iniciado pela pessoa porta JWT e deriva relações por `auth.uid()`, sem `p_user_id` interativo nem CRUD direto de `service_role`; callback público recebe somente state e resolve o dono por ele.

**Provas:** auditor executa o bloco antes do despacho e supervisor o julga cego ao plano depois; QA, CISO e crítico revisam a fase. Teste só vale se passa e falha sem a mudança; comando de prova é somente leitura, literal e reproduzível.

**Limites:** máximo de 3 rodadas e 45 minutos por fase; duas devoluções `NÃO CUMPRIDO` por tarefa, terceira escala ao humano; `DOD INVÁLIDO` retorna ao tech-lead. Desvio é registrado antes em `changes.md`.

**Evidência E2E:** não há Patrol/e2e novo, conforme D34 em `docs/decisions.md`; widget prova comportamento visível. OAuth real aguarda configuração Google externa e não será declarado provado antes dela.

## Âncoras e contrato

- `supabase/migrations/0010_criar_messages_e_proposed_actions.sql` tem RLS/confirmação, mas não kinds Calendar, vínculo OAuth ou state.
- `supabase/functions/proposals/handler.ts` e `_shared/ai/proposal_writer.ts` são modelo de proposta/JWT; não podem chamar Google.
- `supabase/functions/main/index.ts` e `main/env.ts` exigem handler autenticado e allowlist de env por função.
- `supabase/migrations/0008_criar_ponte_de_vault_das_credenciais_de_ia.sql` é o modelo Vault/RPC/limpeza.
- `app/lib/modules/chat_module/` e `app/lib/app_router.dart` são o gabarito para `calendar_module`, hoje inexistente.

`POST /calendar/authorize` sob JWT faz purge de states vencidos, cria state único/PKCE com dono derivado por `auth.uid()` e devolve URL OAuth; `GET /calendar/callback` é público só para o Google, aceita somente state como capacidade de identidade e o consome removendo state/PKCE. `GET /calendar/connection`, `GET /calendar/events` e `POST /calendar/proposals` exigem JWT. A leitura consulta Google diretamente; criar usa `primary`; remarcação usa `calendarId + eventId` imutáveis e recusa recorrência/ambiguidade. O contrato completo está em `02_specs.md`.

## Ritual de fechamento de fase

1. Supervisor julga toda tarefa; só `DoD: CUMPRIDO` autoriza marcar `[x]`.
2. QA roda `revisar-fase`, CISO revisa o diff e crítico integrador revisa a consolidação; `fechar-etapa` executa o DoD da fase.
3. Consolidação roda `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test -r compact`, `deno fmt --check`, `deno lint`, `deno task check`, `deno task test` e os scripts de gate.
4. Cada fase abre um único PR para `develop`, com CI verde; PR 1 contém exclusivamente a migration.

## Fases

### Fase 1 — Schema seguro · PR 1

Dono: `especialista-backend`.

#### Ondas de execução

1. T1.1 é sequencial: estabelece o schema de todos os endpoints posteriores.

- [x] **T1.1** — Criar `supabase/migrations/0017_criar_vinculo_google_calendar.sql` com vínculo, state OAuth, Vault, consumo/purge físico de PKCE, fronteira JWT/RLS e tipos Calendar em propostas. · camada **migration** · `especialista-backend` · **DoD: DOD INVÁLIDO** em 2026-08-27 — não reprova a tarefa nem consome cota de `NÃO CUMPRIDO`; sete comandos `rg -P` casavam através de linhas sem `-U` e davam falso negativo (com mais um `$f` sem escape no bullet do CI, que abortava o comando em `set -u`), o bloco não exigia o agendamento `cron.schedule` que o CHG-001 prometeu e os dois critérios de teste não nomeavam arquivo nem comando de prova; o bloco ainda tinha sete linhas, acima do limite de três a seis. Bloco corrigido sem afrouxar exigência, conforme CHG-002 em `changes.md`. Segundo `DOD INVÁLIDO` em 2026-08-27, também sem consumir cota: os quatro comandos `rtk run` apontavam para caminho absoluto do `$HOME` do desenvolvedor em vez de caminho a partir da raiz do repositório, e abortavam com exit 2 em qualquer outro checkout ou no runner de CI; corrigidos para caminho relativo à raiz, a convenção que T2.1 em diante já seguia. Auditor: `DESPACHÁVEL`. Supervisor cego: **DoD: CUMPRIDO** em 2026-08-27 — seis linhas executadas, as quatro `rtk run` em exit 0 e as duas de banco pelo ciclo completo em Postgres descartável, com as asserções falsificadas uma a uma (RLS desligada, `GRANT` de tabela inteira, `cron.unschedule`) para provar que nenhuma passa vacuamente.
  - `rtk run 'set -eu; rg -n -U -P "(?s)create table public\\.google_calendar_connections\\s*\\(.*?\\buser_id\\s+uuid\\s+not null.*?\\);" supabase/migrations/0017_criar_vinculo_google_calendar.sql; rg -n -U -P "(?s)create table public\\.google_oauth_authorizations\\s*\\(.*?\\buser_id\\s+uuid\\s+not null.*?\\);" supabase/migrations/0017_criar_vinculo_google_calendar.sql; rg -n -P "(?ms)^alter table public\\.google_calendar_connections enable row level security;[[:space:]]*$" supabase/migrations/0017_criar_vinculo_google_calendar.sql; rg -n -P "(?ms)^alter table public\\.google_oauth_authorizations enable row level security;[[:space:]]*$" supabase/migrations/0017_criar_vinculo_google_calendar.sql; rg -n -U -P "(?is)create policy\\s+[^;]+\\s+on\\s+public\\.google_calendar_connections\\b[^;]*(?:using|with check)\\s*\\([^;]*\\bauth\\.uid\\(\\)[^;]*\\buser_id\\b[^;]*\\)" supabase/migrations/0017_criar_vinculo_google_calendar.sql; rg -n -U -P "(?is)create policy\\s+[^;]+\\s+on\\s+public\\.google_oauth_authorizations\\b[^;]*(?:using|with check)\\s*\\([^;]*\\bauth\\.uid\\(\\)[^;]*\\buser_id\\b[^;]*\\)" supabase/migrations/0017_criar_vinculo_google_calendar.sql'` exige, separadamente e sem alternativa que aceite só uma delas, os dois DDLs nomeados com `user_id uuid not null`, `enable row level security` em ambas as tabelas e uma policy multiline por tabela referenciando `auth.uid()` e `user_id` na cláusula de acesso.
  - `rtk run 'set -eu; rg -n -P "\\brefresh_secret_ref\\b" supabase/migrations/0017_criar_vinculo_google_calendar.sql; rg -n -P "\\bpkce_secret_ref\\b" supabase/migrations/0017_criar_vinculo_google_calendar.sql; rg -n -P "\\bvault\\.secrets\\b" supabase/migrations/0017_criar_vinculo_google_calendar.sql; ! rg -n -i -P "\\b(?:refresh_token|access_token|id_token|pkce_verifier|code_verifier)\\b\\s+(?:text|varchar(?:\\s*\\(\\s*\\d+\\s*\\))?|character varying|jsonb|bytea)\\b" supabase/migrations/0017_criar_vinculo_google_calendar.sql; ! rg -n -P "\\bconsumed_at\\b" supabase/migrations/0017_criar_vinculo_google_calendar.sql'` exige separadamente ambas as referências e o uso de `vault.secrets`, e falha se token/verificador PKCE for coluna de conteúdo em claro ou se marca de consumo substituir a remoção física.
  - O teste em banco descartável `supabase/tests/0017_vinculo_google_calendar.sql`, rodado pelo passo novo do job `migrations` de `.github/workflows/ci.yml` logo após "Aplicar migrations em ordem" com `docker exec -i pg psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -q < supabase/tests/0017_vinculo_google_calendar.sql`, aborta por `raise exception` se consumir state válido não remover a linha e o segredo PKCE do Vault, se o purge de state vencido não fizer a mesma limpeza, se iniciar OAuth não executar o purge antes de inserir novo state, ou se `supabase/migrations/0017_criar_vinculo_google_calendar.sql` não agendar a rotina de purge por `cron.schedule`, com o job correspondente presente em `cron.job`.
  - O mesmo `supabase/tests/0017_vinculo_google_calendar.sql`, rodado pelo mesmo `docker exec -i pg psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -q`, aborta por `raise exception` se um JWT gravar ou consultar relação de outro usuário, se `user_id` não for derivado de `auth.uid()` dentro do banco, se existir RPC interativa que aceite `p_user_id`, se `service_role` tiver `SELECT`, `INSERT`, `UPDATE` ou `DELETE` direto em `public.google_calendar_connections` ou `public.google_oauth_authorizations`, ou se a ponte pública do callback aceitar qualquer entrada além do state.
  - `rtk run 'set -eu; rg -n -P "\\bcreate_calendar_event\\b" supabase/migrations/0017_criar_vinculo_google_calendar.sql; rg -n -P "\\breschedule_calendar_event\\b" supabase/migrations/0017_criar_vinculo_google_calendar.sql; ! rg -n -i -P "\\bcalendar_events\\b" supabase/migrations/0017_criar_vinculo_google_calendar.sql'` exige os dois novos kinds, separadamente, e a ausência de entidade de eventos.
  - `rtk run 'set -eu; rg -n -P "(?m)^  migrations:\\s*$" .github/workflows/ci.yml; rg -n -U -P "(?ms)^  migrations:\\s*$.*?^      - name: Subir o Postgres do Supabase\\s*$.*?^        run: \\|\\s*$" .github/workflows/ci.yml; rg -n -U -P "(?ms)^  migrations:\\s*$.*?^      - name: Bootstrap do schema auth \\(só CI\\)\\s*$.*?^        run: docker exec -i pg psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -q < supabase/ci-bootstrap\\.sql\\s*$" .github/workflows/ci.yml; rg -n -U -P "(?ms)^  migrations:\\s*$.*?^      - name: Aplicar migrations em ordem\\s*$.*?^        run: \\|\\s*$.*?^          files=\\(supabase/migrations/\\*\\.sql\\)\\s*$.*?^          for f in \\\"\\$\\{files\\[@\\]\\}\\\"; do\\s*$.*?^            docker exec -i pg psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -q < \\\"\\\$f\\\"\\s*$" .github/workflows/ci.yml'` exige no job `migrations` o Postgres, o bootstrap com `ON_ERROR_STOP` e o loop ancorado que aplica cada migration com `ON_ERROR_STOP`; é a prova não mutante da régua de aplicação.

**DoD da fase:** CI prova migration limpa; RLS isola ambas as tabelas e JWT não escolhe dono; callback state-only consome/purge fisicamente PKCE; segredos são referências Vault; não há CRUD direto `service_role` nem RPC interativa `p_user_id`; o PR não contém app/backend.

### Fase 2 — OAuth, leitura e confirmação backend · PR 2

Dono: `especialista-backend`.

#### Ondas de execução

1. T2.1 e T2.2 são paralelas: adaptadores/testes disjuntos. 2. T2.3 integra ambos no handler.

- [x] **T2.1** `[paralela · frente OAuth · worktree]` — Criar `supabase/functions/calendar/google_oauth.ts`, `calendar_credentials.ts` e testes. · camada **backend** · `especialista-backend` · **DoD: CUMPRIDO** em 2026-08-29, rejulgado após a FD-009 acrescentar o segundo escopo; o supervisor refez cada falsificação por conta própria. · **Auditoria de critério: `DEVOLVER AO TECH-LEAD`** em 2026-08-29 — as quatro linhas voltaram: a primeira rodava `deno test` a partir da raiz, onde nenhuma implementação passa (`Relative import path "@std/assert" not prefixed`, exit `1`); a segunda se amarrava a "o teste" dela; a terceira dizia "o stub prova que" sem comando, arquivo ou nome de caso, e cobrava exigências fora dos cenários da primeira; a quarta era verde por construção, porque `rg` sobre `supabase/functions/calendar` sai hoje com stdout vazio e exit `2` por a pasta não existir. Bloco reescrito sem afrouxar exigência: cada condição da FD-007 vira nome de RPC da migration `0017` escrito por extenso, com prova nomeada.
  - `cd supabase/functions && deno test --allow-env --allow-net calendar/google_oauth_test.ts calendar/calendar_credentials_test.ts` termina com código `0`, cobrindo consentimento com `state`, PKCE challenge, `access_type=offline`, `prompt=consent` e, na URL de autorização, os dois escopos `https://www.googleapis.com/auth/calendar.events` e `https://www.googleapis.com/auth/calendar.calendarlist.readonly`, state de uso único, consumo, expiração/purge e refresh recusado. O caso de consentimento falha se qualquer um dos dois escopos faltar na URL, porque `calendar.events` sozinho não autoriza `calendarList.list` (procedência: FD-009 de `docs/007_agenda/decisions.md`).
  - Os casos de `supabase/functions/calendar/google_oauth_test.ts` falham se state já consumido ou vencido ainda cria vínculo e se, depois de obter o verificador por `google_oauth_authorization_prepare_callback`, o fluxo terminar sem chamar `google_oauth_authorization_complete_callback` no sucesso ou `google_oauth_authorization_discard_callback` na negação/erro, deixando a autorização e o segredo PKCE vivos no Vault; os de `supabase/functions/calendar/calendar_credentials_test.ts` falham se refresh recusado pelo Google não produzir o resultado tipado `reconnect_required` ou se o valor do refresh token aparecer na resposta do adaptador.
  - O fluxo iniciado pela pessoa usa o cliente Supabase construído com o `Authorization` da requisição e chama a RPC `google_oauth_authorization_start`, que em `supabase/migrations/0017_criar_vinculo_google_calendar.sql` não tem parâmetro de dono e deriva `user_id` de `auth.uid()` dentro do banco; a ponte do callback resolve o dono só pelo hash do state. `cd supabase/functions && deno test --allow-env --allow-net calendar/google_oauth_test.ts --filter identidade` termina com código `0`, imprime `0 failed` e contagem de `passed` maior que zero, e esses casos, sobre um stub que registra cada `rpc(nome, args)` e `from(tabela)`, falham se houver acesso direto às tabelas `google_oauth_authorizations` ou `google_calendar_connections`, se qualquer chamada levar `user_id`/`p_user_id`, se o fluxo interativo usar chave `service_role` em vez do JWT recebido, ou se o `user_id` aparecer na resposta do callback (procedência: FD-007 de `docs/007_agenda/decisions.md`).
  - `cd supabase/functions && rg -n 'google_oauth_authorization_start' calendar/google_oauth.ts && rg -n 'google_calendar_connection_secret_reveal' calendar/calendar_credentials.ts && ! rg -n -i 'console\.(log|error|warn|info).*(token|secret|verifier)' calendar/google_oauth.ts calendar/calendar_credentials.ts` termina com código `0`: os dois `rg` positivos ancoram que os arquivos existem e nomeiam as RPCs pelas quais o segredo trafega, e só então a negativa vale — hoje o comando termina com `2` (`No such file or directory`), e é essa ancoragem que separa "rodou e não achou" de "caminho inexistente".

- [x] **T2.2** `[paralela · frente Google · worktree]` — Criar `supabase/functions/calendar/google_calendar.ts`, `calendar_proposals.ts` e testes de listagem/idempotência. · camada **backend** · `especialista-backend` · **DoD: CUMPRIDO** em 2026-08-29, com o supervisor refazendo por conta própria a falsificação de cada invariante. · **Auditoria de critério: `DEVOLVER AO TECH-LEAD`** em 2026-08-29 — a terceira linha citava `ganza_proposal_id` sem dizer onde o vínculo é gravado nem por qual prova, e o supervisor é cego ao plano; a primeira rodava `deno test` a partir da raiz, onde nenhuma implementação correta passa (`Relative import path "@std/assert" not prefixed`, exit `1`, medido em 2026-08-29 com `supabase/functions/proposals/handler_test.ts`). Bloco reescrito sem afrouxar exigência: o vínculo continua sendo o do §6 de `02_specs.md` e da FD-006, agora escrito por extenso.
  - `cd supabase/functions && deno test --allow-env --allow-net calendar/google_calendar_test.ts calendar/calendar_proposals_test.ts` termina com código `0`, cobrindo dois calendários, paginação, dia inteiro, retry e recusa de recorrência. Hoje termina com `1` e `error: No such file or directory`, porque `supabase/functions/calendar/` ainda não existe.
  - O teste falha se a leitura consulta só `primary`, confirmação duplica evento ou Cancelar faz fetch Google.
  - Confirmar uma proposta de criação envia ao Google um evento cujo `extendedProperties.private.ganza_proposal_id` é o id da proposta em `public.proposed_actions` e, antes do POST, lista o calendário alvo filtrando por essa mesma propriedade privada — o vínculo mora só no evento remoto, sem coluna nova em nenhuma tabela. `cd supabase/functions && deno test --allow-env --allow-net calendar/calendar_proposals_test.ts --filter ganza_proposal_id` termina com código `0`, imprime `0 failed` e contagem de `passed` maior que zero, e esses casos inspecionam as requisições capturadas pelo `fetch` stubado: falham se a chave não for enviada, se o valor divergir do id da proposta, ou se a listagem prévia não filtrar por essa propriedade (procedência: §6 de `docs/007_agenda/02_specs.md` e FD-006 de `docs/007_agenda/decisions.md`).
  - Confirmar uma remarcação faz `PATCH` apenas no par `calendar_id` + `event_id` copiado da proposta e relê o evento antes de alterar: `cd supabase/functions && deno test --allow-env --allow-net calendar/calendar_proposals_test.ts --filter remarc` termina com código `0`, imprime `0 failed` e contagem de `passed` maior que zero, e esses casos falham se sair qualquer `PATCH` quando a releitura devolve `404` (resposta esperada `event_not_found`), quando `start`/`end` vindos do Google divergem do `original_start`/`original_end` da proposta (resposta esperada `event_ambiguous`) ou quando o evento traz `recurringEventId` (resposta esperada `recurring_event_unsupported`).

- [x] **T2.3** — Criar `supabase/functions/calendar/handler.ts`, `index.ts`, `handler_test.ts` e allowlist em `supabase/functions/main/env.ts`/`index.ts`. · camada **backend** · `especialista-backend` · **DoD: CUMPRIDO** em 2026-08-29; o supervisor refez as duas falsificações e ainda plantou erro de tipo para provar que o `-q` do `deno check` não cega o gate do CI.
  - `cd supabase/functions && deno test --allow-env --allow-net calendar/handler_test.ts` termina com código `0`, cobrindo authorize, callback válido e inválido, connection, events, proposals e o caso em que a renovação recusada pelo Google faz `GET /calendar/connection` responder `reconnect_required` derivado na própria leitura, sem que o stub do cliente Supabase registre escrita alguma em `public.google_calendar_connections` (procedência: FD-008 de `docs/007_agenda/decisions.md`). Hoje termina com `1` e `error: No such file or directory`, porque `supabase/functions/calendar/` ainda não existe.
  - O teste falha se Calendar é público no roteador ou callback aceita state inexistente.
  - `cd supabase/functions && deno fmt --check && deno lint && deno task check && deno task test` termina com código `0`.

**DoD da fase:** OAuth server-side usa state/PKCE/offline e pede na URL de consentimento os escopos `calendar.events` e `calendar.calendarlist.readonly`; callback só vincula state válido e o consome com remoção física de PKCE; JWT/RLS é a fronteira de todo fluxo iniciado pela pessoa e callback é state-only; consulta todos os calendários sem cache; proposta confirmada é a única escrita e é idempotente.

### Fase 3 — Agenda e cards no Flutter · PR 3

Dono: `especialista-dominio`, `especialista-dados`, `especialista-apresentacao` e `especialista-infra`.

#### Ondas de execução

1. T3.1 fecha domínio. 2. T3.2 e T3.3 são paralelas, em data/presentation. 3. T3.4 e T3.5 dependem do contrato e integram rota/chat.

- [ ] **T3.1** — Criar entidades, repositório e use cases em `app/lib/modules/calendar_module/domain/`. · camada **domain** · `especialista-dominio`
  - `cd app && flutter test test/modules/calendar_module/domain -r compact` termina com código `0`, cobrindo evento com hora, dia inteiro e estados de conexão. Hoje termina com `1`, porque `app/test/modules/calendar_module/domain/` ainda não existe.
  - O teste falha se domínio aceita data relativa, token ou recorrência como alvo de remarcação.
  - `rg -n 'package:flutter|Map<' app/lib/modules/calendar_module/domain` não imprime ocorrências.

- [ ] **T3.2** `[paralela · frente data · worktree]` — Criar models zard e `CalendarRepositoryImpl` em `app/lib/modules/calendar_module/data/`. · camada **data** · `especialista-dados`
  - `cd app && flutter test test/modules/calendar_module/data -r compact` termina com código `0`, cobrindo resposta normalizada, reconexão e payload inválido. Hoje termina com `1`, porque `app/test/modules/calendar_module/data/` ainda não existe.
  - O teste falha se model aceita `secret_ref`/token ou timestamp sem validação UTC.
  - `rg -n 'try \{' app/lib/modules/calendar_module` mostra tratamento de exceção apenas em `data/`.

- [ ] **T3.3** `[paralela · frente UI · worktree]` — Criar Cubit, página e widgets em `app/lib/modules/calendar_module/presentation/`. · camada **presentation** · `especialista-apresentacao`
  - `cd app && flutter test test/modules/calendar_module/presentation -r compact` termina com código `0`, cobrindo conectado, reconectar, lista, dia inteiro e data/hora explícitas. Hoje termina com `1`, porque `app/test/modules/calendar_module/presentation/` ainda não existe.
  - O teste falha se UI mostra hora artificial em dia inteiro ou usa cor como único sinal de reconexão.
  - `rg -n 'Widget _|Widget [a-zA-Z_]+\(' app/lib/modules/calendar_module/presentation` não imprime helper que retorna Widget.

- [ ] **T3.4** — Registrar rota, barrel e DI em `app/lib/modules/calendar_module/` e `app/lib/app_router.dart`. · camada **infra** · `especialista-infra`
  - `cd app && flutter test test/app_router_test.dart --plain-name 'agenda autenticada' -r compact` termina com código `0`: o caso novo, cujo nome contém `agenda autenticada`, mora em `app/test/app_router_test.dart` e navega até a Agenda com sessão válida. Hoje termina com `79` (`No tests ran.`) — o arquivo já existe e já passa inteiro, então rodá-lo sem o filtro seria verde por construção.
  - O teste falha se `CalendarRoutes` não está registrado ou rota chama cliente Google fora do Supabase.
  - `cd app && flutter analyze` termina com código `0`.

- [ ] **T3.5** — Adaptar `app/lib/modules/chat_module/` para card Calendar com confirmar/cancelar e dados explícitos. · camada **presentation** · `especialista-apresentacao`
  - `cd app && flutter test test/modules/chat_module/presentation/chat --plain-name 'card Calendar' -r compact` termina com código `0`: o caso novo, cujo nome contém `card Calendar`, mostra título, calendário e antes/depois com Confirmar e Cancelar. Hoje termina com `79` (`No tests ran.`) — `app/test/modules/chat_module/presentation/chat/` já existe e já passa, então rodá-lo sem o filtro seria verde por construção.
  - O teste falha se Cancelar chama escrita ou Confirmar aceita proposta recorrente ou ambígua.
  - `rg -n 'googleapis|google\.com|refresh_token|client_secret' app/lib` não imprime ocorrências.

**DoD da fase:** pessoa inicia OAuth só por URL backend, vê agenda/estado de reconexão e o chat não cria/remarca fora da confirmação explícita.

### Fase 4 — Bateria, docs e fechamento · PR 4

Dono: `qa`; inicia somente após gate geral CISO sobre o código consolidado.

#### Ondas de execução

1. T4.1–T4.3 são paralelas, com arquivos disjuntos. 2. T4.4 consolida gates e recebe QA/CISO/crítico finais.

- [ ] **T4.1** `[paralela · frente backend · worktree]` — Completar bateria Calendar em `supabase/functions/calendar/*_test.ts`. · camada **testes** · `qa`
  - `cd supabase/functions && deno task test` termina com código `0` incluindo Calendar.
  - A bateria falha ao remover state validation, idempotência de proposta ou recusa de recorrência.
  - Stubs provam que token/segredo não entra em resposta nem log.

- [ ] **T4.2** `[paralela · frente app · worktree]` — Completar unit/widget em `app/test/modules/calendar_module/` e `app/test/modules/chat_module/`. · camada **testes** · `qa`
  - `cd app && flutter test test/modules/calendar_module test/modules/chat_module -r compact` termina com código `0`.
  - A bateria falha ao ocultar data/fuso, confirmar sem card ou tratar reconnect como agenda atual.
  - Widget prova texto e controle acessível, não só cor, para conexão, dia inteiro e recorrência recusada.

- [ ] **T4.3** `[paralela · frente docs · worktree]` — Criar `docs/007_agenda/final_report.md` e atualizar docs de feature e raiz no estado real. · camada **docs** · `qa`
  - `final_report.md` relaciona cada caso entregue aos testes unitários, widget e backend que o provam.
  - A releitura de docs/007, `README.md`, `CHANGELOG.md`, `ANALYTICS.md`, `ERROR_LOGS.md` e `docs/roadmap.md` não deixa frase vizinha falsa nem promete cache, webhook, recorrência editável ou OAuth cliente.
  - Todo comando novo documentado é executado copiado e colado com código `0`, e `bash scripts/verify-gauntlet.sh` imprime `✓ gauntlet: roadmap, documentos e contratos canônicos íntegros`.

- [ ] **T4.4** — Consolidar, executar gates e registrar vereditos sem criar E2E novo. · camada **testes** · `qa`
  - `cd app && dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test -r compact` termina com código `0`.
  - `cd supabase/functions && deno fmt --check && deno lint && deno task check && deno task test` termina com código `0`.
  - `bash scripts/gates_guard.sh && bash scripts/validar-workflows.sh && bash scripts/verify-gauntlet.sh` termina com código `0`.

**DoD da fase:** CISO pré-bateria e final pós-docs passam; frentes têm `CUMPRIDO`; testes unit/widget/backend provam caminhos e falhas; docs dizem a verdade; não há E2E novo.

## Rastreabilidade e riscos

| DoD do PRD | Fases donas |
|---|---|
| Todos calendários e alteração externa na próxima leitura | 2, 3, 4 |
| Criar no primário após confirmação e card explícito | 1, 2, 3, 4 |
| Remarcar único; recorrente/ambíguo/removido sem mutação | 1, 2, 3, 4 |
| Segredos fora do app/log/API; vínculo RLS/Vault | 1, 2, 4 |
| Cobertura unit/widget e gauntlet | 3, 4 |

Projeto Google Cloud, consent screen, redirect HTTPS e conta de teste bloqueiam só a prova real contra Google, não a preparação/código/testes com stub. Modo Testing pode expirar refresh em sete dias e deve resultar em `reconnect_required`. Múltiplas contas, seleção de calendário, disponibilidade, convidados, webhook e sync estão fora do escopo.

## Progresso

| Fase | PR | Estado | Próximo gate |
|---|---|---|---|
| 1 | PR #56 | mergeada em `develop`; T1.1 `CUMPRIDO` | encerrada |
| 2 | PR 2 | T2.1, T2.2 e T2.3 `CUMPRIDO`; crítico integrador devolveu `fail` com bloqueante de código em correção | `fechar-etapa` com o DoD da fase e PR 2 |
| 3 | PR 3 | não iniciada; libera com o merge do PR 2 | auditor em T3.1 |
| 4 | PR 4 | não iniciada | CISO geral antes de T4.1–T4.3 |
