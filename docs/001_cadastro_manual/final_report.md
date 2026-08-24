# Relatório final — Feature 001 — Cadastro manual ponta a ponta

Estado: **entregue**. Cinco fases, cinco PRs; Fases 1–4 mergeadas (PRs #15,
#17, #19 e #20), Fase 5 (bateria + fechamento) fecha a feature. O contrato
está em [`01_prd.md`](01_prd.md); o "o quê", em [`02_specs.md`](02_specs.md);
o fatiamento e os vereditos, em [`03_plan.md`](03_plan.md); os desvios, em
[`changes.md`](changes.md).

## O que foi entregue

Cadastro manual de transação ponta a ponta: a migration `0004_criar_transactions`
(RLS + política de dono, dinheiro em `bigint` centavos), a Edge Function
`POST /functions/v1/transactions` (JWT do usuário, validação na borda, nunca
`service_role`), e no app a leitura da lista e o formulário de escrita com
valor monetário acumulado dígito a dígito — **nunca `double.parse(x) * 100`** —
data explícita com ano quando difere, e algarismos tabulares na coluna de
valores.

## Como cada caso foi provado

A prova automatizada é unit + widget (o E2E é do humano, decisão **D34**). A
bateria mora em `app/test/`, espelhando `app/lib/`:

| Camada | Caso | Teste |
|---|---|---|
| core | dígitos → centavos inteiros, backspace, teto de 9 dígitos | `app/test/core/format/cents_input_test.dart` |
| core | `R$ 45,00`, negativo `−R$`, valor grande sem arredondar | `app/test/core/format/money_formatter_test.dart` |
| core | `15/08, sexta`; ano diferente inclui o ano | `app/test/core/format/date_formatter_test.dart` |
| data | payload válido, `amount` string → `Left`, `direction` desconhecida → `Left`, `area_id` nulo | `app/test/modules/transactions_module/data/models/transaction_model_test.dart` |
| data | `toPayload` só com `direction`/`amount`/`description`/`occurred_at` | idem |
| domain | `CreateTransaction`/`ListTransactions` devolvendo `Either`, delegação verificada | `app/test/modules/transactions_module/domain/usecases/*.dart` |
| cubit | sequência exata de estados de envio e de listagem (os três desfechos) | `app/test/modules/transactions_module/presentation/**/*_cubit_test.dart` |
| widget | formulário: botão desabilitado inválido, desabilitado em voo, banner de falha | `app/test/modules/transactions_module/presentation/new_transaction/widgets/new_transaction_form_test.dart` |
| widget | estado vazio mostra "Nenhuma transação registrada." | `app/test/modules/transactions_module/presentation/transactions_list/widgets/transactions_list_empty_view_test.dart` |

A suíte completa roda verde: `cd app && flutter test -r compact` → **115
testes, todos passando**.

## Provas de falha-sem-a-mudança (o teste realmente guarda o que promete)

Cada mutação abaixo foi aplicada ao código de produção, o teste rodou vermelho
e a árvore foi restaurada:

1. `cents_input.dart`: `cents * 10 + digit` → `cents * 10` ⇒ `Expected: <4500>, Actual: <0>`.
2. `transactions_list_empty_view.dart`: texto removido ⇒ `Found 0 widgets with text "Nenhuma transação registrada."`.
3. `transaction_model.dart`: `toPayload` ganhou `user_id` ⇒ `Expected: Set['direction','amount','description','occurred_at'], Actual: Set['direction','amount','description','user_id']`.
4. `create_transaction.dart`: delegação trocada por retorno fixo ⇒ build/teste falhou (a delegação é guardada por `verify`).
5. `transactions_list_cubit.dart`: `fold` com `emit` fixo de `Loaded` ⇒ o caso `Empty` falhou.

## Riscos conhecidos e aceitos

- **X4** — sem idempotência de servidor: o botão desabilitado cobre o toque
  duplo, mas uma duplicata é possível se a resposta se perder na rede. Aceito
  no `01_prd.md` §4.
- **X5** — `updated_at` não é atualizado por nada; a edição é fase futura.
- **X9** — `isValidAmount` da Edge Function valida só `> 0`, sem teto; o app
  (`CentsInput`) já limita a 9 dígitos, então é defesa-em-profundidade opcional.
