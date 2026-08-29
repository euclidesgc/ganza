---
name: empilhar-prs
description: Publica vários PRs simultâneos do ganza como uma pilha (stacked pull requests do GitHub), em vez de PRs independentes contra develop — um build por pilha, e o merge do fundo leva os de baixo junto. Use sempre que o trabalho render mais de um PR aberto ao mesmo tempo. Fonte: docs/GITFLOW.md § 6.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Skill: empilhar PRs

Objetivo: publicar **mais de um PR simultâneo** como pilha. A regra e o porquê estão em
`docs/GITFLOW.md` § 6; aqui está a execução.

**Quando usar:** sempre que houver mais de um PR aberto ao mesmo tempo. Um PR sozinho não
precisa de pilha.

**Ordem da pilha:** de baixo (mais perto de `develop`) para cima, na ordem de dependência —
docs e refatorações de base embaixo, o que depende delas em cima.

## Passos

1. **Cada branch nasce da anterior.** Se já existirem branches soltas (criadas de
   `develop`), adote-as: `gh stack init --base develop <fundo> <meio> ... <topo>`.
   PRs já abertos são **reaproveitados** — as bases são reapontadas, nada é recriado.
2. **Encadeie de fato:** `gh stack rebase`. Rebaseia cada branch sobre a anterior. Confira
   com `gh stack view` — o `⚠` some quando a branch está no lugar certo.
3. **Rode a cancela no topo, uma vez.** O topo contém todos os commits da pilha, então
   `flutter analyze` + `flutter test -r compact` ali cobrem o conjunto.
4. **Publique:** `gh stack submit`.
5. **Tire do rascunho:** `gh stack submit` cria os PRs novos em **draft**. `gh pr ready
   <n>` em cada um, senão o humano não consegue mergear.
6. **Escreva o corpo de cada PR.** O `submit` usa a mensagem de commit; PR que nasce da
   pilha merece o mesmo corpo que um PR aberto à mão.
7. **Confira o CI dos PRs do meio.** Se algum tiver **só** o GitGuardian, a base usa um
   prefixo que falta no filtro `on.pull_request.branches` do `.github/workflows/ci.yml` —
   acrescente o prefixo **no commit do fundo da pilha**, e a correção vale para os de cima.

## Merge (é do agente, desde 21/08/2026)

**Com unit, widget e golden verdes, o DoD da fase verificado rodando e a cancela
de máquina limpa, quem mergeia é o agente** — sem esperar aprovação. Mergeie o
PR escolhido e a pilha leva junto todos os não-mergeados abaixo dele, numa
operação só. **Depois do merge, no mesmo movimento:** apague as branches que
entraram, local e remotamente, e remova os worktrees da fase. Branch órfã e
worktree sobrevivente viram pendência silenciosa.

O que continua sendo do humano é o **E2E**, que ele roda quando quer revisar de
fato — não é etapa do fluxo nem pré-requisito de merge.

Vá ao **PR não-mergeado mais baixo**, confirme que ele e os de baixo estão verdes e
aprovados, e mergeie: os de baixo entram junto, numa operação só. O próximo PR é rebaseado
automaticamente para a base da pilha.

## Iterando depois de publicada

- Commitou em alguma branch do meio: `gh stack rebase && gh stack submit`.
- Navegar: `gh stack bottom` / `up` / `down` / `top` / `switch`.
- Branch nova no topo: `gh stack add <branch>`.

## Restrições

Sem auto-merge. Não dá para mergear um PR do meio isoladamente. A pilha exige histórico
linear. Recurso em public preview.
