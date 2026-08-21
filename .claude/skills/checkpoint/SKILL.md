---
name: checkpoint
description: Escreve/sobrescreve .claude/RETOMADA.md com o estado real da sessão — item do roadmap em curso, fase/onda, branch e PR aberto (com CI), último gate/veredito, primeira ação da retomada, pendências do humano e ponteiros. Auto-invocável e também via /checkpoint. Gatilhos: fim de onda ou gate, fechamento de entrega, antes de /clear, contexto da janela principal enchendo.
allowed-tools: Read, Write, Grep, Glob, Bash
---

# Skill: checkpoint

Objetivo: `.claude/RETOMADA.md` é o que o hook `SessionStart` injeta em toda
sessão nova — inclusive a que o `/clear` abre. Se ele mentir ou estiver
desatualizado, a sessão seguinte começa desorientada, que é pior do que não
ter checkpoint nenhum. **Escreva a partir do estado real, nunca do que você
lembra ter decidido** — confira no repo antes de escrever.

## Como apurar cada campo

- **Item em curso / fase / onda**: `docs/roadmap.md` (a linha `[-]`) e o
  `03_plan.md` da feature — qual fase está em andamento, qual onda, quantas
  tarefas `CUMPRIDO`.
- **Branch / PR**: `git branch --show-current`; `gh pr list --state open
  --json number,title,baseRefName,headRefName` ou, com o número em mãos, `gh
  pr view <n> --json number,state,statusCheckRollup` para o estado real do
  CI — não deduza "deve estar verde", rode o comando.
- **Último gate/veredito**: a última linha de DoD marcada (`**DoD:
  CUMPRIDO**`) no `03_plan.md`, ou o último veredito de `fechar-etapa`/QA/CISO
  que você tiver à mão nesta sessão.
- **Primeira ação da retomada**: um passo **concreto e imediato**, executável
  sem reabrir a conversa — não "continuar a Fase 4", e sim o comando ou a
  ação exata que destrava o resto.
- **Pendências do humano**: só o que **exige** a palavra dele (conta
  externa, decisão que muda exigência, aprovação de PRD) — "nenhuma" é uma
  resposta válida e melhor que inventar uma.
- **Ponteiros**: caminhos, não conteúdo — `03_plan.md`, `decisions.md`,
  `changes.md` da feature; `docs/decisions.md` para decisões transversais
  recentes, citadas por id (`D<n>`).

## Gabarito — no máximo ~15 linhas

```markdown
# RETOMADA

- **Item em curso**: <NNN - nome> — <fase/onda>
- **Branch / PR**: <branch> → <base>, PR #<n> (<estado>, CI: <resultado real>)
- **Último gate/veredito**: <o quê, resultado>
- **Primeira ação da retomada**: <passo concreto e imediato>
- **Depois**: <o que vem em seguida, uma linha>
- **Pendências do humano**: <lista curta ou "nenhuma">
- **Ponteiros**: <caminhos, não conteúdo>
```

**O arquivo aponta, não recita.** Estado detalhado mora no repo — no
`03_plan.md`, no `decisions.md`, no corpo do PR. Se o que você tem para
escrever passar de ~20 linhas, o excesso não cabe aqui: vira uma entrada em
`changes.md`/`decisions.md`, ou uma seção no `03_plan.md`, e o campo aqui
passa a apontar para ela. Prompt de setenta linhas colado à mão era o sintoma
antigo — o arquivo existe para não repeti-lo.

## Quando escrever

Ao fim de cada onda ou gate (o `tech-manager` chama isso no fluxo), no
fechamento de uma entrega, antes de um `/clear` planejado, ou quando notar o
contexto da janela principal enchendo. Sobrescreva o arquivo inteiro — não
acumule checkpoints antigos dentro dele; o histórico já mora no `roadmap.md`,
no `03_plan.md` e no `decisions.md`.

## Protocolo de execução

- **git-safety**: proibido `git stash`, `git checkout`, `git restore`, `git reset --hard`; antes de qualquer comando destrutivo, rode `git rev-parse --show-toplevel` e pare se a árvore não for a esperada. Nunca commite — quem commita é o coordenador, salvo ordem explícita.
- **devolução**: conclusão enxuta, com caminhos completos a partir da raiz do repositório; nunca despeje diff ou log inteiro.
- **economia**: `python3 scripts/docs_index.py search|label|outline` antes de grep/read cru em docs longas; prefira `gh`/`git` para apurar estado real a deduzir da memória da conversa.
