# 004 - Rotinas e ocorrências · Plano

Fatiamento e execução. O "o quê" está em [`02_specs.md`](02_specs.md), o
contrato do pronto em [`01_prd.md`](01_prd.md), as decisões desta feature em
[`decisions.md`](decisions.md), os desvios em [`changes.md`](changes.md), e o
item canônico está no [`docs/roadmap.md`](../roadmap.md).

Estado: **não iniciada** · branch a criar (de `develop`) · a 003 entregou o
pipeline de chat (`/ingest`, `proposed_actions`, `confirmProposal`, cards) que
esta feature consome · **próximo passo: Fase 1 — recorrência determinística e
rotina pelo chat.**

---

## Gauntlet

**Referência:** [`01_prd.md`](01_prd.md), [`02_specs.md`](02_specs.md),
[`decisions.md`](decisions.md), [`changes.md`](changes.md), este plano,
`CLAUDE.md` e as decisões transversais em [`docs/decisions.md`](../decisions.md).

**Rubrica binária:** cada fase só passa quando contrato/DoD, arquitetura,
invariantes de produto, segurança e evidência aplicável estiverem `pass`.

**Invariantes bloqueantes:** recorrência determinística (nunca do modelo);
adiar move a mesma ocorrência e loga evento, sem criar linha nova;
`interval_from_completion` conta da conclusão real; estados fechados no banco e
no app; RLS em toda tabela nova; `confirmProposal` só grava `routines` (nunca a
tabela final de outra feature).

**Provas:** cada crítico devolve `pass`/`fail` com evidência reproduzível e
arquivo/linha. A cada tarefa concluída, o `supervisor-dod` julga o bloco DoD,
cego ao plano.

**Limites:** no máximo 3 rodadas e 45 minutos **por fase**; no nível da tarefa,
duas devoluções `NÃO CUMPRIDO` e a terceira escala ao humano.

**Evidência E2E:** fica em `e2e/round_NN/`; o E2E roda só contra a stack local,
por `patrol test` (escopo do humano).

---

## 1. Decisões travadas antes de começar

As decisões desta feature moram em [`decisions.md`](decisions.md). As três que
governam a máquina: (a) recorrência é código puro testado; (b) adiar move, não
cria; (c) `interval_from_completion` usa a conclusão real como âncora.

---

## 2. Âncoras no código existente

- **App** — gabarito `transactions_module` (domain puro, data com zard,
  presentation com Cubit `sealed`, barrel só rota+DI). Não há tela de rotina.
- **Backend** — `_shared/ai/proposal_schema.ts` já aceita `create_routine`;
  `proposal_writer.ts` `confirmProposal` hoje só migra `create_transaction`.
- **Banco** — migrations `0001..0012`; a próxima é a `0013`.

---

## 3. Ritual de fechamento de fase (vale para todas)

`supervisor-dod` julga a tarefa → QA roda `revisar-fase` → CISO revisa o diff →
`fechar-etapa` roda o DoD da fase → PR com DoD no corpo → CI verde → merge →
próxima fase. `CHANGELOG.md` atualizado no mesmo PR.

---

## 4. Fases

### Fase 1 — Recorrência determinística e rotina pelo chat · PR 1

Branch: `feature/GZ-42-rotina-recursao`. Entrega a migration e o núcleo
determinístico, e faz o chat já criar rotina de ponta a ponta.

**Tarefas**

- [x] **T1.1** — Migration `supabase/migrations/0013_criar_rotinas.sql`: `routines`, `routine_occurrences` e `occurrence_events`, com RLS e política, `status` fechado por `check`, `unique (routine_id, sequence)` e `unique (user_id, lower(btrim(name)))`. · camada **banco** · `especialista-dados` · **DoD: CUMPRIDO**

  **DoD da tarefa**
  - A migration aplica limpo num banco vazio (docker `supabase/postgres:15.8.1.085` + `supabase/ci-bootstrap.sql` + todas as migrations em ordem) e as três checagens do job "Banco" devolvem **vazio**.
  - `routine_occurrences.status` tem `check (status in ('pending','done','postponed','skipped','cancelled','missed'))` e `unique (routine_id, sequence)` — geração duplicada é barrada pelo banco.

- [x] **T1.2** — `supabase/functions/_shared/routine_math.ts` + `routine_math_test.ts`: `nextDueDate(mode, rule, intervalDays, anchor)` determinístico para os dois modos. · camada **backend** · `especialista-backend` · **DoD: CUMPRIDO**

  **DoD da tarefa**
  - `routine_math_test.ts` prova `calendar` cai no dia da semana certo e `interval_from_completion` soma `intervalDays` ao `anchor`; datas fixas (sem `now()`) — **falha sem a mudança**.
  - `deno fmt --check`, `deno lint` e `deno task check` saem `0`.

