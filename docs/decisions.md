# Decisões - Ganzá

Registro de decisões técnicas e pendências humanas. O backlog curto e o estado
das features vivem em [`docs/roadmap.md`](roadmap.md).

## Decisões travadas

| # | Decisão | Data | Onde |
|---|---|---|---|
| ~~D1~~ | ~~**Backend próprio em NestJS; Supabase reduzido a Postgres + Auth + PostgREST + Storage + pg_cron.** Sem Edge Functions/Deno. Motivo: o deploy de função no Supabase self-hosted é por volume montado, e é justamente ali que mora o código que mais muda (ingest, prompts, cálculo). Com NestJS, publicar lógica volta a ser merge em branch.**~~ **Revogada pela D10** — o atrito de deploy provou-se resolvível em ~40 linhas, e manter dois sistemas num projeto solo custava mais. | 2026-08-16 | `CLAUDE.md` |
| D2 | **Sem melos e sem packages.** Um app só, módulos em `app/lib/modules/`. Extrair para pacote quando existir um segundo consumidor de verdade. | 2026-08-16 | `CLAUDE.md` |
| D3 | **A validação E2E é local, em uma stack Supabase descartável via Docker Compose.** O remoto atual é homologação (HML), alimentada por `develop`; E2E não escreve nela. | 2026-08-17 | `docs/GITFLOW.md` §4 |
| D4 | **Backup não é escopo.** Decisão do humano. **Sobrepõe o R9 e o §5.1 do `docs/plano.md`**, que pediam `pg_dump` agendado desde a Fase 0. Não propor rotina de backup, não tratar como item de DoD, não reabrir o assunto — se um dia mudar, é o humano quem traz. | 2026-08-16 | `CLAUDE.md` |
| D5 | **Repositório `euclidesgc/ganza`, privado, `develop` como branch padrão.** Proteção de branch do GitHub não está disponível no plano gratuito para repo privado — a cancela é o hook `pre-push` em `scripts/git-hooks/`. | 2026-08-16 | `docs/GITFLOW.md` §1 |
| D7 | **O remoto atual é HML e é alimentado por `develop`; `main` fica reservado para a produção futura.** O gate completo permanece local antes do PR e não há smoke remoto obrigatório após merge. | 2026-08-17 | `docs/GITFLOW.md` §4 |
| D11 | **Conta única, cadastro fechado.** `ENABLE_EMAIL_AUTOCONFIRM` para criar a conta sem SMTP, e `DISABLE_SIGNUP` logo depois. O app é monousuário por desenho (não-objetivo do plano) — deixar o cadastro aberto num endpoint público seria convite sem porteiro. Verificado: `422 signup_disabled`. | 2026-08-16 | `docs/deploy/coolify.md` |
| D10 | **A lógica de servidor são Edge Functions, não um backend separado** (revoga a D1). O `edge-runtime` voltou à stack. Motivo: um sistema em vez de dois num projeto solo, e **RLS aplicada nativamente** com o JWT do usuário — menos código de segurança escrito à mão num app que guarda extrato bancário. O atrito que motivou a D1 (deploy por volume, sem `supabase functions deploy`) virou `scripts/deploy-functions.sh`, ~40 linhas. Decidido com o backend ainda em ~150 linhas; depois da Fase 1 custaria dias. **O servidor continua necessário pelas chaves de terceiro** — o que mudou foi onde ele mora. | 2026-08-16 | `docs/deploy/coolify.md` |
| D8 | **Build seletivo no monorepo.** CI com `paths-filter` e Coolify com `watch_paths` por deployável. Mexer no app não rebuilda o backend — 2 vCPU compartilhados com outros dois projetos. | 2026-08-16 | `CLAUDE.md` |
| D12 | **O stand-in de `auth.uid()` do CI lê a forma real do GoTrue** — `request.jwt.claims ->> 'sub'` (JSON) —, com fallback para a chave escalar antiga (`request.jwt.claim.sub`) e devolvendo NULL, sem lançar, em JSON malformado. Ele lia **só** a chave escalar, que o GoTrue não usa: toda prova de RLS no CI validava uma função que não existe em produção, e uma prova escrita na forma real teria "passado" pelo motivo errado — com `auth.uid()` NULL a política de dono rejeita o próprio dono, e a negação parece a prova. Corrigido de raiz em vez de remendar o texto do DoD: o custo era o mesmo, e o remendo deixaria a armadilha de pé para a próxima migration. **Pendência conhecida:** o stand-in não expõe `auth.role()`; migration que cheque `auth.role() = 'authenticated'` esbarra no CI numa função inexistente e falha pelo motivo errado — quem escrever a primeira delas amplia o bootstrap junto. | 2026-08-16 | `supabase/ci-bootstrap.sql` |
| D6 | **Domínio sob `bmjtech.duckdns.org`: `supabase.ganza.` (Supabase, no ar), `ganza.` (app) e `api.ganza.` (backend).** O `ganza.duckdns.org` já pertence a outra pessoa (`95.99.103.11`), e registrar um DuckDNS novo exige a conta do humano. O wildcard do `bmjtech` resolve em qualquer profundidade — verificado por `dig` —, então isto funciona sem interação. **Trocar depois é barato:** `PATCH /api/v1/applications/{uuid}` com `domains` + rebuild do front (a URL da API é compile-time). Nomes livres no DuckDNS, se um dia quiser: `ganzaapp`, `meuganza`, `ganza-app`, `appganza`, `ganzabr`. | 2026-08-16 | `.claude/skills/subir-supabase/SKILL.md` |
| D13 | **`transactions.area_id` existe (nulável, FK para `areas`), mas o formulário não pede a área — e `area_id` não entra no payload da Edge Function.** Dinheiro não se compartimenta por área (`docs/plano.md` §6.3); obrigar a escolher entre as quatro áreas padrão para registrar um almoço pede uma decisão que o produto não quer. A coluna já nasce na `0004` para o chat preenchê-la depois sem migration nova. **Dívida conhecida: FK não respeita RLS** — nada no banco impede apontar a transação para uma área alheia. Hoje não vaza (a leitura de `transactions` segue filtrada por `user_id` e o join esbarraria na RLS de `areas`) e está mitigado porque o campo fica fora do payload. Quando o chat passar a preencher `area_id`, **quem escreve valida a posse explicitamente** — o Postgres sozinho não barra. | 2026-08-16 | `docs/001_cadastro_manual/03_plan.md` §1 (A1) |
| D14 | **A feature 001 não exclui transação.** Correção e exclusão são a futura feature de finanças. A limpeza do E2E é feita pela stack local descartável. A política `transactions_owner` é `for all` e já cobriria o `delete` — a ausência é de UI, não de banco. | 2026-08-17 | `docs/001_cadastro_manual/03_plan.md` §1 (A2) |
| D15 | **As fontes Fraunces e IBM Plex Sans entram na feature 001** (tarefa T3.2), não numa tarefa de tema à parte. É o que fecha honestamente a linha "algarismos tabulares" do DoD: sem os `.ttf`, o fallback do sistema não garante figuras tabulares e a coluna de valores dança entre linhas. | 2026-08-16 | `docs/001_cadastro_manual/03_plan.md` §1 (A3) |
| D16 | **Migration chega à produção por `scripts/apply-migrations.sh`, e o script recusa rodar sem alvo explícito.** Não havia caminho nenhum: o CI só provava que as migrations aplicam num Postgres descartável, e o Coolify não roda migration. O script controla o aplicado em `supabase_migrations.schema_migrations`, descobre pendentes lendo o diretório, tem `--baseline` para registrar sem reexecutar o que foi aplicado à mão, e usa uma transação por arquivo. **A recusa por omissão foi escrita depois de o próprio agente que o criou disparar um `--status` contra a produção por um `export` esquecido** (só leitura, sem escrita) — o alvo virou flag (`--local`/`--prod`, visível no histórico do shell) em vez de variável de ambiente, e `--prod --apply` exige a palavra `APLICAR` digitada. **Ressalva conhecida:** `--baseline` também escreve em produção e ficou fora da confirmação; é de uso único e o dano seria uma linha a remover, não schema perdido. | 2026-08-16 | `scripts/apply-migrations.sh` |
| D17 | **Política de RLS chama `auth.<função>()` dentro de um `select`, e o CI cobra.** O advisor do Supabase acusou o lint *Auth RLS Initialization Plan* em `profiles` e `areas` — a função era reavaliada por linha em vez de uma vez por consulta; a `transactions_owner` tinha o mesmo padrão e só escapou do advisor porque a tabela ainda não existia no servidor. A `0005` recria as três com `(select auth.uid())` no `using` **e** no `with check`, e o `EXPLAIN` passou a mostrar `InitPlan`. O gate novo do job "Banco" descobre as funções do schema `auth` em `pg_proc` em vez de procurar o texto `auth.uid()`: **o Postgres normaliza a expressão removendo o prefixo do schema**, então um gate literal ficaria verde para sempre. Irrelevante com quatro linhas; decisivo quando o extrato bancário entrar na Fase 3. | 2026-08-16 | `supabase/migrations/0005_otimizar_politicas_rls.sql` |

