# 005 - Finanças e conciliação · Plano

Fatiamento e execução. O "o quê" está em [`02_specs.md`](02_specs.md), o
contrato do pronto em [`01_prd.md`](01_prd.md), as decisões desta feature em
[`decisions.md`](decisions.md), os desvios em [`changes.md`](changes.md), e o
item canônico está no [`docs/roadmap.md`](../roadmap.md).

Estado: **não iniciada** · branch a criar (de `develop`) · a 003 entregou o
pipeline de chat e a 004, a máquina de ocorrência que o compromisso reusa ·
**próximo passo: Fase 1 — `/finance-math` e compromissos.**

---

## Gauntlet

**Referência:** [`01_prd.md`](01_prd.md), [`02_specs.md`](02_specs.md),
[`decisions.md`](decisions.md), [`changes.md`](changes.md), este plano,
`CLAUDE.md` e as decisões transversais em [`docs/decisions.md`](../decisions.md).

**Rubrica binária:** cada fase só passa quando contrato/DoD, arquitetura,
invariantes de produto, segurança e evidência aplicável estiverem `pass`.

**Invariantes bloqueantes:** juros/amortização é código determinístico testado
(nunca IA); dinheiro em centavos inteiros (nenhum `double` no caminho de
gravação); o modelo interpreta, quem calcula é `/finance-math`; RLS em toda
tabela nova; `confirmProposal` grava só `commitments`/`commitment_occurrences`.

**Provas:** cada crítico devolve `pass`/`fail` com evidência reproduzível e
arquivo/linha. A cada tarefa concluída, o `supervisor-dod` julga o bloco DoD,
cego ao plano.

**Limites:** no máximo 3 rodadas e 45 minutos **por fase**; no nível da tarefa,
duas devoluções `NÃO CUMPRIDO` e a terceira escala ao humano.

**Evidência E2E:** fica em `e2e/round_NN/`; o E2E roda só contra a stack local,
por `patrol test` (escopo do humano).

---

## 1. Decisões travadas antes de começar

As decisões desta feature moram em [`decisions.md`](decisions.md). As que
governam o núcleo: (a) `/finance-math` é código puro testado; (b) detecção de
parcelamento é regex, sem IA; (c) a sincronização bancária fica para a Fase 3/4
(decisão FD-021, conta externa do humano).

---

## 2. Âncoras no código existente

- **Backend** — `_shared/ai/proposal_schema.ts` já aceita `create_commitment`;
  `proposal_writer.ts` `confirmProposal` migra `create_transaction`/`create_routine`.
- **004** — `routine_math.ts` e a migration `0013` (padrão de ocorrência com
  `unique (rotina/compromisso, sequence)` e RLS por FK).
- **Banco** — próxima migration é a `0015`.

---

## 3. Ritual de fechamento de fase (vale para todas)

`supervisor-dod` julga a tarefa → QA roda `revisar-fase` → CISO revisa o diff →
`fechar-etapa` roda o DoD → PR com DoD no corpo → CI verde → merge → próxima
fase. `CHANGELOG.md` atualizado no mesmo PR.

---

## 4. Fases

### Fase 1 — `/finance-math` e compromissos · PR 1

Branch: `feature/GZ-46-finance-math`. O núcleo determinístico: a matemática de
juros/amortização e o modelo de compromisso que gera as parcelas futuras.

**Tarefas**

- [x] **T1.1** — `supabase/functions/_shared/finance_math.ts` + `finance_math_test.ts`: `priceInstallment`, `amortizationSchedule` (Price e SAC) e `earlyPayoffPresentValue`, em centavos inteiros. · camada **backend** · `especialista-backend` · **DoD: CUMPRIDO**

  **DoD da tarefa**
  - `finance_math_test.ts` prova a parcela Price conhecida (ex.: R$ 60.000 em 48x a 1,2% a.m.), o `balance` final `0` nos dois sistemas, e que o PV da quitação desconta as parcelas restantes pela taxa — **falha sem a mudança**.
  - O teste assere que parcela, juro, principal e saldo são **inteiros em centavos** (nenhum valor monetário fracionário) e que a soma dos principais fecha no total — o `number` só carrega centavos.
  - `deno fmt --check`, `deno lint` e `deno task check` saem `0`.

- [x] **T1.2** — Migration `supabase/migrations/0015_criar_compromissos.sql`: `commitments` + `commitment_occurrences`, RLS, `status` fechado, `unique (commitment_id, sequence)`. · camada **banco** · `especialista-dados` · **DoD: CUMPRIDO**

  **DoD da tarefa**
  - A migration aplica limpo num banco vazio (docker + todas as migrations) e as três checagens do job "Banco" devolvem **vazio**.
  - `commitment_occurrences` tem `unique (commitment_id, sequence)` — geração duplicada é barrada pelo banco.

