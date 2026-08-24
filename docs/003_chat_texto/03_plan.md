# 003 - Chat de texto e confirmação · Plano

Fatiamento e execução. O "o quê" está em [`02_specs.md`](02_specs.md), o
contrato do pronto em [`01_prd.md`](01_prd.md), as decisões desta feature em
[`decisions.md`](decisions.md), os desvios em [`changes.md`](changes.md), e o
item canônico está no [`docs/roadmap.md`](../roadmap.md). **Este plano não
inventa escopo: ele distribui o DoD entre as fases e acrescenta o que falta
para cada fase se sustentar sozinha.**

Estado: **em andamento** — Fase 1 (`/ingest`) mergeada · a 002 entregou o
pipeline `_shared/` e as tabelas que esta feature consome · **próximo passo:
Fase 2 — chat no app (`chat_module`).**

---

## Gauntlet

**Referência:** [`01_prd.md`](01_prd.md), [`02_specs.md`](02_specs.md),
[`decisions.md`](decisions.md), [`changes.md`](changes.md), este plano,
`CLAUDE.md` e as decisões transversais em [`docs/decisions.md`](../decisions.md).

**Rubrica binária:** cada fase só passa quando contrato/DoD, arquitetura,
invariantes de produto, segurança e evidência aplicável estiverem `pass`.
Resultado subjetivo, impressão geral ou nota não são critérios de aprovação.

**Invariantes bloqueantes:** nenhuma gravação sem confirmação explícita (a
ingestão grava só em `proposed_actions`); extração devolve **lista**, nunca
objeto único; dinheiro em centavos inteiros; função com JWT do usuário; toda
chamada de IA grava custo e latência em `ai_usage`; nenhuma credencial no
cliente.

**Provas:** cada crítico devolve `pass` ou `fail`, evidência reproduzível,
arquivo/linha e ação corretiva. QA executa os comandos; CISO e crítico
integrador revisam sem editar a fatia implementada. A cada tarefa concluída, o
`supervisor-dod` julga o bloco DoD daquela tarefa, cego ao plano.

**Limites:** no máximo 3 rodadas e 45 minutos **por fase**. No nível da tarefa,
duas devoluções `NÃO CUMPRIDO` e a terceira escala ao humano; `DOD INVÁLIDO`
volta ao tech-lead, não reprova a tarefa e não consome essa cota. Depois de
consolidar tarefas paralelas, o crítico integrador revisa as dependências
cruzadas antes do fechamento.

**Evidência E2E:** fica em `e2e/round_NN/`. Cada `report.md` liga cada passo a
um print, log ou saída de comando. O E2E roda somente contra a stack local, por
`patrol test`.

---

## 1. Decisões travadas antes de começar

As decisões desta feature moram em [`decisions.md`](decisions.md). As três
invariantes obrigatórias da `docs/decisions.md` Fase 1 — (a) ingestão não grava
na tabela final, (b) extração devolve lista, (c) posse de `area_id` validada —
são a régua desta feature inteira.

---

## 2. Âncoras no código existente

**App (`app/lib/`)** — gabarito `transactions_module`: domain puro, data com
zard, presentation com Cubit + estado `sealed`, barrel público só rota + DI. A
tela de chat **não existe**; o item de drawer `/chat` já está gated (002,
`app/lib/app_shell.dart`).

**Backend (`supabase/functions/`)** — `transactions/` é o gabarito de função
(`index.ts` só `Deno.serve(handler)`); `_shared/ai/` tem `parseProposals`,
`writeProposals`, `confirmProposal`, `assertWithinLimits`, `buildEnvelope`,
`logAiEvent`. A task `check` do `deno.json` lista os arquivos um a um — os novos
entram nela.

**Banco (`supabase/migrations/`)** — `0010` (messages/proposed_actions) e `0011`
(ai_*) já existem. **Nenhuma migration nova** nesta feature, salvo se a
`category_hints` precisar de tabela (a `categories` ainda não existe — decisão
da Fase 4).

**CI (`.github/workflows/ci.yml`)** — jobs `changes`, `app`, `functions`,
`migrations`, `harness`, disparados por paths-filter.

---

## 3. Contrato fechado

`POST /functions/v1/ingest` com `{ "content": "string (1..4000)" }` e o JWT do
usuário devolve `200 { "proposals": [...] }`. O fluxo está no `02_specs.md` §2.
`confirmProposal` já existe na 002; esta feature o expõe como endpoint.

