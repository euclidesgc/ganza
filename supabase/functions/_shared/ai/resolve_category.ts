import { normalizeDescription } from './normalize_description.ts';

export type ResolveCategoryResult =
  | { ok: true; categoryId: string | null }
  | { ok: false; code: string };

export async function resolveCategory(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  description: string,
): Promise<ResolveCategoryResult> {
  const key = normalizeDescription(description);
  if (key.length === 0) {
    return { ok: true, categoryId: null };
  }

  const { data: hint, error: hintError } = await supabase
    .from('category_hints')
    .select('category_id')
    .eq('normalized_description', key)
    .maybeSingle();
  if (hintError) {
    return { ok: false, code: 'lookup_failed' };
  }

  const categoryId = hint?.category_id;
  if (typeof categoryId !== 'string') {
    return { ok: true, categoryId: null };
  }

  // A FK não respeita RLS (D13): confirma que a categoria é do usuário antes
  // de usá-la — a leitura é RLS-scoped, então categoria alheia volta vazia.
  const { data: category, error: categoryError } = await supabase
    .from('categories')
    .select('id')
    .eq('id', categoryId)
    .maybeSingle();
  if (categoryError) {
    return { ok: false, code: 'lookup_failed' };
  }
  if (!category) {
    return { ok: true, categoryId: null };
  }

  return { ok: true, categoryId };
}
