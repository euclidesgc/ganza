# 003 - Chat de texto e confirmação · Specs

Âncoras no código existente e contratos desta feature. O "o quê" está no
[`01_prd.md`](01_prd.md); o fatiamento, no [`03_plan.md`](03_plan.md).

## 1. O que já existe e se reutiliza (não reinventar)

- **Pipeline defensivo** em `supabase/functions/_shared/`: `ai/prompt_envelope.ts`
  (instrução separada do dado, saneamento, tetos), `ai/proposal_schema.ts`
  (`parseProposals`, conjunto fechado), `ai/proposal_writer.ts`
  (`writeProposals`/`confirmProposal`), `ai/normalize_description.ts`,
  `ai/limits.ts` (`assertWithinLimits`), `observability/ai_event.ts`
  (`logAiEvent`/`hashContent`). **Tudo testado na 002**.
- **Tabelas** `public.messages` (com `origin`), `public.proposed_actions`,
  `public.ai_providers`/`ai_routes`/`ai_usage`, `public.transactions` — com RLS
  e política de dono. O `/ingest` escreve em `messages` e `proposed_actions`;
  a confirmação migra para `transactions`.
- **Configuração de IA** (chave no Vault, gating do item de chat) entregue na 002.
- **Gabarito de Edge Function**: `supabase/functions/transactions/` (`index.ts` só
  `Deno.serve(handler)`, `handler.ts` exportado, `index_test.ts`/`handler_test.ts`).
- **Módulo Flutter**: gabarito `areas_module`/`transactions_module` — domain puro,
  data com zard, presentation com Cubit, barrel público só rota + DI.

## 2. Contrato do `/ingest`

```
POST /functions/v1/ingest
Authorization: Bearer <jwt do usuário>
{ "content": "string (1..4000)" }
→ 200 { "proposals": [ { "id", "kind", "payload", "sequence" }, ... ] }
```

- Valida `content` na borda (não-vazio, ≤ 4000) — predicado à mão, sem zod.
- Chama `assertWithinLimits` antes de qualquer chamada à IA (413/429).
- Resolve a rota em `ai_routes` por `task_type`; monta o envelope e chama o
  provedor; grava `ai_usage` (custo/latência/sha256) via `logAiEvent`.
- `parseProposals` + `writeProposals` gravam em `proposed_actions` (nunca na
  tabela final). A confirmação é um endpoint **separado** (`confirmProposal`).

## 3. Contrato do app

- `chat_module` (novo): `presentation/chat/` com a tela do chat (campo de texto,
  lista de cards), `ChatCubit`, rotas `/chat`. O item do drawer já existe e está
  gated (002).
- A tela **envia** para o `/ingest` e **lista** os cards pendentes; confirmar
  chama o endpoint de confirmação e refaz a leitura pelo PostgREST (mesmo padrão
  da `transactions_list`).
- Card **não editável**: confirmar ou cancelar, sem campo de texto.

## 4. Fluxo de dados

```
mensagem → /ingest → classify_intent → extract_record → parseProposals
         → writeProposals (proposed_actions, pending) → cards
card confirmado → confirmProposal → revalida → transactions
card cancelado → status = 'cancelled'
```

## 5. Invariantes que o DoD cobra (da `docs/decisions.md` Fase 1)

1. A ingestão **não grava** na tabela final, só em `proposed_actions`.
2. A extração devolve **lista** — mensagem que gera dois registros.
3. Quem preencher `transactions.area_id` prova a posse da área (FK não respeita
   RLS — D13): tentativa com `area_id` alheio recusada.

## 6. Riscos

- **IA alucinando** → conjunto fechado de `kind`/campos + teto de `amount`.
- **Custo** → `limits.ts` (teto de chamadas/custo) + `ai_usage`.
- **Injeção de instrução** → envelope + `proposal_schema` (já provado na 002).