---

## 4. Ritual de fechamento de fase (vale para todas)

1. O especialista dono implementa; a cada tarefa concluída, o `supervisor-dod`
   julga o bloco DoD daquela tarefa.
2. **QA roda `revisar-fase`** contra este plano e as regras do `CLAUDE.md`.
3. **CISO revisa o diff** da fase (sem `Write` — aponta, não conserta).
4. **`fechar-etapa` roda o DoD da fase, linha por linha, de verdade.** Só então:
   PR com o DoD no corpo e o resultado de cada linha → CI verde → merge em
   `develop` → próxima fase.

`CHANGELOG.md` (seção `Unreleased`) é atualizado **no mesmo PR** da mudança, em
toda fase.

---

## 5. Fases

### Fase 1 — Edge Function `/ingest` · PR 1

Branch: `feature/GZ-37-ingest`. Primeiro porque é a fonte da interpretação: sem
ela o app não tem o que mostrar. Se sustenta sozinha porque entrega o endpoint
com os testes, reutilizando o pipeline da 002.

**Tarefas**

- [x] **T1.1** — Criar `supabase/functions/ingest/index.ts` (só `Deno.serve(handler)`) e `supabase/functions/ingest/handler.ts` que valida `content` na borda (não-vazio, ≤ 4000), resolve a rota em `ai_routes`, monta o envelope com `buildEnvelope`, chama `assertWithinLimits`, grava `ai_usage` via `logAiEvent` e devolve `200 { proposals }` ou o erro correspondente. · camada **backend** · `especialista-backend` · **DoD: CUMPRIDO**

  **DoD da tarefa**
  - `supabase/functions/ingest/index.ts` contém só `Deno.serve(handler)` e a importação de `handler.ts`; `deno check supabase/functions/ingest/index.ts supabase/functions/ingest/handler.ts` sai `0`.
  - `content` vazio ou acima de 4000 devolve `400 { code: 'content_invalido' }` antes de qualquer chamada à IA — provado por `supabase/functions/ingest/handler_test.ts` com `fetch` stubado, e o teste **falha sem a validação** (remover o guard faz o caso falhar).
  - O handler usa `parseProposals` + `writeProposals` de `_shared/ai/` e **não** importa nada de `transactions/`; `rtk proxy grep -cE "from\\('transactions'" supabase/functions/ingest/handler.ts` imprime `0`, e a camada de IA (`supabase/functions/_shared/ai/*.ts` e `_shared/observability/*.ts`) não alcança `Deno.env`: `grep -cE "Deno\\.env" supabase/functions/_shared/ai/*.ts supabase/functions/_shared/observability/*.ts` devolve `0` em todos.
  - A chamada à IA passa por `assertWithinLimits` e o resultado grava `ai_usage` (custo/latência/sha256) — o teste com o provedor fake assere a linha em `ai_usage` e a ausência do conteúdo no log.
  - `deno fmt --check`, `deno lint` e `deno task check` saem `0` com o `ingest` na task `check` do `deno.json`.

**DoD da Fase 1**

- [x] `cd supabase/functions && deno task test` verde — 69 testes, incluindo os 5 de `ingest/handler_test.ts`.
- [x] A validação de `content` (vazio e > 4000 → `400 content_invalido`) falha sem o guard — mutação vista vermelha e restaurada, provada por `ingest/handler_test.ts` com `fetch` stubado. *Ressalva do PR #40:* o `curl` contra `/functions/v1/ingest` com JWT real não rodou (o sandbox não sobe a stack Supabase completa); o caminho está provado por teste.
- [x] Job "Edge Functions" verde no CI do PR.

---

### Fase 2 — Chat no app · PR 2

Branch: `feature/GZ-38-chat-app`. O placeholder da 002 vira a tela real: nasce o
`chat_module` (domain puro, data via `functions.invoke('ingest')`, presentation
com Cubit + estado `sealed`), o barrel público expõe só rota + DI, e o item de
drawer `/chat` — já gated em 002 — agora chega numa tela que envia a mensagem e
mostra os cards de proposta.

**Tarefas**

