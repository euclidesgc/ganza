import { assertEquals } from '@std/assert';
import { assertWithinLimits } from './limits.ts';

// deno-lint-ignore no-explicit-any
function fakeSupabase(count: number, costRows: { cost_micros: number }[]): any {
  const inserts: Record<string, unknown>[] = [];

  // deno-lint-ignore no-explicit-any
  function query(columns: string, opts?: { count?: string; head?: boolean }): any {
    const result = opts?.count === 'exact'
      ? { count, error: null }
      : { data: costRows, error: null };
    const builder = {
      ...result,
      gte: () => builder,
      eq: () => builder,
      then: (resolve: (value: typeof result) => void) => Promise.resolve(result).then(resolve),
    };
    return builder;
  }

  const supabase = {
    from: (_table: string) => ({
      select: query,
      insert: (row: Record<string, unknown>) => {
        inserts.push(row);
        return Promise.resolve({ error: null });
      },
    }),
  };

  return { supabase, inserts };
}

Deno.test('entrada grande é recusada antes de qualquer consulta', async () => {
  const { supabase, inserts } = fakeSupabase(0, []);
  const result = await assertWithinLimits(supabase, {
    taskType: 'extract_record',
    content: 'a'.repeat(4001),
  });
  assertEquals(result.ok, false);
  if (!result.ok) {
    assertEquals(result.code, 'input_too_large');
    assertEquals(result.status, 413);
  }
  assertEquals(inserts.length, 0);
});

Deno.test('lote grande demais é recusado', async () => {
  const { supabase } = fakeSupabase(0, []);
  const result = await assertWithinLimits(supabase, {
    taskType: 'bulk_categorize',
    batchSize: 101,
  });
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, 'batch_too_large');
});

Deno.test('61ª chamada na hora é limitada e a recusa fica registrada', async () => {
  const { supabase, inserts } = fakeSupabase(60, []);
  const result = await assertWithinLimits(supabase, {
    taskType: 'extract_record',
    content: 'x',
  });
  assertEquals(result.ok, false);
  if (!result.ok) {
    assertEquals(result.code, 'ai_rate_limited');
    assertEquals(result.status, 429);
  }
  assertEquals(inserts.length, 1);
  assertEquals(inserts[0].status, 'refused');
  assertEquals(inserts[0].cost_micros, 0);
});

Deno.test('custo diário acima do teto é recusado', async () => {
  const { supabase } = fakeSupabase(0, [{ cost_micros: 1_000_000_001 }]);
  const result = await assertWithinLimits(supabase, {
    taskType: 'extract_record',
    content: 'x',
  });
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, 'ai_budget_exceeded');
});

Deno.test('dentro dos limites devolve ok', async () => {
  const { supabase } = fakeSupabase(0, []);
  const result = await assertWithinLimits(supabase, {
    taskType: 'extract_record',
    content: 'almoço',
  });
  assertEquals(result.ok, true);
});