| D18 | **O volume `deno-cache` do edge-runtime é aquecido antes do restart por `deploy-functions.sh` e pela stack local.** Um import npm novo já pôs o runtime em restart loop (`failed to bootstrap runtime: No such file or directory`) porque havia só metadados no cache. O aquecimento usa Deno `2.1.4`, mesma versão embutida no runtime, e o volume nomeado compartilhado. | 2026-08-17 | `scripts/deploy-functions.sh`, `scripts/local-supabase.sh` |
| D20 | **O E2E deixa de recompilar o APK por cena: a cena vira parâmetro de runtime, servido pelo servidor de captura que já existe.** Medido na rodada 02 da feature 001: 10 cenas em ~30 min, dos quais ~9 min são build (um por cena, porque `--dart-define` é compile-time e `String.fromEnvironment` é `const`), ~4 min são reinstalação do APK a cada `patrol test` e ~3 min são o emulador subindo duas vezes — `e2e_shots.sh` derruba o AVD e `e2e_registro_shots.sh` sobe outro. Metade da rodada não prova nada. O canal de configuração já existe e é bidirecional: `scripts/capture-e2e-evidence.py` é alcançado do device por `adb reverse` e já recebe os PNGs; o teste passa a pedir a cena e seus parâmetros por `GET` no `setUp`. Com um build só (`patrol build android` + `adb shell am instrument` por cena), emulador único entre os dois roteiros e quick boot do AVD — hoje o log diz `Not saving state: RAM not mapped as shared`, então são 85 s de boot toda vez — a projeção é **~30 min → 6–8 min sem perder nenhuma prova**. Não fazer durante coleta de evidência: três tentativas da rodada 02 se perderam por mexer no harness com a rodada em curso. | 2026-08-19 | `scripts/capture-e2e-evidence.py`, `docs/001_cadastro_manual/e2e_shots.sh`, `docs/001_cadastro_manual/e2e_registro_shots.sh`, `scripts/e2e-emulator.sh` |
| D19 | **A `service_role` é injetada no ambiente de todo worker, inclusive os que não precisam dela.** `main/index.ts` monta o `envVars` igual para qualquer função despachada; `transactions` usa só a anon key + o JWT do usuário (correto), mas a chave que fura RLS fica acessível no processo do mesmo jeito. Achado do gate do CISO na feature 001 — **padrão pré-existente, não nasceu naquele diff**, e por isso não bloqueou o PR. Reduzir o raio é escopar `envVars` por função, no mesmo estilo do `PUBLICAS`. Vale fazer antes de a primeira função agendada (com `service_role` legítima) coexistir com as de usuário. | 2026-08-16 | `supabase/functions/main/index.ts` |

