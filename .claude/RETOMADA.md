# RETOMADA

- **Item em curso**: **007 - Agenda e Google Calendar** — Fase 1 (schema seguro) fechada e mergeada (T1.1 `CUMPRIDO`). A próxima é a **Fase 2 — OAuth, leitura e confirmação backend**, com T2.1, T2.2 e T2.3 ainda `[ ]`.
- **Branch / PR**: nenhum aberto. `develop` limpa e sincronizada; o repositório tem só `develop` e `main`, sem worktrees e sem branch órfã.
- **Último gate/veredito**: faxina geral mergeada pelos PRs #59 e #61, CI inteiro verde — 212 testes do app, 159 do Deno, `gates_guard`, `verify-gauntlet` e `lint-dod` em `exit=0`.
- **Primeira ação da retomada**: despachar o `auditor-de-criterios` sobre os blocos DoD de T2.1 e T2.2 em `docs/007_agenda/03_plan.md` antes de qualquer execução. As duas são `[paralela]` e pedem worktree própria cada.
- **Depois**: T2.3 (sequencial, depende das duas), então Fase 3 (agenda e cards no Flutter) e Fase 4 (bateria, docs, fechamento).
- **Ferramenta nova, use antes de despachar**: `bash scripts/lint-dod.sh docs/007_agenda/03_plan.md` acusa por máquina os defeitos de critério que custaram três `DOD INVÁLIDO` na Fase 1. Hoje sai `exit=0`; rode de novo a cada bloco DoD novo que escrever. `--run <plano> <ID>` executa os spans de uma tarefa sem julgar.
- **Pendências do humano**: **P1** — projeto Google Cloud, consent screen, redirect HTTPS e conta de teste; bloqueia só a prova real contra o Google, as Fases 2 e 3 seguem com stub. **P9** — onde entra a UI de conciliação e de importação OFX (a 005 está `[x]` com duas Edge Functions sem nenhum chamador). **P10** — a biometria fica ou sai: entrou contra um não-objetivo escrito do PRD da 002, sem PRD, plano ou roadmap.
- **Ponteiros**: `docs/007_agenda/03_plan.md` (Fase 2 em diante) · `docs/007_agenda/changes.md` (CHG-001, CHG-002) · `docs/007_agenda/decisions.md` · `supabase/tests/0017_vinculo_google_calendar.sql` (gabarito de teste de banco) · `docs/decisions.md` (D34 revisada, D37 goldens sem relógio, D38 funções sem consumidor).
