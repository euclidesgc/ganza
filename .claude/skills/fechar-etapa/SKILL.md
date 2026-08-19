---
name: fechar-etapa
description: Verifica o DoD da fase rodando cada prova de verdade, antes de abrir o PR. Use ao terminar uma fase do 03_plan.md ou item do roadmap, com todas as tarefas já em CUMPRIDO — é o que autoriza abrir PR, mergear e passar para a próxima fase. Não use ao fim de uma tarefa; o DoD de tarefa é outro nível e quem o julga é o supervisor-dod.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, mcp__dart__run_tests, mcp__dart__analyze_files
---

# Skill: fechar uma etapa

Objetivo: transformar "acho que terminei" em "está provado". **Nenhum PR abre sem esta passagem.** A fase também precisa dos vereditos `pass` independentes de QA, CISO e, após consolidação paralela, do crítico integrador.

O que se verifica aqui é o **DoD da fase** — a etapa do `03_plan.md`, o nível que
autoriza abrir o PR. O DoD **de tarefa** é outro nível e já foi julgado pelo
`supervisor-dod` a cada tarefa concluída: o veredito está registrado na própria
linha da tarefa no `03_plan.md`, no campo `**DoD: CUMPRIDO**`, e só tarefa com
esse valor está marcada `[x]`. A porta de entrada desta passagem é conferir que
o veredito **existe** — não rejulgá-lo —, e a conferência é um comando; para a
fase `N` da feature `NNN_<nome>`:

```bash
grep -c '^- \[.\] \*\*T<N>\.' docs/NNN_<nome>/03_plan.md
grep -c '^- \[.\] \*\*T<N>\..*DoD: CUMPRIDO' docs/NNN_<nome>/03_plan.md
grep -n '^- \[.\] \*\*T<N>\.' docs/NNN_<nome>/03_plan.md | grep -v 'DoD: CUMPRIDO'
```

Os dois números — tarefas da fase e vereditos `CUMPRIDO` — têm de ser iguais, e o
terceiro comando não pode imprimir nada; o prefixo `DoD: ` existe para
`CUMPRIDO` não casar com `NÃO CUMPRIDO`. Qualquer linha impressa é tarefa por
julgar, `NÃO CUMPRIDO` ou `DOD INVÁLIDO`, e a etapa não está pronta para esta
passagem.

O ciclo do projeto é fechado e a ordem importa:

```
tarefa implementada → DoD da tarefa julgado pelo supervisor-dod → próxima tarefa
todas CUMPRIDO → DoD da fase verificado rodando → PR aberto → merge → próxima etapa
```

Sem DoD da fase atingido não se abre PR, não se mergeia, e não se começa a etapa seguinte.

**Esta passagem é gate de fase, não tarefa supervisionada.** Ela não é despachada
com bloco DoD nem passa pelo `supervisor-dod` — seria exigir `CUMPRIDO` de si
mesma antes de poder rodar.

## 1. Releia o DoD antes de rodar qualquer coisa

O DoD da fase foi escrito **antes** da implementação, no `03_plan.md` (ou no item do `docs/roadmap.md`). Releia com a pergunta certa: **cada linha ainda mede o que a etapa promete?**

Se durante a implementação você descobriu que o DoD media a coisa errada,
**isso é um desvio** — vai ao tech-lead e ao humano. Antes de mudar o DoD,
registre em `docs/NNN_<nome>/changes.md` o planejamento original, impedimento,
alternativas, decisão e resumo; depois reconcilie PRD, specs e plano e liste
esses arquivos na entrada. Reescrever o DoD sozinho, depois de ver o resultado,
é fazer a prova caber na resposta.

## 2. Rode cada linha, uma a uma

Nada de "os testes passaram, então está tudo certo". Cada linha do DoD tem um comando e um resultado esperado — execute e **cole a saída real**.

| Tipo de linha | O que verificar |
|---|---|
| **Teste automatizado** | Passa. E **falha sem a mudança**: reverta o trecho, rode o teste, veja vermelho, restaure. Teste que nunca foi visto falhar não prova nada — este projeto já teve um caso em que o CI estava verde e o serviço não subia. |
| **Saída de comando** | O comando roda e devolve exatamente o esperado. Se envolve serviço no ar, rode **contra o domínio real**, não contra `localhost`. |
| **Evidência de E2E** | O print existe em `docs/NNN_<nome>/e2e/round_MM/` e o `report.md` da rodada está completo: título `# Round MM …`, `## Contexto`, `## Passos executados` (a tabela ligando passo, comando, resultado e o PNG que o prova), `## Ambiente e comandos` — os rótulos que `bash scripts/verify-gauntlet.sh` cobra —, mais `## Rastro` e `## Limpeza no wrap`, escritos por quem instrumentou. O guard passa, e o dev humano **atestou**. |

## 3. Cheque também o que o DoD não cobre

Antes de abrir o PR, a cancela de máquina, que é o piso e não o teto:

```bash
cd app && dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test -r compact
cd supabase/functions && deno fmt --check && deno lint && deno task check && deno task test
bash scripts/gates_guard.sh && bash scripts/validar-workflows.sh && bash scripts/verify-gauntlet.sh
```

Rode escopado durante a iteração; **aqui** é o ponto de consolidação em que a suíte inteira vale a pena.

## 4. Escreva o resultado no corpo do PR

O DoD verificado é a primeira coisa que o revisor lê:

```markdown
## DoD

- [x] `deno task test` — `health degrada sem SUPABASE_DB_URL` passa; verificado que falha sem o guard
- [x] `curl https://…/functions/v1/health` → `200 {"status":"ok","database":"reachable"}`
- [x] `e2e/round_01/03-card-confirmacao.png` — card com data explícita, atestado pelo dev
```

Linha que **não** passou não vira nota de rodapé: ou a etapa não fechou, ou o
item sai do DoD com aprovação do humano e registro completo em `changes.md`.

## 5. Só então

Abre o PR → CI verde → merge → **e aí** começa a próxima etapa. Marque o item no `docs/roadmap.md` no mesmo movimento.

## Regras de ouro

- **Cada nível de DoD tem o seu juiz.** O de tarefa é do `supervisor-dod`; o da fase é desta passagem. Reverificar o nível de baixo só rende trabalho duplicado e veredito contraditório.
- **DoD é escrito antes, verificado depois.** Escrever o DoD olhando para o que já foi feito é justificar, não provar.
- **Se a etapa entrega algo que roda em servidor, o DoD tem uma linha que só passa com aquilo no ar.** CI verde com serviço fora é DoD mal escrito, não azar.
- **Cole a saída real.** "Rodei e passou" não é evidência; a saída é.
- **Uma etapa por vez.** Fechar duas juntas porque "são pequenas" tira do revisor a chance de reprovar uma.
