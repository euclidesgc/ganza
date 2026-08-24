# RETOMADA

- **001 — Cadastro manual: FECHADA** (PR #37 mergeado, `docs/roadmap.md` marca `[x]`).
- **Item em curso**: 002 — **Fase 6 (Defesa do pipeline de IA)** · branch `feature/GZ-35-defesa-pipeline-ia` (de `develop`).
- **Feito nesta fase**: T6.1 + T6.2 (migrations `0010`/`0011` + `auth.role()` no `ci-bootstrap.sql`, **verificadas contra o Postgres efêmero `pg-fase6`** — 3 gates do CI verdes) e T6.3–T6.6 (módulos `_shared/` `prompt_envelope`, `proposal_schema`, `ai_event`, `normalize_description` + testes, **16 testes Deno verdes**, fmt/lint/check limpos). Commits `67ccf98` e `2466267`.
- **Falta**: T6.7 (`limits.ts`, lê `ai_usage`), T6.8 (`proposal_writer.ts` + `injection_corpus.json`, escreve `proposed_actions`), T6.9 (`decisions.md`), as **provas de falha-sem-a-mudança** (`provas/t6_*_falha_sem_a_mudanca.md`) de T6.3–T6.8, o DoD da fase, o gate do CISO e o PR.
- **Sub-agentes travam neste ambiente** (executor de flutter, frente A e frente B — todos ficaram "running" sem produzir nada). Estou escrevendo e verificando **eu mesmo** na conversa principal. Não confiar em sub-agente para este repositório.
- **Ambiente**: `deno` em `~/.deno/bin/deno` (fora do PATH); `flutter`/`dart` só com `sandbox_permissions: danger-full-access`. Postgres efêmero `pg-fase6` **de pé** (apagar ao fim da fase).
- **Depois da 002**: 003 chat → 004 rotina → **005 finanças/juros/empréstimos (objetivo principal)** → 006 áudio.
- **Pendências do humano**: rotacionar o par de credenciais da Pluggy (P13).
- **Ponteiros**: `docs/002_conta_e_configuracoes/03_plan.md` (Fase 6 ~linha 1499, DoD da fase ~linha 1730) · `docs/roadmap.md` · `docs/decisions.md` (D34/D35).
