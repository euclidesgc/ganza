# 001 - Cadastro manual ponta a ponta · Specs

Primeiro item do roadmap por feature. Fonte do "o quê": `docs/plano.md` §6.5, §6.7, §7, §11.4. Fronteira de escopo: o `01_prd.md` e o `03_plan.md`.

As decisões específicas estão em [`decisions.md`](decisions.md). O histórico
append-only de desvios e as reconciliações está em [`changes.md`](changes.md);
estas specs descrevem somente o estado final.

## 1. O que esta etapa entrega

Uma transação criada pela UI e listada pela UI, **sem nenhuma IA**. O valor da etapa não é o módulo financeiro — é provar o encanamento inteiro em um caminho real:

```
Flutter (formulário) → Edge Function /transactions → Postgres (insert)
Flutter (lista)      ← PostgREST + RLS            ← Postgres (select)
```

A escrita passa pela Edge Function porque é ali que a Fase 1 vai pendurar interpretação e categorização. A leitura vai direto pelo `supabase_flutter`, como manda o `CLAUDE.md` ("Leitura de dados do usuário não passa pelo backend").

## 2. Fora de escopo (explícito)

| Não entra | Onde entra |
|---|---|
| Qualquer chamada de IA, chat, `proposed_actions`, card de confirmação | Fase 1 |
| Categoria, `categories`, `category_hints` | Fase 1 (hints) / Fase 3 (tabela) |
| Pluggy, contas, cartões, faturas, parcelamento, financiamento, conciliação de verdade | Fase 3 |
| Compromissos, ocorrências, previsão, dashboard financeiro | Fase 3 |
| Editar ou excluir transação (F21 — telas de correção) | Fase 3 |
| Filtro, busca, paginação, agrupamento por mês na lista | quando o volume doer |
| Moeda diferente de BRL | não é objetivo da v1 |

O formulário desta etapa **não é** o formulário definitivo de despesa. Ele é o mínimo que prova o trajeto.

## 3. Modelo de dados — `transactions`

Migration `supabase/migrations/0004_criar_transactions.sql`. O critério de corte foi: entra o que esta etapa usa **ou** o que seria retrabalho destrutivo adicionar depois. Coluna nula que se adiciona com `alter table add column` na Fase 3 fica fora.

| Coluna | Tipo | Nulidade | Default | Razão |
|---|---|---|---|---|
| `id` | `uuid` | not null (PK) | `gen_random_uuid()` | mesma convenção de `profiles` e `areas` |
| `user_id` | `uuid` | not null | `auth.uid()` | dono. FK `auth.users(id) on delete cascade`. É a coluna da RLS |
| `area_id` | `uuid` | **null** | — | FK `public.areas(id) on delete set null`. §6.3: excluir área desassocia, não apaga. Nula porque o sync da Fase 3 não traz área e finanças é visão transversal, não área |
| `direction` | `text` | not null | — | `check (direction in ('in','out'))`. §6.5: toda transação tem direção |
| `amount` | `bigint` | not null | — | **centavos, inteiro**. `check (amount > 0)` — o sinal é o `direction`, nunca o valor |
| `description` | `text` | not null | — | `check (char_length(btrim(description)) > 0)` |
| `occurred_at` | `timestamptz` | not null | `now()` | quando o fato aconteceu (≠ `created_at`) |
| `source` | `text` | not null | `'manual'` | `check (source in ('manual','chat','bank_sync'))`. R2 pede conciliação no modelo desde a primeira migration |
| `reconciliation_status` | `text` | not null | `'pending'` | `check (... in ('pending','matched','standalone','ignored'))`. Idem R2 |
| `created_at` | `timestamptz` | not null | `now()` | convenção do repo |
| `updated_at` | `timestamptz` | not null | `now()` | convenção do repo; F21 usa |

**Índice:** `(user_id, occurred_at desc, created_at desc)` — é exatamente a leitura da tela.

