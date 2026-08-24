import { assertEquals } from '@std/assert';
import { parseProposals } from './proposal_schema.ts';

Deno.test('rejeita user_id no payload, sem sanear', () => {
  const result = parseProposals([
    {
      kind: 'create_transaction',
      payload: {
        direction: 'out',
        amount: 4500,
        description: 'almoço',
        user_id: '00000000-0000-0000-0000-000000000001',
      },
    },
  ]);
  assertEquals(result.ok, false);
  if (result.ok) return;
  assertEquals(result.code, 'campo_nao_permitido');
});

Deno.test('rejeita verbo de alteração e remoção', () => {
  for (const kind of ['update_transaction', 'delete_transaction']) {
    const result = parseProposals([{ kind, payload: {} }]);
    assertEquals(result.ok, false);
    if (result.ok) return;
    assertEquals(result.code, 'kind_nao_permitido');
  }
});

Deno.test('rejeita area_id e category_id no payload', () => {
  for (const key of ['area_id', 'category_id']) {
    const result = parseProposals([
      { kind: 'create_transaction', payload: { [key]: 'x' } },
    ]);
    assertEquals(result.ok, false);
    if (result.ok) return;
    assertEquals(result.code, 'campo_nao_permitido');
  }
});

Deno.test('rejeita raiz que não é lista e lista grande demais', () => {
  const notArray = parseProposals({ kind: 'create_task' });
  assertEquals(notArray.ok, false);
  if (!notArray.ok) assertEquals(notArray.code, 'raiz_nao_e_lista');

  const tooMany = parseProposals(
    Array.from({ length: 11 }, () => ({ kind: 'create_task', payload: {} })),
  );
  assertEquals(tooMany.ok, false);
  if (!tooMany.ok) assertEquals(tooMany.code, 'limite_de_propostas');
});

Deno.test('rejeita amount inválido e descrição longa', () => {
  for (const amount of [45.5, 0, -1, 1_000_000_001]) {
    const result = parseProposals([
      {
        kind: 'create_transaction',
        payload: { direction: 'out', amount, description: 'x' },
      },
    ]);
    assertEquals(result.ok, false);
    if (!result.ok) assertEquals(result.code, 'amount_invalido');
  }

  const longDescription = parseProposals([
    {
      kind: 'create_task',
      payload: { title: 'x', description: 'a'.repeat(201) },
    },
  ]);
  assertEquals(longDescription.ok, false);
  if (!longDescription.ok) assertEquals(longDescription.code, 'description_invalida');
});

Deno.test('aceita proposta bem-formada', () => {
  const result = parseProposals([
    {
      kind: 'create_transaction',
      payload: { direction: 'out', amount: 4500, description: 'almoço' },
    },
  ]);
  assertEquals(result.ok, true);
  if (result.ok) assertEquals(result.value.length, 1);
});
