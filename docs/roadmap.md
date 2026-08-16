# Roadmap — ganza

Fonte única de rastreabilidade: o que foi feito, o que está em andamento, o que falta. **Ordenado por dependência** — o que destrava o quê. Mantido pela IA no fechamento de cada trabalho.

Status: `[ ]` não iniciada · `[-]` em andamento · `[x]` concluída

> **Regra de ritmo (do `docs/plano.md`): se a fase N não estiver em uso diário, não comece a N+1.** O objetivo real é o O8 — sobreviver ao próprio uso. Nenhuma fase entregue e não usada conta como progresso.

---

## Decisões travadas

| # | Decisão | Data | Onde |
|---|---|---|---|
| D1 | **Backend próprio em NestJS; Supabase reduzido a Postgres + Auth + PostgREST + Storage + pg_cron.** Sem Edge Functions/Deno. Motivo: o deploy de função no Supabase self-hosted é por volume montado, e é justamente ali que mora o código que mais muda (ingest, prompts, cálculo). Com NestJS, publicar lógica volta a ser merge em branch. | 2026-08-16 | `CLAUDE.md` |
| D2 | **Sem melos e sem packages.** Um app só, módulos em `app/lib/modules/`. Extrair para pacote quando existir um segundo consumidor de verdade. | 2026-08-16 | `CLAUDE.md` |
| D3 | **Um ambiente remoto (produção) + Supabase local para dev e teste de migration.** `hml` nasce quando a falta doer. | 2026-08-16 | `docs/GITFLOW.md` §4 |
| D4 | **Backup não é escopo.** Decisão do humano. **Sobrepõe o R9 e o §5.1 do `docs/plano.md`**, que pediam `pg_dump` agendado desde a Fase 0. Não propor rotina de backup, não tratar como item de DoD, não reabrir o assunto — se um dia mudar, é o humano quem traz. | 2026-08-16 | `CLAUDE.md` |
| D5 | **Repositório `euclidesgc/ganza`, privado, `develop` como branch padrão.** Proteção de branch do GitHub não está disponível no plano gratuito para repo privado — a cancela é o hook `pre-push` em `scripts/git-hooks/`. | 2026-08-16 | `docs/GITFLOW.md` §1 |
| D6 | **Domínio sob `bmjtech.duckdns.org`: `supabase.ganza.` (Supabase, no ar), `ganza.` (app) e `api.ganza.` (backend).** O `ganza.duckdns.org` já pertence a outra pessoa (`95.99.103.11`), e registrar um DuckDNS novo exige a conta do humano. O wildcard do `bmjtech` resolve em qualquer profundidade — verificado por `dig` —, então isto funciona sem interação. **Trocar depois é barato:** `PATCH /api/v1/applications/{uuid}` com `domains` + rebuild do front (a URL da API é compile-time). Nomes livres no DuckDNS, se um dia quiser: `ganzaapp`, `meuganza`, `ganza-app`, `appganza`, `ganzabr`. | 2026-08-16 | `.claude/skills/subir-supabase/SKILL.md` |

## Decisões pendentes do humano

| # | Decisão | Bloqueia | Contexto |
|---|---|---|---|
| P1 | **Conta Google e projeto Firebase** para FCM e OAuth do Calendar. | F2 (push), F5 (agenda) | O OAuth em modo de teste expira o refresh token a cada 7 dias — publicar o app resolve. |
| P5 | **Fontes Fraunces e IBM Plex Sans** em `app/assets/fonts/`. | nada — hoje cai no fallback do sistema | Os tokens já apontam para as famílias certas; falta baixar os `.ttf` (SIL OFL, ambas) e declarar no `pubspec.yaml`. Sem elas, os algarismos tabulares não valem e a coluna de valores vai dançar. |
| P7 | **Resolver os incidentes do GitGuardian no dashboard.** | check verde no #5 (não bloqueia o merge) | Investigado a fundo: o commit atual tem **zero** literais de credencial, confirmado por duas ferramentas independentes (`gitleaks` → *no leaks found* e a varredura do nosso hook). Ainda assim o check marca — e o número **subiu de 3 para 4 sem nenhuma linha nova**, o que indica incidentes acumulados no lado do GG a cada versão do branch, não conteúdo do código. Os achados originais eram valores de **teste** (`nao-e-uma-senha`, `valor-de-teste`), nunca credencial real. Só o dashboard mostra o detalhe, e o acesso é seu: marque-os como resolvidos/ignorados. |
| P6 | **Criar seu usuário no Supabase** para poder entrar no app. | testar o login de verdade | Sem SMTP (P4), o cadastro pela tela não confirma o e-mail. O caminho hoje: criar pelo Studio (`https://supabase.ganza.bmjtech.duckdns.org` → login com `SERVICE_USER_ADMIN`) ou por `signup` na API e confirmar por SQL. Posso fazer isso quando você disser o e-mail. |
| P4 | **SMTP para os e-mails de autenticação** (confirmação de cadastro e recuperação de senha). | F0.7 (auth completa) | `SMTP_HOST`/`USER`/`PASS` estão vazios no serviço. Qualquer provedor serve; a alternativa é ligar `ENABLE_EMAIL_AUTOCONFIRM` enquanto o app é só seu. |
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
- [ ] **F0.8 — Backend NestJS: esqueleto.** Projeto, Dockerfile, health check, conexão com o Postgres, deploy no Coolify em `api.ganza.bmjtech.duckdns.org`, CORS.
- [ ] **F0.9 — Cadastro manual ponta a ponta.** Uma entidade (transação) criada e listada pela UI, sem IA. É o que prova que o encanamento inteiro funciona.

## Fase 1 — Chat de texto

- [ ] `/ingest` no backend, camada de IA abstraída (`ai_providers`/`ai_routes`/`ai_usage`) com Gemini
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

- [ ] Build web, layout responsivo, ajustes de captura de áudio e câmera no navegador
