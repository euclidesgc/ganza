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
| D6 | **Domínio sob `bmjtech.duckdns.org`: `ganza.bmjtech.duckdns.org` (app) e `api.ganza.bmjtech.duckdns.org` (backend).** O `ganza.duckdns.org` já pertence a outra pessoa (`95.99.103.11`), e registrar um DuckDNS novo exige a conta do humano. O wildcard do `bmjtech` resolve em qualquer profundidade — verificado por `dig` —, então isto funciona sem interação. **Trocar depois é barato:** `PATCH /api/v1/applications/{uuid}` com `domains` + rebuild do front (a URL da API é compile-time). Nomes livres no DuckDNS, se um dia quiser: `ganzaapp`, `meuganza`, `ganza-app`, `appganza`, `ganzabr`. | 2026-08-16 | `.claude/skills/subir-supabase/SKILL.md` |

## Decisões pendentes do humano

| # | Decisão | Bloqueia | Contexto |
|---|---|---|---|
| P1 | **Conta Google e projeto Firebase** para FCM e OAuth do Calendar. | F2 (push), F5 (agenda) | O OAuth em modo de teste expira o refresh token a cada 7 dias — publicar o app resolve. |
| P3 | **Trocar o domínio do `supabase-kong` no painel do Coolify** para `https://supabase.ganza.bmjtech.duckdns.org` (30 s: projeto Ganza → `ganza-supabase` → contêiner `supabase-kong` → campo de domínio → salvar → redeploy). | TLS; OAuth do Google (F5); app fora da rede local | **A API v1 do Coolify não expõe esse campo** — cinco caminhos tentados, todos registrados em `docs/deploy/coolify.md`. É campo de UI. Enquanto isso o endpoint `sslip.io` funciona por HTTP. |
| P4 | **SMTP para os e-mails de autenticação** (confirmação de cadastro e recuperação de senha). | F0.7 (auth completa) | `SMTP_HOST`/`USER`/`PASS` estão vazios no serviço. Qualquer provedor serve; a alternativa é ligar `ENABLE_EMAIL_AUTOCONFIRM` enquanto o app é só seu. |
| P2 | **GitHub Pro (US$ 4/mês)?** Só ele libera proteção de branch e *required status checks* em repo privado. | nada hoje | O hook `pre-push` cobre o push direto. O que falta é a cancela que impede mergear com CI vermelha — hoje isso é disciplina. Alternativa sem custo: tornar o repo público. |

---

## Fase 0 — Fundação

O plano estima 3 semanas. Com a D1 (sem Edge Functions) a estimativa cai para ~2.

- [x] **F0.1 — Repositório e harness.** Estrutura, `CLAUDE.md`, 9 agentes, 13 skills, GitFlow, `.gitignore`, README, CHANGELOG, `gates_guard.sh`, `ci.yml`.
- [-] **F0.2 — GitHub + CI verde.** Repo privado criado, `main`/`develop`, `develop` como padrão e hook `pre-push` no lugar da proteção de branch (ver D5). **Falta:** o `ci.yml` passar de verdade — hoje ele descreve um projeto que ainda não existe, e só fica verde depois de F0.5/F0.8.
- [-] **F0.3 — Supabase enxuto no Coolify.** Sete contêineres no ar e saudáveis (`db`, `kong`, `auth`, `rest`, `storage`, `meta`, `studio`), **~840 MB** — 8 dos 15 serviços do template foram cortados. Vizinhos (driva, love-secret, Garage) seguem `running:healthy`. Detalhes em `docs/deploy/coolify.md`. **Falta:** domínio próprio + TLS (**P3**) e SMTP (**P4**).
- [ ] **F0.4 — Primeira migration.** Extensões (`pgcrypto`, `pg_cron`, `pg_net`, `supabase_vault`), `profiles`, `areas`, e RLS em tudo. Skill `criar-migration`. PR sozinho.
- [ ] **F0.5 — App Flutter: esqueleto.** `flutter create`, flavors dev/prod, `bootstrap.dart` com as 4 redes de erro, go_router, get_it, `core/error` e `core/network`.
- [ ] **F0.6 — Design system.** Tokens de `core/theme/` a partir da identidade do plano §11 (paleta couro/palha/ocre/latão, Fraunces + IBM Plex Sans com algarismos tabulares), tema claro e escuro. `gates_guard.sh` verde.
- [ ] **F0.7 — Auth + navegação.** Login pelo Supabase, sessão persistida, shell de navegação, tela vazia por área.
- [ ] **F0.8 — Backend NestJS: esqueleto.** Projeto, Dockerfile, health check, conexão com o Postgres, deploy no Coolify em `api.ganza.duckdns.org`, CORS.
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
