# 006 - Recursos multimodais · Plano

Fatiamento e execução. O "o quê" está em [`02_specs.md`](02_specs.md), o
contrato do pronto em [`01_prd.md`](01_prd.md), as decisões desta feature em
[`decisions.md`](decisions.md), os desvios em [`changes.md`](changes.md), e o
item canônico está no [`docs/roadmap.md`](../roadmap.md).

Estado: **pronta para PR** · branch `feature/GZ-50-transcrever` · as Fases 1 e
2 estão concluídas e validadas localmente. O CI remoto e o merge em `develop`
continuam pendentes.

---

## Gauntlet

**Referência:** [`01_prd.md`](01_prd.md), [`02_specs.md`](02_specs.md),
[`decisions.md`](decisions.md), [`changes.md`](changes.md), este plano,
`CLAUDE.md` e as decisões transversais em [`docs/decisions.md`](../decisions.md).

**Rubrica binária:** cada fase só passa quando contrato/DoD, arquitetura,
invariantes de produto, segurança e evidência aplicável estiverem `pass`.

**Invariantes bloqueantes:** transcrição e extração são `task_type` separados
(FD-001); nada grava sem confirmação (a transcrição só grava em `messages`, com
`transcript`); nenhuma credencial no cliente; toda chamada de IA grava `ai_usage`.

**Provas:** cada crítico devolve `pass`/`fail` com evidência reproduzível e
arquivo/linha. A cada tarefa concluída, o `supervisor-dod` julga o bloco DoD,
cego ao plano.

**Limites:** no máximo 3 rodadas e 45 minutos **por fase**; no nível da tarefa,
duas devoluções `NÃO CUMPRIDO` e a terceira escala ao humano.

**Evidência E2E:** está suspensa e não é pré-requisito desta feature; o escopo
automatizado é unitário, widget e golden.

---

## 1. Decisões travadas antes de começar

As decisões desta feature moram em [`decisions.md`](decisions.md). A que governa
o núcleo: transcrição é `transcribe_audio`, separada de `extract_record` (FD-001
da 003) — duas chamadas, dois `ai_usage`.

---

## 2. Âncoras no código existente

- **Backend** — `_shared/ai/execute.ts` (`resolveProvider`/`callProvider` só
  texto hoje; ganha `transcribeAudio` com áudio inline); `ingest/` é o gabarito.
- **Banco** — `ai_routes.transcribe_audio` já existe; `messages` já tem
  `media_path`/`media_type`/`transcript`.

---

## 3. Ritual de fechamento de fase (vale para todas)

`supervisor-dod` julga a tarefa → QA roda `revisar-fase` → CISO revisa o diff →
`fechar-etapa` roda o DoD → PR com DoD no corpo → CI verde → merge → próxima
fase. `CHANGELOG.md` atualizado no mesmo PR.

---

## 4. Fases

### Fase 1 — Transcrição (`/transcribe`) · PR 1

Branch: `feature/GZ-50-transcrever`. A Edge Function que transforma áudio em
texto, reutilizando a camada de IA da 002.

**Tarefas**

- [x] **T1.1** — `_shared/ai/execute.ts` ganhou `transcribeAudio(provider, audioBase64, mimeType)` (Gemini `generateContent` com `inline_data`) + teste. · camada **backend** · `especialista-backend` · **DoD: CUMPRIDO**

  **DoD da tarefa**
  - `execute_test.ts` (ou novo) prova que `transcribeAudio` monta a `inline_data` com o `mime_type`/dado correto e devolve o texto do primeiro `candidate` — **falha sem a mudança**.
  - `deno fmt --check`, `deno lint` e `deno task check` saem `0`.

- [x] **T1.2** — Edge Function `supabase/functions/transcribe/` (`POST { audio_base64, mime_type }`): valida na borda (base64 presente ≤ teto de **bytes decodificados**, mime fechado), chama `transcribe_audio`, grava a `message` (`origin='transcript'`, `media_type='audio'`, `transcript`) e o `ai_usage`, devolve `{ transcript, message_id }`; áudio sem fala retorna erro sem gravar `messages`, propostas ou transações. · camada **backend** · `especialista-backend` · **DoD: CUMPRIDO**

  **DoD da tarefa**
  - `transcribe/handler_test.ts` prova `405`/`401`/`400` (base64 ausente, inválido ou vazio; MIME fora do conjunto), `413` acima do teto de bytes decodificados, `422` para áudio sem fala e o caminho feliz (grava `messages` + `ai_usage` e devolve o transcript) — com `fetch` stubado; **falha sem a mudança**.
  - A transcrição **não** insere em `proposed_actions` nem em `transactions`: o teste assere as chamadas de `fetch`.
  - `transcribe` está em `FUNCOES_COM_SERVICE_ROLE` (precisa ler o segredo do Vault) e o `ai_usage` grava custo/latência/sha256 do áudio.
  - `deno fmt --check`, `deno lint`, `deno task check` e `deno task test` saem `0`.