- [x] **T1.3** — `confirmProposal` (em `_shared/ai/proposal_writer.ts`) migra `create_routine`: revalida o payload por allowlist, grava em `routines` e gera a primeira `routine_occurrences` (`sequence = 1`, `due_date = nextDueDate(...)`). · camada **backend** · `especialista-backend` · **DoD: CUMPRIDO**

  **DoD da tarefa**
  - `proposal_writer_test.ts` prova que confirmar `create_routine` grava `routines` + 1 ocorrência com `sequence = 1` e `due_date` determinístico, e que `payload` com campo proibido é rejeitado — **falha sem a mudança**.
  - `deno task test` verde; `deno fmt --check`/`deno lint`/`deno task check` saem `0`.

**DoD da Fase 1**

- [x] `cd supabase/functions && deno task test` verde — **100 testes**, incluindo `routine_math_test.ts` (5).
- [ ] Jobs "Banco" e "Edge Functions" verdes no CI do PR.

---

### Fase 2 — Estados e log (resolver ocorrência) · PR 2

Branch: `feature/GZ-43-resolver-ocorrencia`. Fecha a máquina de estado: marcar a
ocorrência nos estados terminais, **adiar movendo a data da mesma linha** (FD-005)
e **`done` gerando a próxima** (determinístico, FD-004), tudo com log em
`occurrence_events`.

**Tarefas**

- [x] **T2.1** — Edge Function `supabase/functions/routine-occurrences/` (`index.ts` só `Deno.serve(handler)`, `handler.ts` exportado): `POST { occurrence_id, action }` com `action` em `done|postpone|skip|cancel`; usa só o JWT do usuário (RLS decide dono); `done` marca e gera a próxima ocorrência (`sequence + 1`, `nextDueDate` com âncora `due_date + 1` no modo `calendar` e `completed_at` no `interval_from_completion`); `postpone` atualiza `due_date` da **mesma** linha e loga evento; `skip`/`cancel` marcam e logam. · camada **backend** · `especialista-backend` · **DoD: CUMPRIDO**

  **DoD da tarefa**
  - `supabase/functions/routine-occurrences/index.ts` contém só `Deno.serve(handler)`; `deno check supabase/functions/routine-occurrences/index.ts supabase/functions/routine-occurrences/handler.ts` sai `0`, e `routine-occurrences` está na task `check` do `deno.json`.
  - `routine-occurrences/handler_test.ts` prova `405`/`401`/`400` (JSON inválido, `action`/`occurrence_id` inválidos, `postpone` sem `due_date`)/`404` (ocorrência alheia)/`409` (já terminal) e o caminho feliz de cada ação — `done` gera a próxima (`sequence + 1`), `postpone` atualiza `due_date` **sem** inserir ocorrência nova, `skip`/`cancel` marcam — com `fetch` stubado; cada caso **falha sem a mudança**.
  - `postpone` grava `occurrence_events` (`postponed`, `from_date`/`to_date`) e **não** muda `sequence`: o teste assere que não há `insert` em `routine_occurrences` no `postpone`.
  - `routine-occurrences` usa **só o JWT do usuário**: `rtk proxy grep -cE "SERVICE_ROLE" supabase/functions/routine-occurrences/handler.ts` imprime `0`.
  - `deno fmt --check`, `deno lint`, `deno task check` e `deno task test` saem `0`.

**DoD da Fase 2**

- [x] `cd supabase/functions && deno task test` verde — **110 testes**, incluindo `routine-occurrences/handler_test.ts` (10).
- [ ] Job "Edge Functions" verde no CI do PR.

---

### Fase 3 — App: rotinas e ocorrências · PR 3

`routines_module`: lista de rotinas + próxima ocorrência + ações; atrasada
visualmente distinta.

### Fase 4 — Atrasadas, taxa de cumprimento e fechamento · PR 4

Lista de atrasadas, taxa de cumprimento por rotina, bateria (unit+widget+golden)
e docs vivas; roadmap 004 `[x]`.

---

## 5. Rastreabilidade — as linhas do DoD do roadmap

| # | Linha do DoD do roadmap | Fase que fecha |
|---|---|---|
| 1 | Dois modos de recorrência (calendar / interval) | **1** |
| 2 | Geração de ocorrências (determinística) | **1** |
| 3 | Cinco estados terminais + log de eventos | **2** |
| 4 | Lista de atrasadas + taxa de cumprimento | **4** |

---

## 6. Progresso

Legenda das fases: `[ ]` não iniciada · `[-]` em andamento · `[x]` mergeada em
`develop`.

- [x] **Fase 1** — Recorrência determinística e rotina pelo chat · PR 1
- [-] **Fase 2** — Estados e log · PR 2
- [ ] **Fase 3** — App: rotinas e ocorrências · PR 3
- [ ] **Fase 4** — Atrasadas, taxa de cumprimento e fechamento · PR 4