- [x] **T2.1** — Criar o `chat_module` completo: `domain/` (`ChatProposal`,
  `ChatRepository`, `IngestMessage`), `data/` (`ChatRepositoryImpl` via
  `functions.invoke('ingest')`), `presentation/` (`ChatCubit` + estado `sealed`,
  `ChatPage`, `ChatComposer`, `ChatProposalCard`), `chat_injection.dart` e o
  barrel público (`chat_module.dart`) só com rota + DI; registrar em
  `app/lib/injection.dart`. · camada **app** · `especialista-apresentacao` +
  `especialista-dados` · **DoD: CUMPRIDO**

  **DoD da tarefa**
  - `app/test/modules/chat_module/presentation/chat/chat_page_test.dart` passa e **falha sem a mudança**: voltando a `ChatPage` ao placeholder da 002 (sem `ChatComposer`/`ChatProposalCard`), o caso "enviar mostra os cards de proposta retornados" falha.
  - O mesmo arquivo prova o estado `ChatSending` visível: com o use case pendente, o `FilledButton` "Enviar" tem `onPressed` nulo (caso "botão de enviar desabilitado durante o envio"), e **falha sem o `ChatSending`** no `switch` do `chat_page.dart`.
  - `cd app && flutter analyze` sai `0`; `cd app && dart format --output=none --set-exit-if-changed .` sai `0`; `bash scripts/gates_guard.sh` imprime "limpos em app/lib".
  - O domínio é Dart puro e a apresentação não alcança `data/`: `rtk proxy grep -rE "flutter|supabase|dio" app/lib/modules/chat_module/domain` e `rtk proxy grep -rE "modules/chat_module/data" app/lib/modules/chat_module/presentation` devolvem `0`.
  - O repositório fala só com o Supabase (`_client.functions.invoke('ingest', body: {'content': content})`) e nenhum cliente de API externa existe no app: `rtk proxy grep -rE "gemini|pluggy|google" app/lib` devolve `0`.
  - `app/lib/modules/chat_module/chat_module.dart` contém exatamente `export 'chat_injection.dart';` e `export 'chat_routes.dart';` — o barrel público expõe só rota + DI.

**DoD da Fase 2**

- [x] `cd app && flutter test -r compact` verde — **120 testes**, incluindo os 2 de `chat_page_test.dart`.
- [x] `cd app && flutter analyze` sai `0`; `dart format --output=none --set-exit-if-changed .` sai `0`.
- [x] Job "App" verde no CI do PR.

---

### Fase 3 — Confirmação · PR 3

Endpoint de confirmação + card confirmar/cancelar + refetch.

### Fase 4 — `category_hints` · PR 4

Correção de categoria do usuário vira lookup na próxima ingestão.

### Fase 5 — Bateria automatizada e fechamento · PR 5

Testes unit + widget + golden, docs vivas, fechamento.

---

## 6. Rastreabilidade — as linhas do DoD do roadmap

| # | Linha do DoD do roadmap | Fase que fecha |
|---|---|---|
| 1 | `/ingest` com IA abstraída (`ai_providers`/`ai_routes`/`ai_usage`) | **1** |
| 2 | Classificação de intenção (`create` · `attach` · `query`) | **1** |
| 3 | Extração devolvendo lista, gravada em `proposed_actions` | **1** |
| 4 | Cards de confirmação em sequência, não editáveis, data explícita | **2** e **3** |
| 5 | `category_hints` — correção vira lookup | **4** |

---

## 7. Riscos e dependências que o DoD do roadmap não cobre

| # | Risco | Onde dói | Tratamento neste plano |
|---|---|---|---|
| X1 | A IA responder malformado | Fase 1 | `parseProposals` rejeita (já testado na 002) |
| X2 | Custo do tier gratuito | Fase 1 | `assertWithinLimits` antes de toda chamada |
| X3 | Card plausível de texto de terceiro | Fase 2/3 | procedência (`origin`) no card + confirmação |

---

## 8. Progresso

Legenda das fases: `[ ]` não iniciada · `[-]` em andamento · `[x]` mergeada em
`develop`. Na linha de **tarefa**, `[x]` significa o veredito `CUMPRIDO` do
`supervisor-dod`, no campo `DoD:` da própria linha.

- [x] **Fase 1** — Edge Function `/ingest` · PR 1
- [-] **Fase 2** — Chat no app · PR 2
- [ ] **Fase 3** — Confirmação · PR 3
- [ ] **Fase 4** — `category_hints` · PR 4
- [ ] **Fase 5** — Bateria automatizada e fechamento · PR 5
