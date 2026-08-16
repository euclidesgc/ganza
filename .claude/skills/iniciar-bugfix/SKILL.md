---
name: iniciar-bugfix
description: Abre um bugfix no GitFlow do ganza — correção de bug encontrado EM DESENVOLVIMENTO (ainda não em produção). Branch de develop → PR para develop. Para bug já publicado, use iniciar-hotfix. Fonte: docs/GITFLOW.md.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Skill: iniciar um bugfix

Objetivo: corrigir um bug que está **em desenvolvimento** (ainda não chegou à produção). O fluxo é o da feature, com o prefixo `bugfix/` — base e destino são `develop`. (Bug já em produção = `iniciar-hotfix`.)

> **Enquanto `hml` não existir** (ver `docs/GITFLOW.md` §4), "valide em homologação" significa validar no ambiente **local** — o merge em `develop` continua obrigatório; muda só onde se olha o resultado.


Passos:
1. Parta de `develop` atualizado: `git switch develop && git pull --ff-only origin develop`.
2. Crie o branch: `git switch -c bugfix/<issue>-<slug>` (ex.: `bugfix/GZ-9-card-nao-confirma`).
3. Reproduza o bug primeiro (de preferência com um teste que falha), então corrija. `flutter analyze` verde e testes passando.
4. Atualize o **CHANGELOG** (`Unreleased`, em `### Fixed`).
5. Traga a base (`git merge --no-edit origin/develop`), rode a cancela local.
6. Abra o PR para `develop`: `gh pr create --base develop --fill`. CI verde + revisão → merge → auto-deploy em **homologação**.
7. Valide na URL de hml; delete o branch.

Regras inegociáveis:
- Se o bug estiver num `release/*` aberto (em estabilização), o `bugfix/*` sai e volta **para esse `release/*`**, não para `develop` — veja `docs/GITFLOW.md`.
- Sem push direto em `main`/`develop`; nada de declarar pronto com CI vermelha.