**DoD da Fase 1**

- [x] `cd supabase/functions && /tmp/ganza-deno.dhMmjt/deno task test` verde, incluindo `transcribe/handler_test.ts` (`159 passed`, 2026-08-25).
- [ ] Job "Edge Functions" verde no CI do PR.

---

### Fase 2 — App: captura de áudio · PR 2

Botão de microfone no compositor do chat → grava → `/transcribe` → `/ingest` →
cards. A transcrição e a extração continuam chamadas separadas; o app não fala
com o provedor de IA.

**Tarefas**

- [x] **T2.1** — O `chat_module` inicia, para e cancela uma gravação pelo contrato de domínio, mantendo o arquivo de áudio efêmero fora do estado de apresentação. · camada **app** · `especialista-dominio` + `especialista-dados` · **DoD: CUMPRIDO**

  **DoD da tarefa**
  - Os testes unitários dos use cases de gravação provam delegação para o repositório e que cancelar descarta a gravação sem chamar `/transcribe`.
  - O contrato do repositório devolve uma gravação com Base64 e MIME válidos, sem expor API de IA ou credencial ao cliente.
  - `cd app && flutter analyze` sai `0` e os testes unitários novos saem verdes.

- [x] **T2.2** — O `ChatCubit` encadeia `recording → /transcribe → /ingest`: só envia o transcript não vazio ao pipeline de chat já existente e reaproveita a lista de cards de proposta. · camada **app** · `especialista-apresentacao` · **DoD: CUMPRIDO**

  **DoD da tarefa**
  - Teste unitário do cubit prova a ordem `stop recording` → `transcribe` → `ingest` e que o conteúdo enviado ao `/ingest` é exatamente o transcript devolvido.
  - Testes unitários provam que erro da transcrição, áudio sem fala e cancelamento não chamam `/ingest` nem alteram propostas existentes.
  - `cd app && flutter analyze` sai `0` e os testes unitários novos saem verdes.

- [x] **T2.3** — O compositor apresenta os controles de gravar/parar/cancelar e estados visíveis de envio, áudio não compreendido e falha de transcrição; no sucesso, renderiza os mesmos cards de confirmação do texto. · camada **app** · `especialista-apresentacao` · **DoD: CUMPRIDO**

  **DoD da tarefa**
  - Teste de widget exercita gravar, parar e cancelar, com controles acessíveis e sem envio de texto enquanto a gravação ou transcrição está em curso.
  - Testes de widget provam rótulos visíveis distintos para áudio sem fala e falha de transcrição, sem usar apenas cor para comunicar o erro.
  - Golden do compositor cobre os estados de gravação e erro, com fontes reais carregadas; o estado de sucesso é coberto pelo teste de widget que mostra os cards.
  - `cd app && flutter test -r compact` sai `0`, incluindo os testes unitários, de widget e goldens novos.

**DoD da Fase 2**

- [x] `cd app && flutter analyze` sai `0` (2026-08-25).
- [x] `cd app && flutter test test/modules/chat_module -r compact` sai `0` (`41 passed`), incluindo a cadeia gravação → transcrição → cards, os erros visíveis e os goldens da feature.
- [x] `cd supabase/functions && /tmp/ganza-deno.dhMmjt/deno task test` sai `0` (`159 passed`), incluindo `/transcribe`.
- [ ] `cd app && flutter test -r compact` ainda tem duas falhas golden de baseline em `routines_module`, sem relação com a feature 006; elas não são declaradas verdes nem corrigidas neste PR.
- [ ] O CI do PR está verde; após o merge, `docs/roadmap.md` muda a feature 006 para `[x]`.

---

## 5. Rastreabilidade — as linhas do DoD do roadmap

| # | Linha do DoD do roadmap | Fase que fecha |
|---|---|---|
| 1 | Áudio → transcrição (`transcribe_audio`, separado) | **1** |
| 2 | Texto transcrito entra no mesmo pipeline do chat | **2** |

---

## 6. Progresso

Legenda das fases: `[ ]` não iniciada · `[-]` em andamento · `[x]` concluída;
o merge em `develop` só ocorre após CI verde.

- [x] **Fase 1** — Transcrição (`/transcribe`) · PR 1 · testes e cancelas Deno locais concluídos; CI remoto pendente
- [x] **Fase 2** — App: captura de áudio e fechamento · PR 2 · testes locais concluídos; CI remoto pendente
