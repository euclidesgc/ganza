# RETOMADA

- **001 e 002 — FECHADAS** (PRs #37, #38, #39 mergeados). `docs/roadmap.md`: 001 `[x]`, 002 `[x]`.
- **Item em curso**: **003 — Chat de texto e confirmação** · branch `feature/GZ-37-ingest` (de `develop`, commit `d2b7efa` com o planejamento). PRD (`01_prd.md`), specs (`02_specs.md`), plano (`03_plan.md` com Gauntlet + Fase 1 detalhada), `decisions.md` e `changes.md` criados. `verify-gauntlet.sh` verde.
- **Primeira ação da retomada**: implementar a **Fase 1 — Edge Function `/ingest`** (T1.1): `supabase/functions/ingest/{index,handler}.ts` + a camada de IA abstraída (`execute(taskType, input)` que resolve `ai_routes`/`ai_providers` e chama o provedor) + `ingest` na task `check` do `deno.json` + `handler_test.ts`. O pipeline `_shared/` (`parseProposals`, `writeProposals`, `buildEnvelope`, `assertWithinLimits`, `logAiEvent`) já está pronto na 002.
- **Ambiente**: sandbox `danger-full-access`, aprovação `never`. `deno` em `~/.deno/bin/deno`. Docker/psql OK. **Sub-agentes travam** — escrever na conversa principal.
- **Depois da 003**: 004 rotina → **005 finanças/juros/empréstimos (objetivo principal)** → 006 áudio.
- **Fios soltos**: branches `chore/GZ-32/33/34` (docs de processo não mergeadas).
- **Pendências do humano**: rotacionar o par de credenciais da Pluggy (P13).
- **Ponteiros**: `docs/003_chat_texto/03_plan.md` (Fase 1) · `supabase/functions/_shared/ai/` (pipeline pronto) · `supabase/functions/transactions/handler.ts` (gabarito de função).
