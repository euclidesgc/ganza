# RETOMADA

- **Item em curso**: 001 - Cadastro manual ponta a ponta — **Fase 5 (bateria automatizada + fechamento)** · branch `feature/GZ-18-testes-cadastro-manual` (de `develop`). Fases 1–4 mergeadas (PRs #15, #17, #19, #20).
- **T5.1 CONCLUÍDO** — gate 1 do CISO sobre o código consolidado das Fases 1–4: veredito **`pass`** (cadência padrão), fecha a ressalva do CISO da Fase 4. Achados `[BAIXO]` não bloqueantes em `03_plan.md` §7 (X9: `isValidAmount` sem teto).
- **T5.2 fatiada em 5 frentes** (`T5.2a`–`T5.2e`) no `03_plan.md`, cada uma com bloco DoD próprio: domain (use cases), data (`TransactionModel`), core (`CentsInput`/`formatMoney`/`formatTransactionDate`), cubit (`NewTransactionCubit`/`TransactionsListCubit`), widget (formulário + estado vazio). Deps presentes: `mocktail`, `bloc_test`, `zard`, `equatable`.
- **Primeira ação da retomada**: despachar o executor da bateria (uma frente por camada), coletar o resultado de cada frente e julgar pelo `supervisor-dod`.
- **Depois**: T5.5 (reescopo do E2E) + T5.4 (reconciliar `changes.md` com D34/D35) + T5.3 (`manter-docs-vivas`) · `fechar-etapa` sobre o DoD da Fase 5 · PR (pilha) → CI verde → merge · roadmap F0.9 `[x]`, P5 baixada.
- **Pendências do humano**: (1) aval na T5.5 — o reescopo do E2E altera linhas do DoD das Fases 3/4 e mexe em escopo que é dele; (2) rotacionar o par de credenciais da Pluggy — a Fase 5 da 002 fechou (PR #35), que era o marco combinado (P13); (3) GitGuardian do PR #20 já validado como falso positivo.
- **Fios soltos**: branches `chore/GZ-32-harness-pos-fase-5`, `chore/GZ-33-lint-dod` (worktree `wt-lint`) e `chore/GZ-34-hooks-formato` (worktree `wt-hooks`) — docs de processo/tooling não mergeadas. Não bloqueiam a 001; decidir se viram PR.
- **Ponteiros**: `docs/001_cadastro_manual/03_plan.md` (Fase 5 ~linha 269) · `docs/001_cadastro_manual/changes.md` · `docs/001_cadastro_manual/decisions.md` · `docs/decisions.md` (D34/D35).
