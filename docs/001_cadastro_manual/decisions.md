# Decisões da feature 001 - Cadastro manual

Estas decisões valem apenas para o cadastro manual. Decisões transversais e
pendências humanas permanecem em [`../decisions.md`](../decisions.md).

## Decisões vigentes

| ID | Decisão | Contexto e impacto | Data |
|---|---|---|---|
| A1 | `transactions.area_id` é nulável e não integra o formulário nem o payload. | Finanças é transversal a áreas; evita escolha artificial e IDOR por FK. | 2026-08-18 |
| A2 | Não há exclusão de transação nesta etapa. | Correção fica na Fase 3; a ausência é de UI, não de política RLS. | 2026-08-18 |
| A3 | Fraunces e IBM Plex Sans entram nesta feature. | Fecha a prova de algarismos tabulares exigida pela UI. | 2026-08-18 |
| A4 | A escrita usa `SupabaseClient.functions.invoke`, não `Dio`. | O cliente injeta `apikey` e JWT corretos para Kong e Edge Functions. | 2026-08-18 |
| A5 | Erros da Edge Function usam `{"error":{"code":"...","message":"..."}}`. | Roteador e handler mantêm contrato estável para a camada `data`. | 2026-08-18 |
| A6 | A home recebe só a ação de entrada para transações. | Não antecipa dashboard ou resumo financeiro. | 2026-08-18 |
| A7 | Não há PRs simultâneos nesta feature. | Cada fase depende da anterior e é revisada isoladamente. | 2026-08-18 |
| A8 | Patrol é o executor E2E Android; MCP serve apenas para exploração. | Mantém provas determinísticas no CI e adiciona automação de UI nativa. | 2026-08-18 |
| A9 | A ponte JUnit `MainActivityTest` é versionada em `androidTest`. | O CLI só orquestra; a ponte lista e executa os `patrolTest` no Android. | 2026-08-18 |
| A10 | Screenshots E2E usam `adb reverse` para `127.0.0.1`. | Mantém o frame marcado válido quando o cenário bloqueia o Supabase local. | 2026-08-18 |
| A11 | E2E usa somente Patrol, PNGs e logs, com AVD sob ownership do harness. | Elimina `integration_test` e vídeo; evita armazenamento desnecessário e impede que a limpeza encerre emulador externo. | 2026-08-18 |

## Modelo de decisão

### FD-NNN - Título objetivo

- **Data:** AAAA-MM-DD
- **Contexto:** problema ou oportunidade que exigiu a decisão.
- **Alternativas:** opções consideradas e suas concessões.
- **Decisão:** escolha feita e responsável.
- **Impacto:** arquivos, contrato, risco ou dependência afetados.
