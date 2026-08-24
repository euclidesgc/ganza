# Decisões da feature 003 - Chat de texto e confirmação

Registre aqui somente decisões de escopo, produto, arquitetura ou execução que
valem para esta feature. Decisões transversais pertencem a
[`docs/decisions.md`](../../decisions.md).

## Decisões vigentes

| ID | Decisão | Contexto e impacto | Data |
|---|---|---|---|
| FD-001 | A interpretação (`classify_intent` → `extract_record`) e a transcrição de áudio são `task_type` **separados**, mesmo quando o mesmo modelo faria as duas numa chamada. | Quando errar, é preciso saber qual etapa falhou (`docs/plano.md` §6.11). Aqui só entra `classify_intent`/`extract_record`; `transcribe_audio` é da feature 006. | 2026-08-24 |
| FD-002 | `attach` e `query` nascem na taxonomia com a resposta "ainda não sei", não como funcionalidade. | O `docs/plano.md` §6.2 já define que `update` não existe e `query` recebe "ainda não sei consultar". Classificar e responder honestamente evita virar registro torto. | 2026-08-24 |

## Modelo de decisão

### FD-NNN - Título objetivo

- **Data:** AAAA-MM-DD
- **Contexto:** problema ou oportunidade que exigiu a decisão.
- **Alternativas:** opções consideradas e suas concessões.
- **Decisão:** escolha feita e responsável.
