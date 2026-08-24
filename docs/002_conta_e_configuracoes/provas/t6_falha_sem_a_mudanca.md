# Provas de falha-sem-a-mudança — Fase 6

Cada mutação abaixo foi aplicada ao módulo, o teste rodou vermelho e a árvore
foi restaurada. As três provam os invariantes de segurança da fase: rejeição em
vez de saneamento (T6.4), chave de `category_hints` imune a homoglifo/zero-width
(T6.6) e privilégio zero da saída do modelo (T6.8).

## T6.4 — proposal_schema rejeita, não sanea

Mutação: remover o laço que devolve `campo_nao_permitido` para `user_id`,
`area_id` e `category_id` no `payload`.

Saída vermelha (`deno test _shared/ai/proposal_schema_test.ts`):

```
rejeita user_id no payload, sem sanear ... FAILED
rejeita area_id e category_id no payload ... FAILED
+   campo_nao_permitido
FAILED | 4 passed | 2 failed
```

## T6.6 — normalize_description imune a chave gêmea

Mutação: remover o `.replace(combiningMarks, '')` que tira o acento decomposto.

Saída vermelha (`deno test _shared/ai/normalize_description_test.ts`):

```
caractere invisível ou homoglifo não cria chave gêmea ... FAILED
error: AssertionError: Values are not equal: gêmea: "Pádaria"
FAILED | 2 passed | 1 failed
```

## T6.8 — writeProposals nunca alcança transactions

Mutação: trocar `from('proposed_actions')` por `from('transactions')` em
`writeProposals`.

Saída vermelha (`deno test _shared/ai/proposal_writer_test.ts`):

```
o corpus inteiro não escreve nenhuma linha em transactions ... FAILED
FAILED | 3 passed | 1 failed
```

## Provas estruturais (grep, sem mutação)

- `grep -n "from('" _shared/ai/proposal_writer.ts` mostra `from('transactions')`
  apenas dentro de `confirmProposal` — `writeProposals` alcança uma tabela só.
- `grep -cE "Deno\.env|SERVICE_ROLE" _shared/**/*.ts` → 0 em todos os módulos.
- `grep -cE "fetch\(|Deno\.env|createClient" _shared/ai/prompt_envelope.ts
  _shared/ai/normalize_description.ts` → 0 (módulos puros).
