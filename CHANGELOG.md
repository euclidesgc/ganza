# Changelog

Formato: [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/). Versionamento: [SemVer](https://semver.org/lang/pt-BR/).

A seção `Unreleased` é atualizada **no mesmo PR** da mudança; o `release/*` a promove para a versão.

## [Unreleased]

### Added

- Harness do projeto: `CLAUDE.md`, time de agentes em `.claude/agents/`, skills em `.claude/skills/`, `docs/GITFLOW.md`, `docs/roadmap.md`, `scripts/gates_guard.sh` e o `ci.yml` com gate de RLS nas migrations.
- Hook `pre-push` (`scripts/git-hooks/`) barrando push direto em `main`/`develop` — a proteção de branch do GitHub não está disponível em repositório privado no plano gratuito.
