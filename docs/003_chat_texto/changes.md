# Histórico de mudanças - Feature 003 - Chat de texto e confirmação

Este arquivo é append-only. Registre uma entrada antes de mudar a implementação
ou os documentos canônicos por causa de um desvio descoberto após o início da
feature. Depois da entrada, reconcilie PRD, specs e plano para que descrevam o
estado final, sem preservar neles uma versão obsoleta do planejamento.

## Mudanças registradas

### CHG-001 - A sugestão de categoria pelo modelo fica para depois da 003

- **Data:** 2026-08-24
- **Fase/PR:** Fase 4 (`category_hints`).
- **Planejado originalmente:** `docs/plano.md` §6.2 diz "Categoria → sempre sugerida" — o modelo propõe a categoria, e a correção grava `descrição normalizada → categoria` em `category_hints`.
- **Por que não foi possível prosseguir:** fechar a "sugestão do modelo" e o "lookup por correção" na mesma fase arrastaria duas superfícies novas (campo de categoria no contrato do modelo + resolução de nome→id) para um DoD cujo núcleo é o ciclo correção→lookup. A Fase 4 entrega o mecanismo de aprendizado; a sugestão do modelo entra quando a taxonomia já existir de verdade.
- **Alternativas consideradas:** (a) o modelo sugere a categoria e o código casa o nome com `categories` — risco de nome não-casado virar categoria criada por saída de modelo; (b) a categoria vem só do lookup, sem campo de categoria no modelo — transação sem hint nasce `category_id = null` até a primeira correção.
- **Decisão tomada:** (b) nesta fase, registrada como FD-003.
- **Resumo da resolução:** o contrato do `/ingest` não ganha campo de categoria; a resolução é determinística no caminho de confirmação (`normalize_description` → `category_hints`).
- **Reconciliação documental:** `decisions.md` (FD-003) e o plano da Fase 4 neste arquivo; `02_specs.md` §3 ganhou o contrato da resolução.

## Modelo de registro

### CHG-NNN - Título objetivo

- **Data:** AAAA-MM-DD
- **Fase/PR:** identificador da fase ou PR afetado.
- **Planejado originalmente:** o que PRD, specs ou plano determinava antes do desvio.
- **Por que não foi possível prosseguir:** fato técnico, produto ou dependência que tornou o planejamento impraticável.
- **Alternativas consideradas:** opções avaliadas e suas concessões.
- **Decisão tomada:** escolha final e responsável pela aprovação.
- **Resumo da resolução:** como código, ambiente ou processo ficou resolvido.
- **Reconciliação documental:** arquivos e seções de PRD, specs e plano atualizados para a realidade final.
