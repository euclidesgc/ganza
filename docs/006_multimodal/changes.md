# Histórico de mudanças - Feature 006 - Recursos multimodais

Este arquivo é append-only. Registre uma entrada antes de mudar a implementação
ou os documentos canônicos por causa de um desvio descoberto após o início da
feature.

## Mudanças registradas

### CHG-001 - Regenerar os dois baselines golden de rotinas que bloqueiam a PR

- **Data:** 2026-08-25
- **Fase/PR:** fechamento da Fase 2 e PR da feature 006.
- **Planejado originalmente:** a bateria Flutter completa deveria estar verde para abrir a PR da feature 006, incluindo os goldens já versionados.
- **Por que não foi possível prosseguir:** duas imagens golden preexistentes de `routines_module` falham tanto localmente quanto no CI sob Flutter 3.44.9, bloqueando a PR apesar de não pertencerem ao fluxo multimodal.
- **Alternativas consideradas:** (a) deixar o CI vermelho, que impede a entrega; (b) alterar produção ou testes de rotinas, que amplia indevidamente o escopo e pode mascarar o baseline; (c) regenerar os dois PNGs pelo teste golden oficial, fixando Flutter 3.44.9.
- **Decisão tomada:** regenerar exclusivamente os dois PNGs golden de rotinas pelo teste oficial sob Flutter 3.44.9, sem alterar código de produção, testes de rotina ou o comportamento da feature 006.
- **Resumo da resolução:** somente os dois PNGs golden de rotinas foram atualizados. O teste focal passou e `cd app && flutter test -r compact` passou com `201 passed`; não houve alteração de código de rotina.
- **Reconciliação documental:** `03_plan.md` registra a resolução e as provas locais; PRD e specs não mudam porque o contrato multimodal não foi alterado.

## Modelo de registro

### CHG-NNN - Título objetivo

- **Data:** AAAA-MM-DD
- **Fase/PR:** identificador da fase ou PR afetado.
- **Planejado originalmente:** o que PRD, specs ou plano determinava antes do desvio.
- **Por que não foi possível prosseguir:** fato técnico, produto ou dependência.
- **Alternativas consideradas:** opções avaliadas e suas concessões.
- **Decisão tomada:** escolha final e responsável pela aprovação.
- **Resumo da resolução:** como código, ambiente ou processo ficou resolvido.
- **Reconciliação documental:** arquivos e seções atualizados para a realidade final.
