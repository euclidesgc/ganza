import { assertEquals } from '@std/assert';
import { resolveCategory } from './resolve_category.ts';

function fakeSupabase(
  hintCategoryId: string | null,
  categoryOwned: boolean,
  // deno-lint-ignore no-explicit-any
): { supabase: any; queries: string[] } {
  const queries: string[] = [];

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
    from: (table: string) => {
      queries.push(table);
      return {
        select: () => {
          if (table === 'category_hints') {
            return builder(hintCategoryId ? { category_id: hintCategoryId } : null);
          }
          if (table === 'categories') {
            return builder(hintCategoryId && categoryOwned ? { id: hintCategoryId } : null);
          }
          return builder(null);
        },
      };
    },
  };

  return { supabase, queries };
}

Deno.test('descrição sem hint devolve null', async () => {
  const { supabase } = fakeSupabase(null, false);
  const result = await resolveCategory(supabase, 'almoço no bar');
  assertEquals(result.ok, true);
  if (result.ok) assertEquals(result.categoryId, null);
});

Deno.test('descrição com hint devolve o category_id do usuário', async () => {
  const { supabase, queries } = fakeSupabase('c1', true);
  const result = await resolveCategory(supabase, 'Almoço no Bar do Zé');
  assertEquals(result.ok, true);
  if (result.ok) assertEquals(result.categoryId, 'c1');
  assertEquals(queries.includes('category_hints'), true);
  assertEquals(queries.includes('categories'), true);
});

Deno.test('categoria alheia não retorna na RLS e vira null', async () => {
  const { supabase } = fakeSupabase('c2', false);
  const result = await resolveCategory(supabase, 'almoço no bar');
  assertEquals(result.ok, true);
  if (result.ok) assertEquals(result.categoryId, null);
});

Deno.test('descrição vazia devolve null sem tocar no banco', async () => {
  const { supabase, queries } = fakeSupabase('c1', true);
  const result = await resolveCategory(supabase, '!!!');
  assertEquals(result.ok, true);
  if (result.ok) assertEquals(result.categoryId, null);
  assertEquals(queries.length, 0);
});