## Decisões pendentes do humano

| # | Decisão | Bloqueia | Contexto |
|---|---|---|---|
| P1 | **Conta Google e projeto Firebase** para FCM e OAuth do Calendar. | F2 (push), F5 (agenda) | O OAuth em modo de teste expira o refresh token a cada 7 dias — publicar o app resolve. |
| P7 | **Resolver os incidentes do GitGuardian no dashboard.** | check verde no #5 (não bloqueia o merge) | Investigado a fundo: o commit atual tem **zero** literais de credencial, confirmado por duas ferramentas independentes (`gitleaks` → *no leaks found* e a varredura do nosso hook). Ainda assim o check marca — e o número **subiu de 3 para 4 sem nenhuma linha nova**, o que indica incidentes acumulados no lado do GG a cada versão do branch, não conteúdo do código. Os achados originais eram valores de **teste** (`nao-e-uma-senha`, `valor-de-teste`), nunca credencial real. Só o dashboard mostra o detalhe, e o acesso é seu: marque-os como resolvidos/ignorados. |
| P8 | **Role dedicado no Postgres para o backend** (`ganza_api`, permissão mínima), em vez de conectar como `postgres`. | nada hoje — o único uso da conexão `postgres` é o `select 1` do `health` | **A escrita da F0.9 não dispara isto**: a Edge Function de `transactions` grava com o **JWT do usuário** (role `authenticated`), pela RLS, e não pela conexão `postgres` (D10). O que dispara é a primeira escrita **sem usuário na frente** — job de `pg_cron`, ingestão do Pluggy, qualquer caminho que abra conexão própria em vez de repassar o JWT. É uma migration pequena; o adiamento é proporcional ao risco atual, não esquecimento. |
| P4 | **SMTP** — só necessário para recuperação de senha. | nada hoje | Resolvido para cadastro: `ENABLE_EMAIL_AUTOCONFIRM=true` e depois `DISABLE_SIGNUP=true`. A conta existe e a porta está fechada (`422 signup_disabled`, verificado). Perdeu a senha? Redefine pelo Studio. |
| P2 | **GitHub Pro (US$ 4/mês)?** Só ele libera proteção de branch e *required status checks* em repo privado. | nada hoje | O hook `pre-push` cobre o push direto. O que falta é a cancela que impede mergear com CI vermelha — hoje isso é disciplina. Alternativa sem custo: tornar o repo público. |