**RLS:** `enable row level security` + política `transactions_owner` `for all using (user_id = auth.uid()) with check (user_id = auth.uid())`, no mesmo formato de `areas`.

### O que fica de fora do schema, de propósito

`currency`, `merchant`, `category_id`, `account_id`, `card_id`, `invoice_id`, `occurrence_id`, `payment_method`, `external_id`, `metadata`. Todas do §7 do plano, todas nuláveis ou com default, todas adicionáveis por `add column` sem tocar em linha existente. Nenhuma tem tabela-alvo existindo hoje. Colocá-las agora seria schema morto num item cujo ponto é provar o encanamento.

### Invariantes do dado (viram teste, não são recomendação)

1. **`user_id` nunca vem do payload.** Sai do JWT (via `default auth.uid()` e/ou derivação na função). Payload que traga `user_id` é ignorado — nunca respeitado.
2. **`amount` é inteiro em centavos, do teclado ao banco.** Não existe `double`/`float` em nenhum ponto do caminho do dinheiro. A conversão "45,00" → `4500` é acumulação de dígitos, nunca `double.parse(x) * 100`.
3. **O sinal mora no `direction`.** `amount` é sempre positivo.
4. **`occurred_at` é o fato; `created_at` é o registro.** Nunca se usa um no lugar do outro.

## 4. Contrato da Edge Function

`POST /functions/v1/transactions` — roteada pelo `main/index.ts` existente. Só `POST`; o comportamento mora num `handler.ts` testável sem subir servidor.

**Requisição**

```json
{
  "direction": "out",
  "amount": 4500,
  "description": "Almoço",
  "occurred_at": "2026-08-15T12:00:00-03:00"
}
```

`occurred_at` é **opcional**; ausente vira `now()`. Isso mantém o `curl` do DoD curto. `user_id` e `area_id` não fazem parte do contrato nesta etapa (ver Pergunta 1).

**Respostas**

| Status | Quando | Corpo |
|---|---|---|
| `201` | criada | a linha criada, inclusive `id` e `occurred_at` resolvido |
| `400` | validação | `{"error":{"code":"...","message":"..."}}` |
| `401` | sem `Authorization` ou JWT inválido | `{"error":{"code":"unauthorized",...}}` |
| `405` | método ≠ POST | idem |
| `500` | falha inesperada | `{"error":{"code":"internal_error",...}}` |

**Códigos de erro de validação:** `invalid_json`, `invalid_direction`, `invalid_amount`, `invalid_description`, `invalid_occurred_at`. Códigos estáveis, porque a camada `data` do app os traduz para `Failure` tipada.

**Validação na borda** (nenhum `any` atravessa):

- `direction` presente e ∈ `{in, out}`
- `amount` presente, tipo número, **inteiro** (`45.5` → 400), `> 0`
- `description` presente, string, após `trim` entre 1 e 200 caracteres
- `occurred_at`, se presente, ISO-8601 parseável

A função usa o **JWT do usuário**, não a `service_role` — a RLS se aplica sozinha no insert. A checagem de `Authorization` é explícita na borda, para que a ausência vire `401` e não um `500` disfarçado de erro de RLS.

## 5. Leitura

`GET /rest/v1/transactions` direto pelo `supabase_flutter`, **sem filtro de `user_id` na query** — quem autoriza é a RLS, como já se faz no `areas_module`. Ordenação `occurred_at desc, created_at desc`. Sem paginação nesta etapa.

Depois de um `201`, a lista **refaz a leitura** em vez de inserir o item localmente. É mais lento e é de propósito: é o refetch que prova o trajeto de volta, que é o objetivo do item.

## 6. Telas

### 6.1 Formulário de cadastro

Quatro campos, na ordem em que se pensa:

| Campo | Controle | Regra |
|---|---|---|
| Direção | seletor de dois estados: **Despesa** / **Receita** | default **Despesa**. Rótulo textual sempre visível — cor não é o único sinal |
| Valor | campo monetário pt-BR, `R$`, dígitos entrando pela direita | máximo 9 dígitos inteiros. Vazio ou zero desabilita o envio |
| Descrição | texto de uma linha | obrigatório, até 200 caracteres |
| Data | seletor de data, default **hoje** | não aceita data futura — o que ainda vai acontecer é compromisso (Fase 3), não transação |

