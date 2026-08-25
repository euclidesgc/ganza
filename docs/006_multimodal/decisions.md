# Decisões da feature 006 - Recursos multimodais

Registre aqui somente decisões de escopo, produto, arquitetura ou execução que
valem para esta feature. Decisões transversais pertencem a
[`docs/decisions.md`](../../decisions.md).

## Decisões vigentes

| ID | Decisão | Contexto e impacto | Data |
|---|---|---|---|
| FD-009 | A transcrição (`transcribe_audio`) e a extração (`extract_record`) são **duas chamadas de IA separadas** — o `/transcribe` devolve o texto, o app chama o `/ingest` com ele. | FD-001: "quando errar, é preciso saber qual etapa falhou". Duas chamadas = dois `ai_usage`, custo e latência atribuídos à etapa certa. | 2026-08-24 |
| FD-010 | O áudio vai **inline** (`inline_data` base64) na chamada Gemini, com `mime_type` fechado e **teto de bytes** na borda. | O Storage assinado viria numa fase posterior; inline mantém a chave no backend e evita upload extra. O teto protege o tier gratuito. | 2026-08-24 |

## Modelo de decisão

### FD-NNN - Título objetivo

- **Data:** AAAA-MM-DD
- **Contexto:** problema ou oportunidade que exigiu a decisão.
- **Alternativas:** opções consideradas e suas concessões.
- **Decisão:** escolha feita e responsável.
