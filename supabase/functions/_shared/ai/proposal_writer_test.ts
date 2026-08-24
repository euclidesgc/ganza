import { assertEquals } from '@std/assert';
import { confirmProposal, writeProposals } from './proposal_writer.ts';
import corpus from './testdata/injection_corpus.json' with { type: 'json' };

function fakeSupabase(
  // deno-lint-ignore no-explicit-any
  proposal?: any,
  hintCategoryId: string | null = null,
  // deno-lint-ignore no-explicit-any
): { supabase: any; inserts: Record<string, unknown>[] } {
  const inserts: Record<string, unknown>[] = [];

  // deno-lint-ignore no-explicit-any
  function builder(data: any): any {
    const b = {
      data,
      error: null,
      eq: () => b,
      select: () => b,
      maybeSingle: () => Promise.resolve({ data, error: null }),
      single: () => Promise.resolve({ data: { id: 't1' }, error: null }),
    };
    return b;
  }

  const supabase = {
    from: (table: string) => ({
      select: () => {
        if (table === 'category_hints') {
          return builder(hintCategoryId ? { category_id: hintCategoryId } : null);
        }
        if (table === 'categories') {
          return builder(hintCategoryId ? { id: hintCategoryId } : null);
        }
        return builder(proposal ?? null);
      },
      insert: (rows: unknown) => {
        const list = Array.isArray(rows) ? rows : [rows];
        for (const row of list) inserts.push({ table, ...(row as object) });
        return builder(null);
      },
      update: (row: Record<string, unknown>) => {
        inserts.push({ table, update: row });
        return builder({ data: [], error: null });
      },
    }),
  };

  return { supabase, inserts };
}

Deno.test('o corpus inteiro não escreve nenhuma linha em transactions', async () => {
  const { supabase, inserts } = fakeSupabase();
  for (const description of corpus) {
    const raw = [{
      kind: 'create_transaction',
      payload: { direction: 'out', amount: 100, description },
    }];
    await writeProposals(supabase, 'm1', raw);
  }
  const transactions = inserts.filter((row) => row.table === 'transactions');
  assertEquals(transactions.length, 0);
});

Deno.test('confirmProposal revalida o payload lido do banco', async () => {
  const { supabase } = fakeSupabase({
    id: 'p1',
    status: 'pending',
    kind: 'create_transaction',
    payload: { direction: 'out', amount: 999999999999, description: 'x' },
  });
  const result = await confirmProposal(supabase, 'p1');
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, 'payload_invalido');
});

Deno.test('confirmProposal monta a linha final por allowlist', async () => {
  const { supabase, inserts } = fakeSupabase({
    id: 'p1',
    status: 'pending',
    kind: 'create_transaction',
    payload: {
      direction: 'out',
      amount: 4500,
      description: 'almoço',
      note: 'campo que a allowlist não copia',
    },
  });
  const result = await confirmProposal(supabase, 'p1');
  assertEquals(result.ok, true);
  const transaction = inserts.find((row) => row.table === 'transactions');
  assertEquals(transaction !== undefined, true);
  assertEquals('user_id' in (transaction ?? {}), false);
  assertEquals('note' in (transaction ?? {}), false);
  assertEquals((transaction ?? {}).description, 'almoço');
});

Deno.test('confirmProposal copia a categoria do hint para a transação', async () => {
  const { supabase, inserts } = fakeSupabase(
    {
      id: 'p1',
      status: 'pending',
      kind: 'create_transaction',
      payload: { direction: 'out', amount: 4500, description: 'almoço no bar' },
    },
    'c1',
  );
  const result = await confirmProposal(supabase, 'p1');
  assertEquals(result.ok, true);
  const transaction = inserts.find((row) => row.table === 'transactions');
  assertEquals((transaction ?? {}).category_id, 'c1');
});

Deno.test('confirmProposal rejeita category_id vindo do payload', async () => {
  const { supabase } = fakeSupabase({
    id: 'p1',
    status: 'pending',
    kind: 'create_transaction',
    payload: {
      direction: 'out',
      amount: 4500,
      description: 'x',
      category_id: 'c9',
    },
  });
  const result = await confirmProposal(supabase, 'p1');
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, 'payload_invalido');
});

Deno.test('confirmProposal migra create_routine e gera a primeira ocorrência', async () => {
  const { supabase, inserts } = fakeSupabase({
    id: 'p1',
    status: 'pending',
    kind: 'create_routine',
    payload: {
      name: 'banho no cachorro',
      recurrence_mode: 'interval_from_completion',
      interval_days: 15,
    },
  });
  const result = await confirmProposal(supabase, 'p1');
  assertEquals(result.ok, true);

  const routine = inserts.find((row) => row.table === 'routines');
  assertEquals(routine !== undefined, true);
  assertEquals((routine ?? {}).recurrence_mode, 'interval_from_completion');

  const occurrence = inserts.find((row) => row.table === 'routine_occurrences');
  assertEquals((occurrence ?? {}).sequence, 1);
  assertEquals('due_date' in (occurrence ?? {}), true);
});

Deno.test('confirmProposal rejeita create_routine com payload inválido', async () => {
  const { supabase } = fakeSupabase({
    id: 'p1',
    status: 'pending',
    kind: 'create_routine',
    payload: { name: 'x', recurrence_mode: 'diario' },
  });
  const result = await confirmProposal(supabase, 'p1');
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, 'payload_invalido');
});

Deno.test('confirmar duas vezes devolve proposta_nao_pendente', async () => {
  const { supabase } = fakeSupabase({
    id: 'p1',
    status: 'confirmed',
    kind: 'create_transaction',
    payload: { direction: 'out', amount: 4500, description: 'x' },
  });
  const result = await confirmProposal(supabase, 'p1');
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, 'proposta_nao_pendente');
});
