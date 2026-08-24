# 004 - Rotinas e ocorrências · PRD

Rotina não é tarefa com data — é **regra que gera ocorrências**, como a conta de
luz gera cobrança mensal. Esta feature entrega a máquina: criar a regra, gerar a
próxima ocorrência, marcá-la nos estados terminais e ver a fila do que está
atrasado (`docs/plano.md` §6.4).

## 1. Resultado esperado

A pessoa cria uma rotina ("lavar roupa toda segunda", "banho no cachorro a cada
15 dias") e o sistema gera a próxima ocorrência com data. Quando chega, ela marca
**feita**, **adiada** (move a data da *mesma* ocorrência), **pulada** ou
**cancelada**; se não age, a ocorrência **atrasa** e aparece na lista de
atrasadas. O histórico responde "quantas vezes eu realmente lavei roupa em
agosto?" — por isso adiar move, não cria.

## 2. Fronteira: o que a IA interpreta e o que o código decide

| A IA interpreta | O código decide |
|---|---|
| O nome da rotina e a regra de recorrência expressa em linguagem natural | O cálculo determinístico da próxima data (nunca o modelo) |
| — (o `kind` `create_routine` já entra pelo chat) | Os cinco estados terminais, o log de eventos, a geração da ocorrência |

A recorrência é **código determinístico**, no mesmo espírito de `/finance-math`:
o modelo interpreta o pedido, quem calcula a data é o código, testado.

## 3. Caminho feliz

1. Pessoa escreve "banho no cachorro a cada 15 dias" no chat.
2. `/ingest` classifica `create_routine`; o card mostra a rotina e a regra.
3. Confirmar → `confirmProposal` grava a `routine` e gera a **primeira
   ocorrência** (`due_date` = hoje + 15 dias).
4. A tela de rotinas mostra a próxima ocorrência; marcá-la como **feita** gera a
   seguinte (15 dias após a conclusão real — modo `interval_from_completion`).
5. Uma ocorrência passada da data sem ação fica na **lista de atrasadas**.

## 4. Exceções e casos de borda

- **Adiar move a data da mesma ocorrência**, não cria outra (o ciclo é a unidade
  de contagem); o movimento fica no `occurrence_events`.
- **Atrasada para de notificar depois de 3 dias** (a notificação em si é
  transversal, fora desta feature), mas continua na lista até resolver.
- **`calendar` vs `interval_from_completion`**: "toda segunda" é data fixa;
  "a cada 15 dias" conta da conclusão real — se atrasou 5 dias, o próximo é 15
  dias depois do banho real.

## 5. O que esta feature **não** entrega (registrado no `changes.md`)

- **Boards/kanban** (`boards`, `board_columns`, `tasks`) — é a 008 (organização).
- **Notificação push em dupla via** — é transversal (FCM + `/notify`), não desta
  feature; aqui nasce só o dado `notify_until_days`/`reminder_days_before`.
- **Compromisso financeiro** (`commitments`) — é a 005, com colunas de juros.

## 6. Invariantes que o DoD cobra

1. **Recorrência é determinística**: nenhum cálculo de data vem da saída do
   modelo; a próxima ocorrência sai de código puro testado.
2. **Adiar não cria ocorrência nova**: `postpone` atualiza `due_date` da mesma
   linha e escreve um evento; a sequência/contagem não muda.
3. **Estados fechados**: `status` restrito a `pending|done|postponed|skipped|
   cancelled|missed`, com `check` no banco.
4. **RLS em toda tabela nova**, política `user_id = (select auth.uid())`.

## 7. Testes que cada etapa vai pedir

- **Math**: `next_due_date` para os dois modos — `calendar` cai no dia da semana
  certo e `interval_from_completion` conta da conclusão (atraso não distorce).
- **Backend**: `confirmProposal` migra `create_routine` para `routines` +
  primeira ocorrência; `resolve` marca `done/postpone/skip/cancel` e `postpone`
  loga evento sem criar linha nova.
- **App**: lista de rotinas/ocorrências e ações; atrasada visualmente distinta.

## 8. Dependências e riscos

- **Depende** da 003 (`/ingest`, `proposed_actions`, `confirmProposal`, cards).
- **Risco**: o cálculo de `calendar`/`interval` estar errado e distorcer o
  histórico — barrado por teste determinístico com datas fixas.
- **Risco**: geração duplicada de ocorrência — barrado por chave única
  `(routine_id, sequence)`.