Botão **Registrar** desabilitado enquanto inválido e enquanto o envio está em voo (evita duplicata por toque duplo). Em erro, o formulário **preserva o que foi digitado**.

### 6.2 Lista

Uma linha por transação, mostrando: descrição, **data explícita** e valor.

- **Data explícita, sempre**: `15/08, sexta` (`dd/MM, EEEE` em pt-BR, minúsculo). Ano diferente do corrente: `15/08/2025, sexta`. **Nunca** "hoje"/"ontem" — o plano §6.2 exige data explícita justamente para não devolver ambiguidade ao usuário.
- **Valor com algarismos tabulares** (`FontFeature.tabularFigures()`), alinhado à direita: a coluna não pode dançar entre linhas.
- Direção sinalizada por **prefixo textual e cor** (`−` / `+`, terracota para saída, verde seco para entrada) — nunca só por cor.

### 6.3 Estados da tela

| Estado | O que aparece |
|---|---|
| Carregando | indicador discreto, sem bloquear a navegação |
| Vazio | "Nenhuma transação registrada." + convite para registrar a primeira. Sem ilustração, sem entusiasmo (§11.4) |
| Erro de leitura | mensagem curta + ação "tentar de novo" |
| Com dados | lista ordenada, mais recente primeiro |

A lista é uma rota nova, alcançável a partir da home autenticada. A home **não muda** nesta etapa: §11.4 reserva a tela inicial para "hoje e esta semana", que é assunto da Fase 2.

## 7. Decisões tomadas aqui (com a fonte)

| # | Decisão | Fonte |
|---|---|---|
| 1 | `amount` é `bigint` em centavos | DoD ("valor não-inteiro vira 400") + §6.7 ("valor igual ± centavos") |
| 2 | `occurred_at` é `timestamptz`, não `date` | Convenção de nomes do §7 (`_at` = timestamptz, `_date` = date) e a Fase 3 traz horário do banco. `date` viraria troca de tipo depois |
| 3 | O app manda a data escolhida às **12:00 no fuso do perfil** | Meio-dia local não vira o dia em nenhum offset nem em virada de horário — é o que impede "15/08" aparecer como "16/08" |
| 4 | `direction` e demais vocabulários são `text` + `check`, não `enum` do Postgres | Enum é caro de alterar; `check` é a fonte da verdade legível e o padrão do repo |
| 5 | `source` e `reconciliation_status` entram já | R2 é risco alto e diz literalmente "conciliação no modelo desde a primeira migration" |
| 6 | Sem categoria nesta etapa | A tabela `categories` não existe e criá-la é Fase 3. Um `category text` livre agora viraria retrabalho destrutivo quando virasse FK |
| 7 | Sem edição nem exclusão | O DoD diz "criada e listada". Correção é F21 |
| 8 | Data futura bloqueada na UI, **não** na função | A Fase 3 (sync) não pode herdar essa trava |
| 9 | 201 devolve a linha, mas a tela refaz a leitura | O refetch é a prova do caminho de volta |

## 8. Perguntas em aberto

Priorizadas. Cada uma muda o schema ou a tela; nenhuma tem resposta no `docs/plano.md`.

### P1 — O formulário pede a área? (schema + tela)

| Opção | O que custa | O que ganha |
|---|---|---|
| **A** — coluna `area_id` + seletor opcional no formulário ("Sem área") | dropdown alimentado pelo `areas_module`, mais um widget test, e `area_id` passa a vir do payload — o que abre um IDOR teórico (FK não respeita RLS: dá para referenciar área de outro usuário) | o E2E exercita o FK e duas tabelas sob RLS |
| **B** — coluna `area_id` no schema, **sem** seletor na tela | uma coluna sempre nula por enquanto | tela de 4 campos; Fase 1 preenche `area_id` sem migration; payload sem `area_id` elimina o IDOR |
| **C** — sem a coluna agora | uma migration a mais na Fase 1 (aditiva, não destrutiva) | schema estritamente mínimo |

