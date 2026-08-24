# Decisões da feature 005 - Finanças e conciliação

Registre aqui somente decisões de escopo, produto, arquitetura ou execução que
valem para esta feature. Decisões transversais pertencem a
[`docs/decisions.md`](../../decisions.md).

## Decisões vigentes

| ID | Decisão | Contexto e impacto | Data |
|---|---|---|---|
| FD-006 | Juros, amortização e quitação são **código determinístico** em `/finance-math`, nunca saída do modelo; dinheiro em centavos inteiros (arredondamento explícito, uma vez por linha). | `docs/plano.md` §6.6: "o número do app vai divergir do banco" por seguro/IOF/TR, então o cálculo precisa ser previsível e testável. O modelo interpreta o pedido; quem calcula é função pura testada. | 2026-08-24 |
| FD-007 | A detecção de parcelamento é **regex**, não IA: `PARC 03/12` na descrição vira compromisso sem duplicar o informado no chat (deduplicação por estabelecimento + valor da parcela + total). | §6.5: "a detecção não precisa de IA". Regex resolve a maioria, é determinístico e não consome cota de modelo. | 2026-08-24 |
| FD-008 | A sincronização bancária entra na **Fase 4**, pelo caminho **OFX/CSV** primeiro (decisão FD-021 da 002); o núcleo de juros/empréstimos (Fases 1–2) não depende dela. | O objetivo principal (analisar contas, prestações, juros e empréstimos) é servido pelo compromisso manual + `/finance-math`; a Pluggy exige conta externa do humano e é adiada sem bloquear o núcleo. | 2026-08-24 |

## Modelo de decisão

### FD-NNN - Título objetivo

- **Data:** AAAA-MM-DD
- **Contexto:** problema ou oportunidade que exigiu a decisão.
- **Alternativas:** opções consideradas e suas concessões.
- **Decisão:** escolha feita e responsável.