---

## Fase 0 — Fundação

O plano estima 3 semanas. Com a D1 (sem Edge Functions) a estimativa cai para ~2.

- [x] **F0.1 — Repositório e harness.** Estrutura, `CLAUDE.md`, 9 agentes, 13 skills, GitFlow, `.gitignore`, README, CHANGELOG, `gates_guard.sh`, `ci.yml`.
- [x] **F0.2 — GitHub + CI verde.** Repo privado, `main`/`develop`, `develop` como padrão, hook `pre-push` no lugar da proteção de branch (D5). O `ci.yml` **roda de verdade** desde o PR #4: format, analyze, gates e 20 testes no app; migrations aplicando num `supabase/postgres` limpo com gate de RLS e de política. O job do backend se pula sozinho até `backend/` existir.
- [x] **F0.3 — Supabase enxuto no Coolify.** Sete contêineres saudáveis (`db`, `kong`, `auth`, `rest`, `storage`, `meta`, `studio`), **~840 MB** — 8 dos 15 serviços do template cortados. Em **`https://supabase.ganza.bmjtech.duckdns.org`** com TLS Let's Encrypt; auth, rest e storage devolvem 200. Vizinhos (driva, love-secret, Garage) seguem `running:healthy`. Detalhes em `docs/deploy/coolify.md`. **Falta só** SMTP (**P4**).
- [x] **F0.4 — Primeira migration.** Extensões (`pgcrypto`, `pg_cron`, `pg_net`, `supabase_vault`), `profiles`, `areas` com RLS e política, e o trigger que cria perfil + 4 áreas padrão no signup. Aplicado no banco real e **provado**: anônimo lê `[]`, o dono lê as 4 áreas. CI passou a rodar contra a imagem `supabase/postgres` de produção e ganhou o gate de política, não só o de RLS.
- [x] **F0.5+F0.6 — App Flutter e design system.** Fundidos num PR só: o `gates_guard` proíbe estilo hardcoded desde o primeiro widget, então separar criaria um PR que viola o próprio gate. Entrega: `flutter create` (Android + Web), flavors com `applicationId` distinto, `bootstrap.dart` com as 4 redes de erro, go_router, get_it, `core/error` com `Failure` selada, tradutor único de exceção, `core/theme/` completo (paleta do plano §11, tipografia com algarismos tabulares, `GanzaColors` como `ThemeExtension`), tela inicial com a marca e a faixa de pulso. 14 testes, analyze limpo, gates verdes. **Pendente:** os arquivos de fonte (Fraunces e IBM Plex Sans) ainda não estão em `app/assets/fonts/` — hoje cai no fallback do sistema (**P5**).
- [x] **F0.7 — Auth + navegação.** `auth_module` completo (domain/data/presentation) sobre o GoTrue, guarda de rota reagindo ao stream de sessão, e `areas_module` listando as quatro áreas padrão — leitura direta por `supabase_flutter`, sem filtro de usuário na query, porque quem autoriza é a RLS. 18 testes.
- [x] **F0.8 — Lógica de servidor: esqueleto.** Edge Functions em Deno (D10): `main/index.ts` roteando `/functions/v1/<nome>`, `health` consultando o banco de verdade, publicação por `scripts/deploy-functions.sh`, CI com `deno fmt`/`lint`/`check`/`test`. Verificado no domínio: 200 no health, 404 em rota inexistente. *(Nasceu em NestJS e migrou; os três deploys falhos do caminho — DI, rede e binding IPv4-only — estão em `docs/deploy/coolify.md`.)*
- [-] **F0.9 — Cadastro manual ponta a ponta.** Histórico preservado da feature 001, cujo plano canônico está em **`docs/001_cadastro_manual/`** (`01_prd.md` · `02_specs.md` · `03_plan.md`).

  **DoD**
  - [x] `supabase/migrations/0004_criar_transactions.sql` aplica limpo no CI, com RLS e política — job "Banco" verde
  - [x] `deno task test` cobre a função de criação: valor não-inteiro e `direction` fora de `in|out` viram 400. Verificado que os testes **falham** sem a validação — seis mutações, seis quedas
  - [x] `curl -X POST https://supabase.ganza.bmjtech.duckdns.org/functions/v1/transactions` com o JWT da conta cria a linha e devolve 201; **sem** `Authorization` devolve 401 — e o corpo é o do nosso contrato, não o do Kong (X2)
  - [x] `GET /rest/v1/transactions` **anônimo** devolve `[]` e com a sessão do dono devolve a transação — a RLS provada pelo caminho real
  - [ ] `flutter test -r compact` verde, incluindo widget test do formulário e do estado vazio da lista
  - [ ] E2E no emulador: print da transação registrada aparecendo na lista, em `docs/001_cadastro_manual/e2e/round_01/`, atestado pelo dev
  - [ ] valor exibido usa algarismos tabulares e a data é explícita ("15/08, sexta"), conferido no print