**Recomendação: B.** O ponto da etapa é o encanamento, não a taxonomia; §6.3 é explícito em que dinheiro não se compartimenta por área, então forçar a escolha entre "Rotina pessoal / Rotina profissional / Alimentação / Objetivos" para um almoço seria pedir uma decisão que o produto não quer. A coluna fica porque está no modelo do §7 e é o único elo com o schema existente.

### P2 — Dá para apagar uma transação nesta etapa? (tela)

O E2E roda exclusivamente contra a stack local descartável. Os roteiros recusam
`SUPABASE_URL` remoto, aplicam bootstrap e migrations locais e removem dados ao
encerrar; HML não recebe escrita de teste. O executor Android é `patrol test`,
com `PatrolJUnitRunner`, orquestrador AndroidX e a ponte versionada
`android/app/src/androidTest/java/br/com/ganza/ganza/MainActivityTest.java`.
Ela lista os `patrolTest` do bundle e executa cada caso no emulador. Cada
cenário produz asserções Dart, PNG capturado no ponto de evidência e logs.
Vídeo não é gravado. O roteiro configura `adb reverse` para que o callback de
captura em `127.0.0.1` funcione sem depender da rota de rede do emulador.
O PNG é solicitado imediatamente após a asserção que estabiliza o estado, sem
espera artificial que permita diálogos externos sobreporem a tela.
Os alvos ficam em `app/patrol_test/`; o pacote Flutter `integration_test` não
faz parte deste harness. `scripts/e2e-emulator.sh` grava PID, serial e AVD de
cada rodada, recusa usar emulador externo e encerra apenas o processo que
iniciou, inclusive no `trap` do executor pai.
`scripts/e2e-local.sh` reserva a primeira `round_NN` inexistente entre `01` e
`03`; uma pasta já existente nunca é sobrescrita.
Para induzir falha de transporte, o roteiro bloqueia apenas a saída para o
Supabase local (`10.0.2.2`) por `iptables`; ele não desliga a conectividade
global do emulador.

| Opção | O que custa | O que ganha |
|---|---|---|
| **A** — nada na UI; limpar pelo Studio | zero código; exige lembrar de limpar | escopo intacto (R1) |
| **B** — excluir na lista (deslizar ou pressionar) | 1 use case, 1 estado de cubit, 1 widget test; a política RLS já cobre o `delete` | a tela sobrevive ao uso do dev antes da F21 |

**Recomendação: A.** F21 já está no plano como tela de correção e é Fase 3; abrir a porta agora é o R1 acontecendo devagar. Se a intenção for **usar** a tela no dia a dia durante a Fase 0 (e não só provar o trajeto), a resposta vira B — e aí é decisão de uso, não de escopo.

### P3 — A última linha do DoD é verificável hoje? (dependência)

O DoD exige "valor exibido usa algarismos tabulares, conferido no print". A **P5** do roadmap diz que os `.ttf` de Fraunces e IBM Plex Sans ainda não estão em `app/assets/fonts/` — hoje a tipografia cai no fallback do sistema.

| Opção | O que custa | O que ganha |
|---|---|---|
| **A** — baixar as fontes (SIL OFL, ambas) e declarar no `pubspec.yaml` antes de fechar a etapa | ~15 min, resolve a P5 | a linha do DoD fecha de verdade, e a identidade do §11 sai do papel |
| **B** — fechar com o fallback do sistema, registrando a ressalva | zero | a linha fecha com asterisco: o `tnum` do fallback pode até funcionar, mas não é o que a etapa promete |

**Recomendação: A.** É a menor tarefa do roadmap bloqueando uma linha de DoD, e a coluna de valores é o primeiro lugar onde a falta aparece.
