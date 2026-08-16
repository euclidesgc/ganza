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
- Tabela `transactions` (`0004_criar_transactions.sql`) com RLS e política de dono: valor em **centavos** (`bigint > 0`, nunca float), `direction` restrito a `in`/`out`, descrição não-vazia depois do `btrim`, `source` e `reconciliation_status` como conjuntos fechados, `user_id` com default `auth.uid()` — o dono vem da sessão, não do payload — e `area_id` nulável, para o chat associar depois sem migration nova. Índice `(user_id, occurred_at desc, created_at desc)` para a listagem.

### Fixed

- O stand-in de `auth.uid()` do CI (`supabase/ci-bootstrap.sql`) lia `request.jwt.claim.sub`, chave escalar que o GoTrue **não** usa: toda prova de RLS rodava contra uma função diferente da de produção. Passou a ler a forma real (`request.jwt.claims ->> 'sub'`), mantendo a antiga como fallback e devolvendo NULL — sem lançar — quando o JSON é inválido.
