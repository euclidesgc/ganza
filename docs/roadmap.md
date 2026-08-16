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

## Decisões pendentes do humano

| # | Decisão | Bloqueia | Contexto |
|---|---|---|---|
| P1 | **Repositório no GitHub** — criar `euclidesgc/ganza` privado agora? | F0.2 (CI) | O CI e o auto-deploy do Coolify dependem dele. |
| P2 | **Conta Google e projeto Firebase** para FCM e OAuth do Calendar. | F2 (push), F5 (agenda) | O OAuth em modo de teste expira o refresh token a cada 7 dias — publicar o app resolve. |

---

## Fase 0 — Fundação

O plano estima 3 semanas. Com a D1 (sem Edge Functions) a estimativa cai para ~2.

- [ ] **F0.1 — Repositório e harness.** Estrutura, `CLAUDE.md`, agentes, skills, GitFlow, `.gitignore`, README, CHANGELOG. *(em curso nesta sessão)*
- [ ] **F0.2 — GitHub + CI verde.** Criar o repo, `main`/`develop`, proteção de branch, e o `ci.yml` passando de verdade (hoje ele descreve um projeto que ainda não existe). Depende de **P1**.
- [ ] **F0.3 — Supabase enxuto no Coolify.** Skill `subir-supabase`. Projeto `Ganza`, DuckDNS `ganza.duckdns.org` com wildcard, TLS, SMTP para os e-mails de auth. Confirmar que os projetos vizinhos seguem saudáveis.
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
