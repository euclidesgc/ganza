---
name: iniciar-hotfix
description: Abre um hotfix no GitFlow do ganza — correção URGENTE de um bug já em produção. Branch de main → PR para main (com tag PATCH) → merge de volta em develop. Início é decisão humana. Fonte: docs/GITFLOW.md.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Skill: iniciar um hotfix

Objetivo: corrigir um bug **já em produção** sem arrastar o que está em construção. Nasce de `main`, volta para **`main` E `develop`**, e sobe a versão PATCH. O início é **decisão humana**.

Passos:
1. Parta de `main` atualizado: `git switch main && git pull --ff-only origin main`.
2. Crie o branch: `git switch -c hotfix/<issue>-<slug>` (ex.: `hotfix/GZ-12-notificacao-nao-dispara`).
3. Corrija o mínimo necessário (de preferência com teste que falha antes). `flutter analyze` verde e testes passando.
4. Suba a versão **PATCH** (ex.: `v0.1.0` → `v0.1.1`) e mova o CHANGELOG para a nova versão.
5. Abra o PR para `main`: `gh pr create --base main --fill`. CI verde + revisão humana → merge.
6. **Crie a tag** no merge de `main`: `git switch main && git pull && git tag -a v<X.Y.Z> -m "hotfix ..." && git push origin v<X.Y.Z>`. O Coolify publica em **produção**.
7. **Regra de ouro — não perca a correção:** traga o hotfix de volta para `develop`: `git switch develop && git pull && git merge --no-ff origin/main && git push`. Se houver um `release/*` aberto, integre **nele** em vez de `develop`.
8. Delete o branch de suporte.

Regras inegociáveis (`docs/GITFLOW.md`):
- `hotfix/*` sai de **`main`** (não de `develop`) e volta para **as duas** branches, com tag SemVer.
- `main` é protegida: a atualização é sempre por PR + CI verde.
- Só correção — nada de feature nova no hotfix.
