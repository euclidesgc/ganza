import { assertEquals } from '@std/assert';
import { confirmProposal, writeProposals } from './proposal_writer.ts';
import corpus from './testdata/injection_corpus.json' with { type: 'json' };

// deno-lint-ignore no-explicit-any
function fakeSupabase(proposal?: any): { supabase: any; inserts: Record<string, unknown>[] } {
  const inserts: Record<string, unknown>[] = [];

  // deno-lint-ignore no-explicit-any
  function builder(data: any): any {
    const b = {
      data,
      error: null,
      eq: () => b,
      maybeSingle: () => Promise.resolve({ data, error: null }),
    };
    return b;
  }

  const supabase = {
    from: (table: string) => ({
      select: () => builder(proposal ?? null),
      insert: (rows: unknown) => {
        const list = Array.isArray(rows) ? rows : [rows];
        for (const row of list) inserts.push({ table, ...(row as object) });
        return Promise.resolve({ error: null });
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
