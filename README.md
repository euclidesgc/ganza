# Ganzá

Assistente pessoal de registro. Você manda uma mensagem em linguagem natural — "gastei 45 no almoço", "banho no cachorro a cada 15 dias" — e o sistema estrutura: transação, compromisso, rotina, tarefa, nota. **Nada vira registro sem você confirmar.**

O nome vem do chocalho cilíndrico cheio de sementes do forró e do maracatu: ele não faz solo, marca o pulso por baixo de tudo. É a descrição do produto — muitos registros pequenos num recipiente só, mantendo o ritmo da semana sem disputar atenção.

> No código, no `applicationId` e na URL o nome é **`ganza`**, sem acento. "Ganzá" é só o que aparece na tela.

## Onde está o quê

| Caminho | O que é |
|---|---|
| [`docs/plano.md`](docs/plano.md) | O produto: problema, objetivos, não-objetivos, modelo de dados, fases, identidade |
| [`docs/roadmap.md`](docs/roadmap.md) | O estado: o que foi feito, o que falta, decisões travadas e pendentes |
| [`CLAUDE.md`](CLAUDE.md) | As regras de como se constrói aqui (arquitetura, gates, time de IA) |
| [`docs/GITFLOW.md`](docs/GITFLOW.md) | Branches, PRs, releases |
| `app/` | Flutter — Android e Web, mesmo `lib/` |
| `backend/` | NestJS — toda a lógica de servidor e as chaves de terceiro |
| `supabase/migrations/` | SQL versionado: schema, RLS, pg_cron |
| `infra/coolify/` | A stack self-hosted |

## Arquitetura em uma frase

O app Flutter **não fala com nenhuma API externa**. Lê do Supabase (PostgREST + RLS) e manda para o backend NestJS tudo que exige lógica — interpretar, categorizar, calcular, conciliar, sincronizar. Gemini, Pluggy, Google Calendar e FCM só existem do lado do servidor.

```
Flutter (Android/Web)
   ├── leitura ────────────→ Supabase (Postgres + RLS, Auth, Storage)
   └── escrita com lógica ─→ NestJS ──→ Gemini · Pluggy · Google Calendar · FCM
                                 ↑
                           pg_cron (pg_net)
```

## Rodando (a partir da Fase 0)

```bash
flutter run --flavor dev -t app/lib/main_dev.dart --dart-define-from-file=app/config/dev.json
```

A cancela local, antes de qualquer PR:

```bash
cd app && dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test -r compact && bash ../scripts/gates_guard.sh
```

## Trabalhando com o time de IA

O ponto de entrada é uma skill só:

```bash
/tech-manager <o que você quer>
```

Ela conduz o fluxo — PM faz o discovery, tech-lead escreve o plano, os especialistas implementam fase a fase, QA valida e instrumenta o E2E, CISO revisa. As regras estão no [`CLAUDE.md`](CLAUDE.md); o time, em `.claude/agents/`; os procedimentos, em `.claude/skills/`.

## Estado

Fase 0 — Fundação. Veja [`docs/roadmap.md`](docs/roadmap.md).
