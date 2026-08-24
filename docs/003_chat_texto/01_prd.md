# 003 - Chat de texto e confirmação · PRD

O chat é a porta de entrada de linguagem natural do ganzá: você escreve, o
sistema interpreta e **propõe** registros em cards — nada grava sozinho. Esta
feature entrega o primeiro `/ingest` de verdade, reutilizando o pipeline
defensivo que a Fase 6 da 002 construiu (`proposal_schema`, `proposal_writer`,
`prompt_envelope`, `normalize_description`, `limits`, `ai_event`).

## 1. Resultado esperado

A pessoa abre o chat, escreve uma mensagem e recebe **uma lista de cards de
confirmação**, um por registro proposto. Ela confirma ou cancela cada um. Só o
card **confirmado** vira registro na tabela final. Uma mensagem pode gerar
vários registros ("almocei por 45 e depois paguei a conta de luz" → dois cards).

## 2. Fronteira: o que a IA interpreta e o que o código decide

| A IA interpreta | O código decide |
|---|---|
| A intenção (`create`, `attach`, `query`) e os campos de cada registro | O conjunto fechado de `kind` e de campos — rejeita o que sair dele |
| A categoria sugerida | A escrita, que passa por `parseProposals` + `proposal_writer`, atrás de confirmação |
| Nada | Juros, amortização, parcelamento — isso é `/finance-math`, nunca o modelo |

`update` **não existe no chat** (`docs/plano.md` §6.2). Corrigir é na tela do
registro, fora do chat.

## 3. Caminho feliz

1. Pessoa escreve "almocei no bar do zé, 45 reais, ontem".
2. `/ingest` monta o envelope (instrução separada do dado), chama a IA
   (`classify_intent` → `extract_record`) e grava o custo/latência em `ai_usage`.
3. A extração devolve **lista** de propostas; `proposal_writer` grava em
   `proposed_actions` com `status = 'pending'`.
4. A tela mostra os cards **em sequência, não editáveis**, cada um com descrição,
   valor e **data explícita** ("14/08, sexta"), e a **procedência** (`origin`).
5. Confirmar um card → `confirmProposal` revalida o payload lido do banco e grava
   a transação. Cancelar → `status = 'cancelled'`.

## 4. Exceções e casos de borda

- **Texto que não é registro** ("como foi meu mês?") → `query`: resposta "ainda
  não sei consultar", sem gravar nada.
- **Foto sem texto** → pergunta na hora (a imagem fica pendurada na mensagem).
- **Mensagem com vários registros** → lista de cards (teto de 10 por mensagem).
- **Texto de terceiro no mesmo prompt** (extrato, OCR, transcrição) → passa pelo
  envelope saneado; o corpus adversarial da 002 prova que nenhuma instrução
  injetada vira registro.
- **Sem IA configurada** → o item de chat fica desabilitado com o motivo visível
  (já entregue pela 002).

## 5. Analytics

- `ai_usage` grava **toda** chamada: `task_type`, provedor, modelo, `status`,
  tokens, `cost_micros`, `latency_ms`, `content_sha256` (nunca o conteúdo).
- Eventos de produto (sem dado pessoal no payload): `ingest_started`,
  `ingest_classified`, `proposal_confirmed`, `proposal_cancelled`.

## 6. Erros monitorados

- `400` (entrada fora do contrato), `401` (sessão caiu), `429` (limite/custo,
  via `limits.ts`), `500` (falha de IA/banco) — distinguíveis no log sem ler o
  corpo. A `Failure` tipada do app nunca mostra mensagem crua de exceção.
- Toda chamada de IA tem **fallback** de rota (`ai_routes.fallback_provider_id`).

## 7. Testes que cada etapa vai pedir

- **Edge Function** (`/ingest`): DTO validado na borda; a ingestão **não grava**
  na tabela final, só em `proposed_actions`; a extração devolve **lista**
  (mensagem que gera dois registros); `parseProposals`/`proposal_writer` já
  testados na 002 são reutilizados.
- **App**: cards em sequência, não editáveis, com data explícita e procedência;
  confirmar grava, cancelar não; a tela do chat não reconstrói tudo a cada tecla.
- **Invariante de posse de área**: a etapa que preencher `transactions.area_id`
  prova que a área é do usuário (FK **não** respeita RLS — D13), com tentativa de
  `area_id` alheio recusada.

## 8. Dependências e riscos

- **Depende** da 002 (configuração de IA, `ai_providers`/`ai_routes`/`ai_usage`,
  `proposed_actions`, pipeline `_shared/`).
- **Risco**: a IA alucinar campos ou valores — barrado pelo conjunto fechado e
  pelo teto de `amount` do `proposal_schema`.
- **Risco**: custo do tier gratuito — `limits.ts` já impõe teto de chamadas e de
  custo diário.
