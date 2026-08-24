# Decisões da feature 004 - Rotinas e ocorrências

Registre aqui somente decisões de escopo, produto, arquitetura ou execução que
valem para esta feature. Decisões transversais pertencem a
[`docs/decisions.md`](../../decisions.md).

## Decisões vigentes

| ID | Decisão | Contexto e impacto | Data |
|---|---|---|---|
| FD-004 | A recorrência é **código puro determinístico** (`nextDueDate`), nunca saída do modelo; `calendar` usa dia da semana ISO e `interval_from_completion` soma `intervalDays` à âncora (conclusão real, para o atraso não distorcer o ciclo). | `docs/plano.md` §6.4: "a distinção mais importante aqui" — lavar roupa toda segunda é data fixa; banho a cada 15 dias conta da conclusão. Errar isso distorce o histórico para sempre; por isso o cálculo recebe a data por parâmetro e é testado com datas fixas. | 2026-08-24 |
| FD-005 | **Adiar move a data da mesma ocorrência, não cria outra** — o ciclo é a unidade de contagem; o movimento fica no `occurrence_events`. | §6.4: se cada adiamento gerasse ocorrência nova, "quantas vezes lavei roupa em agosto" perderia resposta confiável. `postpone` atualiza `due_date` e loga; `sequence` não muda. | 2026-08-24 |

## Modelo de decisão

### FD-NNN - Título objetivo

- **Data:** AAAA-MM-DD
- **Contexto:** problema ou oportunidade que exigiu a decisão.
- **Alternativas:** opções consideradas e suas concessões.
- **Decisão:** escolha feita e responsável.