- [x] **T1.3** — `confirmProposal` migra `create_commitment` (grava `commitments` + as ocorrências, `installment` gera as N parcelas) e `proposal_schema` valida o payload. · camada **backend** · `especialista-backend` · **DoD: CUMPRIDO**

  **DoD da tarefa**
  - `proposal_writer_test.ts` prova que confirmar `create_commitment` grava `commitments` + N ocorrências (`installment`) com `expected_amount` = parcela calculada, e que payload com campo proibido é rejeitado — **falha sem a mudança**.
  - `deno task test` verde; `deno fmt --check`/`deno lint`/`deno task check` saem `0`.

**DoD da Fase 1**

- [x] `cd supabase/functions && deno task test` verde — **117 testes**, incluindo `finance_math_test.ts` (5).
- [ ] Jobs "Banco" e "Edge Functions" verdes no CI do PR.

---

### Fase 2 — App: compromissos e simulação de quitação · PR 2

Branch: `feature/GZ-47-compromissos-app`. Expõe a matemática ao app e entrega a
tela de compromissos com a **simulação de quitação antecipada** — o coração do
"plano de recuperação".

**Tarefas**

- [x] **T2.1** — Edge Function `supabase/functions/finance-math/` (`POST { mode, total_amount, installments_total, interest_rate_monthly }` → `{ schedule, early_payoff_present_value }`), JWT do usuário, sem `service_role`; reusa `_shared/finance_math.ts`. · camada **backend** · `especialista-backend` · **DoD: CUMPRIDO**

  **DoD da tarefa**
  - `finance-math/handler_test.ts` prova `405`/`401`/`400` (parâmetros inválidos) e o caminho feliz (schedule com saldo final 0 e PV de quitação) — **falha sem a mudança**; o handler **não** calcula nada (delega a `_shared/finance_math.ts`).
  - `finance-math` usa só o JWT do usuário: `rtk proxy grep -cE "SERVICE_ROLE" supabase/functions/finance-math/handler.ts` imprime `0`.
  - `deno fmt --check`, `deno lint`, `deno task check` e `deno task test` saem `0`.

- [x] **T2.2** — App `commitments_module`: lista de compromissos (nome, direção, modo, total) + simulação de quitação via `/finance-math`; o card mostra saldo devedor e a simulação. · camada **app** · `especialista-apresentacao` · **DoD: CUMPRIDO**

  **DoD da tarefa**
  - `app/lib/modules/commitments_module` (domain puro, data com zard, presentation com Cubit `sealed`, barrel só rota+DI); `rtk proxy grep -rE "flutter|supabase|dio" .../domain` devolve `0`.
  - Widget test prova que a lista mostra os compromissos e que a simulação chama `finance-math` e exibe o valor presente — **falha sem a mudança**.
  - `flutter analyze` em `app/` sai `0`; `dart format --output=none --set-exit-if-changed .` sai `0`; `flutter test -r compact` verde; `bash scripts/gates_guard.sh` limpo.

**DoD da Fase 2**

- [x] `cd supabase/functions && deno task test` verde — **125 testes**, incluindo `finance-math/handler_test.ts` (8).
- [x] `cd app && flutter test -r compact` verde — **182 testes**; `flutter analyze` sai `0`.
- [ ] Jobs "App" e "Edge Functions" verdes no CI do PR.

---

### Fase 3 — Conciliação · PR 3

Branch: `feature/GZ-48-conciliacao`. A máquina de match: o movimento bancário
casa com a ocorrência prevista por **valor igual (± centavos) em janela de ±5
dias** (a mais próxima vence); o valor do banco é canônico.

**Tarefas**

- [x] **T3.1** — `supabase/functions/_shared/conciliation.ts` + `conciliation_test.ts`: `findMatch(movement, candidates)` determinístico. · camada **backend** · `especialista-backend` · **DoD: CUMPRIDO**

  **DoD da tarefa**
  - `conciliation_test.ts` prova o match por valor (tolerância de 1 centavo) + janela de 5 dias, que a **mais próxima** vence, e que fora da janela ou do valor devolve `null` — **falha sem a mudança**.
  - `deno fmt --check`, `deno lint` e `deno task check` saem `0`.

- [x] **T3.2** — Edge Function `supabase/functions/conciliate/` (`POST { transaction_id }`): lê a transação `bank_sync` pendente, busca a ocorrência compatível (`pending`, valor/±5 dias), casa (grava `transaction_id`/`actual_amount`/`status='matched'` na ocorrência e `reconciliation_status='matched'` na transação) ou devolve `sem_match`. · camada **backend** · `especialista-backend` · **DoD: CUMPRIDO**

  **DoD da tarefa**
  - `conciliate/handler_test.ts` prova `405`/`401`/`400`/`404` (transação alheia) e o caminho feliz (casa e grava o vínculo) e `sem_match` — com `fetch` stubado; **falha sem a mudança**.
  - `conciliate` usa **só o JWT do usuário**: `rtk proxy grep -cE "SERVICE_ROLE" supabase/functions/conciliate/handler.ts` imprime `0`.
  - `deno fmt --check`, `deno lint`, `deno task check` e `deno task test` saem `0`.

