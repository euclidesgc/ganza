# 005 - Finanças e conciliação · Specs

Âncoras e contratos. O "o quê" está no [`01_prd.md`](01_prd.md); o fatiamento,
no [`03_plan.md`](03_plan.md).

## 1. O que já existe e se reutiliza

- **Pipeline do chat** (003): `proposal_schema.ts` já aceita `create_commitment`;
  `confirmProposal` hoje migra `create_transaction` e `create_routine`.
- **Máquina de ocorrência** (004): `_shared/routine_math.ts` e a tabela
  `routine_occurrences` — o compromisso reusa o **mesmo desenho** (tabela
  separada, view unificada de "o que vem esta semana", §6.4).
- **Tabelas** `transactions` (com `category_id`, `source`, `reconciliation_status`).

## 2. Matemática financeira determinística (`/finance-math`)

Código puro, sem relógio nem rede; dinheiro em **centavos inteiros** (o
arredondamento é explícito, uma vez por linha). `monthlyRate` é fração
(0.012 = 1,2%).

| Função | O que devolve |
|---|---|
| `priceInstallment(totalCents, months, monthlyRate)` | a parcela fixa Price (`PMT = PV·i / (1 − (1+i)⁻ⁿ)`), em centavos |
| `amortizationSchedule(mode, totalCents, months, monthlyRate)` | lista `{period, installment, interest, principal, balance}` (Price ou SAC), balance final 0 |
| `earlyPayoffPresentValue(installmentCents, remainingMonths, monthlyRate)` | o valor presente das parcelas restantes descontado pela taxa do contrato |

## 3. Tabelas (migration nova)

```
commitments            id, user_id, area_id null, name, direction /*in|out*/,
                       value_mode /*one_off|installment|fixed|variable*/,
                       total_amount, installments_total, due_day, closing_day,
                       reminder_days_before default 3, interest_rate_monthly,
                       amortization_system /*price|sac*/, indexer,
                       outstanding_balance, category_id null, status,
                       started_at, ends_at
commitment_occurrences id, commitment_id, sequence, due_date, expected_amount,
                       actual_amount, estimate_source, transaction_id null,
                       status /*pending|done|skipped|cancelled|missed|matched*/
                       unique (commitment_id, sequence)
```

- `installment` gera **todas** as ocorrências na criação (sequence 1..N).
- `fixed` gera a próxima; `variable` gera com `expected_amount = null`.

RLS em todas; as tabelas-filha herdam o dono pela FK (padrão da 004).

## 4. Detecção de parcelamento (sem IA)

Regex na descrição: `/parc(ela)?\.?\s*(\d{1,2})\s*\/\s*(\d{1,2})/i` →
"PARC 03/12" = parcela 3 de 12. Deduplicação por `estabelecimento + valor da
parcela + total de parcelas`.

## 5. Contratos

**`confirmProposal` (estendido)** — para `create_commitment`, revalida o payload
(conjunto fechado) e grava `commitments` + as `commitment_occurrences`
(`installment` gera as N parcelas; `fixed`/`variable` geram a primeira).

**`/finance-math`** — `_shared/finance_math.ts` reutilizado por `confirmProposal`
e, na Fase 2, pela simulação de quitação.

## 6. Invariantes que o DoD cobra

1. O cálculo é determinístico e testado (parcela Price conhecida, balance final
   `0`, PV da quitação).
2. Nenhum `double` representa dinheiro no caminho de gravação.
3. O `create_commitment` rejeita campo proibido (`user_id`, `category_id` por id).
