---
name: publicar-release
description: Gera uma versão de release do ganza (o "deploy" de produção) no GitFlow — branch release/* de develop, estabiliza, PR para main com tag MINOR, auto-deploy em produção e merge de volta em develop. Conduzido por humano. Fonte: docs/GITFLOW.md.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Skill: publicar uma release (deploy de produção)

Objetivo: promover o que está em `develop` (validado em homologação) para produção. A release **só estabiliza** — não entra feature nova. Sobe a versão MINOR e volta para **`main` E `develop`**. Conduzida por humano.

Passos:
1. Garanta `develop` verde e já testado em **homologação** (`hml.ganza.duckdns.org`).
2. Parta de `develop` atualizado e crie o branch: `git switch develop && git pull && git switch -c release/v<X.Y.0>` (ex.: `release/v0.2.0`).
3. Estabilize apenas: bump da versão, ajustes finais, docs. **Sem feature nova** (isso continua em `feature/*` para a próxima).
4. Promova o **CHANGELOG**: mova `Unreleased` para a seção `v<X.Y.0>` com a data.
5. Rode a cancela local (`dart format`, `flutter analyze`, testes; backend `build`).
6. Abra o PR para `main`: `gh pr create --base main --fill`. CI verde + revisão humana → merge.
7. **Tag no merge de `main`:** `git switch main && git pull && git tag -a v<X.Y.0> -m "release v<X.Y.0>" && git push origin v<X.Y.0>`. O Coolify publica em **produção** (`ganza.duckdns.org` + `api.ganza.duckdns.org`).
8. **Regra de ouro:** faça o merge de volta em `develop`: `git switch develop && git pull && git merge --no-ff origin/main && git push`.
9. Confira produção nas URLs; delete o branch de release.

Regras inegociáveis (`docs/GITFLOW.md`):
- `release/*` nasce de `develop` e volta para **`main` e `develop`**, com **tag SemVer** (MINOR).
- `main` é protegida — só por PR + CI verde; nada de feature nova na release.
- Deploy é automático no push da branch (Coolify); esta skill cuida do **git + versão**, não do painel — a config do Coolify está em `docs/deploy/coolify.md`.