**DoD da Fase 3**

- [x] `cd supabase/functions && deno task test` verde — **136 testes**, incluindo `conciliation_test.ts` (5) e `conciliate/handler_test.ts` (6).
- [ ] Job "Edge Functions" verde no CI do PR.

---

### Fase 4 — Sincronização bancária (OFX) e fechamento · PR 4

Branch: `feature/GZ-49-sync-ofx`. Entrega o "obter meus dados bancários" pelo
caminho **OFX** (FD-021): parser determinístico + importação que cria os
movimentos `bank_sync` (deduplicados), prontos para o conciliador da Fase 3.
Faturas de cartão, cartão-benefício e telas de correção ficam para depois
(CHG-001).

**Tarefas**

- [x] **T4.1** — `supabase/functions/_shared/ofx.ts` + `ofx_test.ts`: `parseOfx(raw)` determinístico (extrai `DTPOSTED`/`TRNAMT`/`FITID`/`MEMO`, normaliza data e converte valor para centavos com sinal). · camada **backend** · `especialista-backend` · **DoD: CUMPRIDO**

  **DoD da tarefa**
  - `ofx_test.ts` prova a extração de múltiplos `STMTTRN` (SGML e XML), a data `YYYYMMDD` → `YYYY-MM-DD` e o valor decimal → centavos com sinal — **falha sem a mudança**.
  - `deno fmt --check`, `deno lint` e `deno task check` saem `0`.

- [x] **T4.2** — Migration `0016_adicionar_external_id_transactions.sql` (`external_id text` + `unique (user_id, external_id)`) e Edge Function `supabase/functions/import-ofx/` (`POST { ofx }`): parseia, cria as transações `bank_sync` (direção pelo sinal, valor absoluto em centavos) e **deduplica** por `external_id`. · camadas **banco**+**backend** · `especialista-backend` · **DoD: CUMPRIDO**

  **DoD da tarefa**
  - A migration aplica limpo (docker + todas as migrations) e os 3 gates do job "Banco" devolvem **vazio**.
  - `import-ofx/handler_test.ts` prova `405`/`401`/`400` (OFX inválido) e o caminho feliz (cria N transações `bank_sync` com `external_id`) e a deduplicação (reimportar não duplica) — **falha sem a mudança**.
  - `import-ofx` usa **só o JWT do usuário**: `rtk proxy grep -cE "SERVICE_ROLE" supabase/functions/import-ofx/handler.ts` imprime `0`.
  - `deno fmt --check`, `deno lint`, `deno task check` e `deno task test` saem `0`.

- [x] **T4.3** — Fechamento: bateria (golden do card de compromisso), docs vivas e roadmap `005` `[x]`. · camadas **app**+**docs** · `qa`/`tech-lead` · **DoD: CUMPRIDO**

  **DoD da tarefa**
  - Golden do card de compromisso (com e sem simulação) com fonte real; `flutter analyze` e `flutter test -r compact` verdes.
  - `docs/005_financas/01_prd.md`/`02_specs.md` descrevem o estado final; `docs/roadmap.md` marca `- [x] 005 - Finanças e conciliação`.
  - `bash scripts/verify-gauntlet.sh` sai `✓` com a 005 `[x]`.

**DoD da Fase 4**

- [ ] `cd supabase/functions && deno task test` verde, incluindo `ofx_test.ts` e `import-ofx/handler_test.ts`.
- [ ] `cd app && flutter test -r compact` verde; `flutter analyze` sai `0`.
- [ ] Jobs "Banco", "App" e "Edge Functions" verdes no CI do PR.

---

## 5. Rastreabilidade — as linhas do DoD do roadmap

| # | Linha do DoD do roadmap | Fase que fecha |
|---|---|---|
| 1 | Compromissos geram ocorrências futuras (parcelamento em Nx) | **1** |
| 2 | Financiamento: taxa, amortização (Price/SAC), simulação | **1** e **2** |
| 3 | Detecção de parcelamento na fatura (regex) | **1** |
| 4 | Conciliação (match valor ± centavos, janela ±5 dias) | **3** |
| 5 | Dashboard financeiro (saldo, comprometido, custo de juros) | **2** |

---

## 6. Progresso

Legenda das fases: `[ ]` não iniciada · `[-]` em andamento · `[x]` mergeada em
`develop`.

- [x] **Fase 1** — `/finance-math` e compromissos · PR 1
- [x] **Fase 2** — App: compromissos e dashboard · PR 2
- [x] **Fase 3** — Conciliação · PR 3
- [-] **Fase 4** — Sincronização bancária (OFX) e fechamento · PR 4
