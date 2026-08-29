# RETOMADA

- **Item em curso**: **007 - Agenda e Google Calendar** — Fase 1 (schema seguro) **fechada e mergeada**; T1.1 `CUMPRIDO`. Próxima é a Fase 2.
- **Branch / PR**: nenhum aberto da 007. PR #56 **mergeado** em `develop` (CI inteiro verde); a branch da fase foi apagada.
- **Último gate/veredito**: DoD da **fase** verificado rodando antes do merge — teste de banco exit 0 com 15 asserções, e falha-sem-a-mudança comprovada removendo o `cron.schedule`. Cancela de máquina: 212 testes do app e 159 do Deno verdes.
- **Primeira ação da retomada**: abrir a **Fase 2** — despachar o `auditor-de-criterios` sobre os blocos DoD de T2.1 e T2.2 em `docs/007_agenda/03_plan.md` antes de qualquer execução; T2.1 e T2.2 são `[paralela]` e pedem worktree própria cada.
- **Depois**: Fase 3 (agenda e cards no Flutter) e Fase 4 (bateria, docs, fechamento).
- **Pendências do humano**: **P1** — projeto Google Cloud, consent screen, redirect HTTPS e conta de teste. Bloqueia **apenas** a prova real contra o Google; as fases 2 e 3 seguem com stub.
- **Aprendizado de processo (vale para a Fase 2)**: comando `rg -P` em bloco DoD precisa de `-U` quando o padrão cruza linhas, caminho a partir da raiz do repo (nunca `$HOME`), e escape triplo (`\\\$`) para casar `$` literal — três `DOD INVÁLIDO` de T1.1 saíram disso. Ver a linha da T1.1 e o `CHG-002`.
- **Fios soltos (pré-007)**: `chore/GZ-34-hooks-formato` com 1 commit não integrado (worktree `.claude/worktrees/wt-hooks`, limpa); worktree `.claude/worktrees/wt-lint` com 1 arquivo modificado. Decidir integrar ou descartar.
- **Ponteiros**: `docs/007_agenda/03_plan.md` (Fase 2 em diante) · `docs/007_agenda/changes.md` (CHG-001, CHG-002) · `docs/007_agenda/decisions.md` · `supabase/tests/0017_vinculo_google_calendar.sql` (gabarito de teste de banco) · `docs/decisions.md` (D34 tira o E2E do escopo automatizado e o devolve ao humano; D37 goldens sem relógio).
