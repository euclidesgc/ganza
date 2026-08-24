# 004 - Rotinas e ocorrências · Specs

Âncoras no código e contratos desta feature. O "o quê" está no
[`01_prd.md`](01_prd.md); o fatiamento, no [`03_plan.md`](03_plan.md).

## 1. O que já existe e se reutiliza

- **Pipeline do chat** (003): `_shared/ai/proposal_schema.ts` já aceita o `kind`
  `create_routine`; `proposal_writer.ts` tem `confirmProposal` (hoje só migra
  `create_transaction`) e `writeProposals`; o card do app já confirma/cancela.
- **Gabarito de Edge Function** (`transactions/`, `proposals/`, `categorize/`) e
  de módulo Flutter (`transactions_module`).
- **Tabelas** `messages`/`proposed_actions` com RLS.

## 2. Modelo de recorrência (determinístico)

`nextDueDate(mode, rule, intervalDays, anchor)` — código puro, sem relógio como
dependência (a data é passada para o teste ser determinístico):

| `mode` | Regra | Próxima data |
|---|---|---|
| `calendar` | `rule` = dia da semana ISO (1=segunda..7=domingo) | o próximo dia ≥ `anchor` que cai nesse dia da semana |
| `interval_from_completion` | `intervalDays` = N | `anchor + N dias` |

- Primeira ocorrência: `anchor` = data de criação da rotina.
- A partir da segunda: `anchor` = `due_date` da ocorrência anterior (`calendar`)
  ou `completed_at` da anterior (`interval_from_completion`).

## 3. Tabelas (migration nova)

```
routines             id, user_id, area_id null, name,
                     recurrence_mode /*calendar|interval_from_completion*/,
                     recurrence_rule /*weekday ISO p/ calendar*/, interval_days,
                     reminder_days_before, notify_until_days default 3,
                     status, created_at, updated_at
                     unique (user_id, lower(btrim(name)))  — corrigir rotina não duplica
routine_occurrences  id, routine_id, sequence, due_date, completed_at,
                     status /*pending|done|postponed|skipped|cancelled|missed*/
                     unique (routine_id, sequence)
occurrence_events    id, routine_id, occurrence_id, event
                     /*postponed|skipped|done|cancelled*/, from_date, to_date,
                     created_at
```

RLS em todas, política `user_id = (select auth.uid())` (ou dono via `routine_id`
para as tabelas-filha, que herdam o dono pela FK — decisão na migration).

**View `routine_summaries`** (`security_invoker`) — projeção da taxa de
cumprimento: `routine_id`, `name`, `done_count`, `resolved_count`. Roda com os
privilégios do chamador, então a RLS de `routines`/`routine_occurrences`
continua decidindo o dono; não é regra de negócio em plpgsql, é agregação.

## 4. Contratos

**`confirmProposal` (estendido)** — para `create_routine`, revalida o payload
(conjunto fechado) e grava em `routines` + a primeira `routine_occurrences`
(`sequence = 1`, `due_date = nextDueDate(...)`).

**Edge Function `/routine-occurrences`** (Fase 2) — `POST` com
`{ occurrence_id, action }`:

| `action` | Efeito |
|---|---|
| `done` | `status = done`, `completed_at = now`; gera a próxima ocorrência |
| `postpone` | `due_date = body.due_date` (mesma linha), evento `postponed` |
| `skip` | `status = skipped`, evento `skipped` |
| `cancel` | `status = cancelled`, evento `cancelled` |

Usa JWT do usuário (RLS decide dono da ocorrência).

## 5. Invariantes que o DoD cobra

1. A próxima ocorrência é **determinística** (`nextDueDate` testado) — nunca
   sai do modelo.
2. **Adiar move, não cria**: `postpone` atualiza a mesma linha e loga evento; a
   `sequence` não muda.
3. `interval_from_completion` conta da **conclusão real**, não da data vencida.
4. Estados fechados no banco (`check`) e no app (`enum`).

## 6. Riscos

- **Recorrência errada distorce o histórico** → `nextDueDate` testado com datas
  fixas e os dois modos.
- **Geração duplicada** → `unique (routine_id, sequence)`.
- **Correção de rotina** (fora desta feature, na tela) → não duplica pelo
  `unique (user_id, lower(btrim(name)))`.
