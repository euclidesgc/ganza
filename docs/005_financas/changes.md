# Histórico de mudanças - Feature 005 - Finanças e conciliação

Este arquivo é append-only. Registre uma entrada antes de mudar a implementação
ou os documentos canônicos por causa de um desvio descoberto após o início da
feature.

## Mudanças registradas

### CHG-001 - A Fase 4 entrega o OFX; faturas, cartão-benefício e correção ficam para depois

- **Data:** 2026-08-24
- **Fase/PR:** Fase 4.
- **Planejado originalmente:** "Pluggy/OFX (FD-021), faturas de cartão, cartão-benefício, telas de correção e fechamento".
- **Por que não foi possível prosseguir:** a Fase 4 acumulava três superfícies grandes (importação de extrato, faturas de cartão e telas de correção) num PR só, quando o núcleo do objetivo — "obter meus dados bancários" — é servido pela importação de extrato sozinha.
- **Alternativas consideradas:** (a) manter o escopo original e abrir um PR gigante; (b) entregar o OFX + fechamento e adiar faturas/cartão-benefício/correção.
- **Decisão tomada:** (b). A Fase 4 entrega o parser OFX + `/import-ofx` + fechamento; faturas de cartão, cartão-benefício e telas de correção entram numa fase posterior (registrado no PRD §5).
- **Resumo da resolução:** o "obter dados bancários" fica completo e o conciliador da Fase 3 passa a ter movimento real para casar.
- **Reconciliação documental:** `01_prd.md` §5 e `03_plan.md` Fase 4 neste arquivo.

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
