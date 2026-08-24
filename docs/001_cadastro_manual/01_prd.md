# 001 - Cadastro manual ponta a ponta · PRD

Enriquece `02_specs.md`. O que está lá não se repete aqui: este documento é o contrato do "pronto".

Decisões desta feature estão em [`decisions.md`](decisions.md). Desvios já
resolvidos e a reconciliação documental correspondente estão em
[`changes.md`](changes.md); este PRD descreve somente o estado final.

## 1. Resultado esperado

Ao fim desta etapa, o dev abre o app na conta local de teste, registra "Almoço, R$ 45,00, ontem" em menos de dez segundos e vê a linha na tela — e essa linha existe no Postgres local, protegida por RLS, tendo passado por uma Edge Function. Nenhum modelo de IA foi chamado.

O que isso prova, e é o único motivo da etapa existir: **as cinco camadas se falam**. Flutter → Edge Function → Postgres → RLS → PostgREST → Flutter. Toda feature da Fase 1 em diante reusa esse trajeto; se ele estiver torto, o erro aparece com IA por cima e ninguém sabe de quem é a culpa.

O que **não** se prova aqui, e não deve ser cobrado: usabilidade do cadastro de despesa, completude do modelo financeiro, categorização, conciliação.

## 2. Fronteira: o que é calculado e o que é interpretado

Esta feature toca dinheiro, então a fronteira vai escrita, não subentendida.

| | Nesta etapa |
|---|---|
| **Determinístico (código)** | **Tudo.** O valor é digitado pelo humano em centavos e viaja como inteiro. A direção é escolhida num seletor de dois estados. A data sai de um seletor. A função valida e insere; não arredonda, não converte moeda, não infere nada. |
| **Interpretado (IA)** | **Nada.** Não há chamada de modelo, `task_type`, `ai_usage`, prompt ou heurística de texto. |

Consequência prática, que é um gate de revisão: se aparecer qualquer parsing de linguagem natural, dedução de categoria ou "adivinhar a direção pelo texto" nesta etapa, é desvio de escopo — não é otimização.

E a invariante que sobrevive à etapa: **nenhum `double` no caminho do dinheiro.** Do teclado ao banco, `int`. A conversão "45,00" → `4500` é acumulação de dígitos. `double.parse("45.00") * 100` produz `4499.999...` e é exatamente o bug que só aparece em produção, meses depois, num total que não bate.

## 3. Caminho feliz

1. Autenticado, o dev abre a lista de transações. Está vazia: "Nenhuma transação registrada."
2. Toca em registrar. O formulário abre com **Despesa** marcada e a data em **hoje**.
3. Digita `4500` no campo de valor, que exibe `R$ 45,00`. Escreve `Almoço`. Ajusta a data para ontem.
4. Toca em **Registrar**. O botão desabilita.
5. O app chama `POST /functions/v1/transactions` com o JWT da sessão. A função valida, insere com o JWT do usuário (RLS aplicada), devolve `201` com a linha.
6. O app volta para a lista e **refaz a leitura** via PostgREST.
7. A linha aparece: `Almoço · 15/08, sexta · −R$ 45,00`, valor com algarismos tabulares, alinhado à direita.

## 4. Exceções e casos de borda

| Situação | Comportamento esperado |
|---|---|
| Requisição sem `Authorization` | `401`. Não é `500`, não é `403`. A função checa o header na borda antes de tocar no banco |
| JWT expirado durante o preenchimento | `401` → a guarda de rota do `auth_module` leva ao login; o app não mostra erro genérico |
| `amount` não inteiro (`45.5`) | `400 invalid_amount`. Do lado do app isso é inalcançável (o campo só produz inteiro) — a validação existe porque a borda não confia no cliente |
| `amount` zero, negativo ou ausente | `400 invalid_amount`. No app, botão desabilitado |
| `direction` fora de `in\|out` | `400 invalid_direction` |
| `description` vazia ou só espaços | `400 invalid_description`. No app, botão desabilitado |
| `description` acima de 200 caracteres | `400 invalid_description`. No app, o campo trava a digitação |
| `occurred_at` não parseável | `400 invalid_occurred_at` |
| `occurred_at` no futuro | Aceito pela função (a Fase 3 não pode herdar a trava), **bloqueado pelo seletor de data** |
| JSON malformado | `400 invalid_json` |
| Método diferente de POST | `405` |
| Payload trazendo `user_id` de outra conta | Ignorado. `user_id` sai do JWT; a `with check` da RLS é a segunda cancela |
| Sem rede no envio | `Failure` tipada, mensagem curta, **o formulário preserva o que foi digitado** |
| Toque duplo em Registrar | O botão desabilita no primeiro toque. Não há idempotência de servidor nesta etapa — se a resposta se perder na rede, a duplicata é possível e é aceita como limitação conhecida |
| Lista vazia | Estado vazio explícito, não uma tela em branco |
| Falha na leitura da lista | Mensagem + "tentar de novo". Nunca lista vazia disfarçando erro — os dois estados precisam ser visualmente distintos |
| Transação de dezembro vista em janeiro | Data exibida com ano: `15/12/2025, segunda` |
| Valor grande (`R$ 1.234.567,89`) | Formata e alinha sem quebrar a coluna. É o teste real dos algarismos tabulares |
| Descrição longa na lista | Uma linha, com reticências. O valor nunca é empurrado para fora |

