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
- `scripts/apply-migrations.sh` — aplicação de migrations no banco de produção, que até aqui não tinha caminho nenhum: o CI só provava que elas aplicam num Postgres descartável. Controle em `supabase_migrations.schema_migrations`, descoberta lendo o diretório, `--baseline` para registrar sem reexecutar o que já foi aplicado à mão, transação por arquivo, e recusa de rodar sem alvo explícito (`--local`/`--prod`) — `--prod --apply` ainda exige confirmação digitada.
- Terceiro gate do job "Banco": política que chama `auth.<função>()` ou `current_setting()` fora de um `select` reprova o CI. O gate descobre as funções do schema `auth` em `pg_proc` em vez de procurar o texto `auth.uid()`, porque o Postgres normaliza a expressão removendo o prefixo do schema — um gate literal ficaria verde para sempre.
- Fontes **Fraunces** e **IBM Plex Sans** em `app/assets/fonts/` (variable, licença SIL OFL incluída). Fecha a pendência P5: sem os arquivos, o app caía no fallback do sistema e os algarismos tabulares não valiam — o requisito que impede a coluna de valores de dançar entre linhas.

### Fixed

- O stand-in de `auth.uid()` do CI (`supabase/ci-bootstrap.sql`) lia `request.jwt.claim.sub`, chave escalar que o GoTrue **não** usa: toda prova de RLS rodava contra uma função diferente da de produção. Passou a ler a forma real (`request.jwt.claims ->> 'sub'`), mantendo a antiga como fallback e devolvendo NULL — sem lançar — quando o JSON é inválido.
- As políticas `profiles_owner`, `areas_owner` e `transactions_owner` chamavam `auth.uid()` de forma que o Postgres reavaliava a função **para cada linha** — o lint "Auth RLS Initialization Plan", acusado pelo advisor do Supabase. `0005_otimizar_politicas_rls.sql` recria as três com `(select auth.uid())` no `using` e no `with check`; o `EXPLAIN` passou a mostrar `InitPlan`. Irrelevante com quatro linhas, decisivo quando o extrato bancário entrar na Fase 3.

### Removed

- `API_BASE_URL` do app (`AppConfig`, `dio_factory` e os `config/*.json`): apontava para `api.ganza.bmjtech.duckdns.org`, o backend NestJS separado que a decisão **D10** revogou. O domínio não existe e a lógica de servidor mora nas Edge Functions do próprio Supabase.