## Fase 1 — Chat de texto

> DoD de cada item entra no `plan.md` da feature quando ela for planejada. Três linhas são **obrigatórias em toda etapa desta fase**, porque são as invariantes que o produto não pode perder: (a) um teste que prova que a ingestão **não grava** na tabela final, só em `proposed_actions`; (b) a extração devolvendo **lista**, verificada com uma mensagem que gera dois registros; (c) **a etapa que passar a preencher `transactions.area_id` prova que a posse da área é validada no código** — FK **não** respeita RLS (D13), então apontar para uma área de outra conta não é barrado pelo Postgres. A prova é uma tentativa com `area_id` alheio sendo recusada, não a inspeção do código.

- [ ] `/ingest` como Edge Function, camada de IA abstraída (`ai_providers`/`ai_routes`/`ai_usage`) com Gemini
- [ ] Classificação de intenção (`create` · `attach` · `query`, sendo as duas últimas "ainda não sei")
- [ ] Extração devolvendo **lista**, gravada em `proposed_actions`
- [ ] Cards de confirmação em sequência, não editáveis, com data explícita
- [ ] `category_hints` — correção do usuário vira lookup na próxima vez

## Fase 2 — Rotina (o primeiro momento em que o app é útil)

- [ ] Rotinas com os dois modos de recorrência (`calendar` · `interval_from_completion`)
- [ ] Geração de ocorrências, cinco estados terminais, log de eventos
- [ ] Adiar move a data da mesma ocorrência
- [ ] Lista de atrasadas; para de notificar em 3 dias e continua visível
- [ ] Boards com prazo opcional + kanban
- [ ] **Alertas em dupla via, provados com o app fechado** (risco R3)

## Fase 3 — Finanças

- [ ] Pluggy: conexão, primeira carga com histórico, categorização em lote agrupada
- [ ] Receita e despesa com `direction`; compromissos e ocorrências
- [ ] Parcelamento por chat e detectado na fatura (regex), sem duplicar
- [ ] Contrato de financiamento e simulação de quitação (prazo × parcela) — determinístico e testado
- [ ] Faturas de cartão, cartão-benefício, conciliação, cobrança de conta variável
- [ ] Dashboard financeiro transversal e telas de correção

## Fase 4 — Multimodal

- [ ] Áudio com transcrição (`transcribe_audio` separado de `extract_record`)
- [ ] Foto como anexo; intenção `attach` com resolução de referência

## Fase 5 — Agenda

- [ ] OAuth Google, leitura de todos os eventos, criar e remarcar pelo chat

## Fase 6 — Organização

- [ ] Áreas configuráveis, dashboards por área, vínculos (`links`), taxa de cumprimento

## Fase 7 — Controle

- [ ] Configurações de IA, painel de custo, `query` pelo chat, orçamento por categoria

## Fase 8 — Web

- [ ] **CORS nas Edge Functions — bloqueia todo o resto desta fase.** Não existe hoje **nenhum** tratamento de `OPTIONS` nem header `Access-Control-Allow-*` no repo. No emulador Android o `POST` passa; no Chrome ele morre no *preflight*, e o sintoma é um erro de rede genérico que não aponta para CORS. Ficou fora da F0.9 de propósito (o E2E daquela fase é Android). Precisa estar resolvido **antes** de qualquer build web que chame `/functions/v1/`. A origem permitida vem de env no Coolify, nunca de literal no repo.
- [ ] Build web, layout responsivo, ajustes de captura de áudio e câmera no navegador