## 5. Analytics

**Nesta etapa não sai evento nenhum.** Não existe SDK de analytics no projeto e o Firebase é a decisão **P1**, pendente do humano. Registrar isso é honestidade de escopo, não esquecimento.

O que fica definido para quando o SDK existir, para que os nomes não nasçam ad hoc na Fase 1:

| Evento | Propriedades | Quando |
|---|---|---|
| `transaction_manual_submitted` | `direction`, `has_custom_date` | toque em Registrar |
| `transaction_manual_succeeded` | `direction`, `latency_ms` | `201` recebido |
| `transaction_manual_failed` | `error_code`, `http_status` | qualquer resposta ≠ `201` |
| `transaction_list_viewed` | `item_count`, `is_empty` | abertura da lista |

Nenhuma propriedade carrega valor, descrição ou qualquer dado do registro. O que se mede é o funil, não o dinheiro.

## 6. Erros monitorados

Sem Crashlytics (também **P1**), o monitoramento desta etapa é log estruturado e as quatro redes de erro que o `bootstrap.dart` já instala.

**Na Edge Function**, cada resposta ≠ `2xx` gera uma linha de log com `status`, `error_code` e latência, **sem o corpo da requisição** (descrição e valor são dado pessoal). Três classes precisam ser distinguíveis no log sem ler código:

1. **Rejeição de validação** (`400`) — comportamento correto, é o sistema funcionando.
2. **Falha de autenticação** (`401`) — esperado quando o token expira; recorrente vira sintoma.
3. **Falha de banco/inesperada** (`500`) — o único que merece atenção. Violação de `check` ou de RLS chegando como `500` significa que a borda deixou passar algo que deveria ter barrado, e isso é bug de validação, não do banco.

**No app**, `PostgrestException` e falha de rede são traduzidas em `core/error` para `Failure` tipada — a UI nunca mostra mensagem crua de exceção.

## 7. Testes que cada etapa vai pedir

Ordem do `CLAUDE.md`: E2E atestado primeiro, bateria automatizada depois.

**Banco (CI, job "Banco")**
- `0004_criar_transactions.sql` aplica limpo num Postgres vazio
- Gate de RLS e gate de política passam para `transactions`
- `insert` sem sessão é negado; com a sessão do dono é aceito
- `amount = 0`, `amount < 0` e `direction = 'x'` violam `check`

**Edge Function (`deno task test`)**
- `201` no caminho feliz, com `user_id` derivado do JWT
- `400` para: `amount` não inteiro, `amount <= 0`, `direction` inválida, `description` vazia, `occurred_at` inválido, JSON malformado
- `401` sem `Authorization`
- `405` em método errado
- Payload com `user_id` alheio não altera o dono da linha
- **Cada teste de validação precisa ser visto falhando sem a validação** — é o que o DoD cobra

**Flutter (`flutter test -r compact`)**
- *domain*: use case de criação devolvendo `Either`
- *data*: `safeParse` do model — payload válido, `amount` como string, `direction` desconhecida
- *core*: conversor de dígitos → centavos (`"4500"` → `4500`; nunca via `double`) e formatador centavos → `R$ 45,00`
- *core*: formatador de data (`15/08, sexta`; ano diferente inclui o ano)
- *cubit*: `bloc_test` de envio (sucesso, falha de rede, falha de validação) e de listagem (carregando → vazio, carregando → com dados, carregando → erro)
- *widget*: formulário — botão desabilitado com campo inválido, desabilitado durante o envio, dados preservados após erro
- *widget*: **estado vazio da lista** (exigido no DoD)

**E2E no emulador** (`patrol test`,
`docs/001_cadastro_manual/e2e/round_01/`, atestado pelo dev)

Patrol executa os cenários por uma ponte JUnit versionada em
`androidTest`, e o roteiro captura um PNG no instante marcado pelo teste.
Vídeo não é gerado: asserções, PNGs e logs são a evidência durável da rodada.
O print precisa mostrar, na mesma imagem: a
transação registrada na lista, a data explícita no formato `15/08, sexta` e o
valor alinhado com algarismos tabulares. Um segundo print do estado vazio antes
do cadastro fecha o par. O `report.md` liga cada passo ao PNG e ao log.

**Prova de RLS pelo caminho real** (comando, saída literal)
- `GET /rest/v1/transactions` anônimo → `[]`
- `GET /rest/v1/transactions` com a sessão do dono → a transação
- `POST /functions/v1/transactions` com JWT → `201`; sem `Authorization` → `401`

## 8. Dependências e riscos

- **P5 (fontes)** fechada: as fontes Fraunces e IBM Plex Sans foram versionadas em `app/assets/fonts/`, e os algarismos tabulares passaram a valer.
- **D3/D7**: o E2E roda exclusivamente na stack local descartável. HML não recebe escrita de teste.
- **P8 (role dedicado no Postgres)** não bloqueia: a escrita desta etapa usa o JWT do usuário, não uma conexão de serviço.
- **R1 (escopo)**: o maior risco desta etapa não é técnico. É o formulário crescer — categoria, conta, forma de pagamento, anexo — e a Fase 0 nunca fechar. A régua é o DoD: criada e listada.
