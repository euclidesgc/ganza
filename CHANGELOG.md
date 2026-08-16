# Changelog

Formato: [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/). Versionamento: [SemVer](https://semver.org/lang/pt-BR/).

A seção `Unreleased` é atualizada **no mesmo PR** da mudança; o `release/*` a promove para a versão.

## [Unreleased]

### Added

- Harness do projeto: `CLAUDE.md`, time de agentes em `.claude/agents/`, skills em `.claude/skills/`, `docs/GITFLOW.md`, `docs/roadmap.md`, `scripts/gates_guard.sh` e o `ci.yml` com gate de RLS nas migrations.
- Hook `pre-push` (`scripts/git-hooks/`) barrando push direto em `main`/`develop` — a proteção de branch do GitHub não está disponível em repositório privado no plano gratuito.
- Primeiras migrations: extensões (`pgcrypto`, `pg_cron`, `pg_net`, `supabase_vault`), `profiles` e `areas` com RLS e política, e o trigger que cria perfil e as quatro áreas padrão no signup.
- CI de banco passou a rodar contra `supabase/postgres` (a imagem de produção) e ganhou o gate de "toda tabela com RLS tem política".
- App Flutter (Android e Web) com flavors, quatro redes de erro, `Failure` selada, tradutor único de exceção e o design system da identidade do plano §11.
- Autenticação pelo Supabase com guarda de rota por sessão, e listagem das áreas do usuário validada por schema.
