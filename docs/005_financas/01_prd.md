# 005 - Finanças e conciliação · PRD

A visão transversal do dinheiro: receita e despesa, compromissos que geram
ocorrências futuras, parcelamento, financiamento com juros e a conciliação com o
extrato bancário (`docs/plano.md` §6.5–6.7). É aqui que nasce o **plano de
recuperação financeira** — a resposta a "quanto devo, quanto isso me custa em
juros e o que acontece se eu quitar antes".

## 1. Resultado esperado

A pessoa registra um financiamento ("financiei o carro em 48x, taxa 1,2% a.m.,
Price") ou uma compra parcelada ("comprei a geladeira em 12x") e o sistema
calcula — **em código determinístico, nunca IA** — a parcela, o cronograma de
amortização, o total de juros e a simulação de quitação antecipada (reduzir
prazo × reduzir parcela). O dashboard agrega: saldo, comprometido, dívida total
e custo de juros — o ponto de partida do plano de recuperação.

## 2. Fronteira: o que a IA interpreta e o que o código decide

| A IA interpreta | O código decide |
|---|---|
| O nome, o valor e a regra expressa em linguagem natural | Parcela, amortização (Price/SAC), saldo devedor, juros — `/finance-math` |
| "PARC 03/12" na descrição da fatura | A detecção de parcelamento por **regex**, sem IA |
| O pedido de simulação | A comparação prazo × parcela e o valor presente das parcelas restantes |

O cálculo financeiro é código determinístico testado (invariante nº 3 do
`CLAUDE.md`). O número do app pode divergir do banco (seguro/IOF/TR não
descontam igual — §6.6); o oficial é o que o banco informar.

## 3. Caminho feliz

1. Pessoa escreve "financiei o carro, 48x de 1.2% ao mês, Price, valor 60 mil".
2. `/ingest` classifica `create_commitment`; o card mostra o compromisso.
3. Confirmar → `confirmProposal` grava o `commitment` e gera as ocorrências
   futuras (parcelas).
4. A tela de compromissos mostra o cronograma e a simulação de quitação.
5. O dashboard mostra a dívida total, o comprometido mensal e o custo de juros.

## 4. Exceções e casos de borda

- **Parcelamento por duas vias** (informado no chat **ou** detectado na fatura):
  deduplicação por estabelecimento + valor da parcela + total de parcelas.
- **Compromisso variável** (luz, água): ocorrência com valor nulo; entra na
  previsão pela média e é marcada como estimativa.
- **Conciliação**: movimento bancário casa com o registro por valor (± centavos)
  em janela de ±5 dias; o valor do banco é canônico.

## 5. O que esta feature **não** entrega primeiro (registrado no `changes.md`)

- **Sincronização bancária (Pluggy/OFX)** — é a Fase 3/4; depende da decisão
  FD-021 (OFX é o caminho recomendado para começar) e de conta externa do humano.
- **Faturas de cartão e cartão-benefício** — Fase 4.

## 6. Invariantes que o DoD cobra

1. **Juros/amortização é código determinístico, nunca IA** — `/finance-math`
   testado com datas e valores fixos.
2. **Dinheiro em centavos inteiros** — nenhum `double` representa dinheiro; o
   arredondamento acontece uma vez por linha do cronograma.
3. **O modelo nunca calcula dinheiro** — ele interpreta o pedido; o cálculo é
   função pura.
4. **RLS em toda tabela nova**, política `user_id = (select auth.uid())`.

## 7. Dependências e riscos

- **Depende** da 003 (`/ingest`, `confirmProposal`, cards) e da 004 (a máquina de
  ocorrência que o compromisso reusa).
- **Risco**: arredondamento errado no cronograma distorce a dívida — barrado por
  teste com valores conhecidos e o total batendo.
- **Risco**: detecção de parcelamento duplicar — barrado por regex testado +
  deduplicação.
