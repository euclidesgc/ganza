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

### Fase 2 — App: compromissos e dashboard financeiro · PR 2

`commitments_module` (lista, cronograma, simulação de quitação) e o dashboard
(saldo, comprometido, dívida total e custo de juros).

### Fase 3 — Conciliação · PR 3

Movimento bancário casa com registro/ocorrência (valor ± centavos, janela ±5
dias); sem match → pergunta no chat.

### Fase 4 — Sincronização bancária, faturas e correção · PR 4

Pluggy/OFX (FD-021), faturas de cartão, cartão-benefício, telas de correção e
fechamento (bateria + docs vivas; roadmap 005 `[x]`).

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

- [-] **Fase 1** — `/finance-math` e compromissos · PR 1
- [ ] **Fase 2** — App: compromissos e dashboard · PR 2
- [ ] **Fase 3** — Conciliação · PR 3
- [ ] **Fase 4** — Sincronização, faturas e correção · PR 4
