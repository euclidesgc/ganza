import { createClient } from '@supabase/supabase-js';
import { normalizeDescription } from '../_shared/ai/normalize_description.ts';

interface ApiError {
  code: string;
  message: string;
}

function errorResponse(code: string, message: string, status: number): Response {
  return Response.json({ error: { code, message } satisfies ApiError }, { status });
}

// Separado do index.ts para poder ser testado sem subir servidor: o
// `Deno.serve` do index é a borda, isto é o comportamento.
export default async function handler(req: Request): Promise<Response> {
  if (req.method !== 'POST') {
    return errorResponse('method_not_allowed', 'use POST', 405);
  }

  const authorization = req.headers.get('Authorization');
  if (!authorization) {
    return errorResponse('unauthorized', 'sessão ausente', 401);
  }

  let raw: unknown;
  try {
    raw = await req.json();
  } catch {
    return errorResponse('invalid_json', 'corpo da requisição não é um JSON válido', 400);
  }
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    return errorResponse('invalid_json', 'corpo da requisição precisa ser um objeto JSON', 400);
  }

  const body = raw as Record<string, unknown>;

  const transactionId = body.transaction_id;
  if (typeof transactionId !== 'string' || transactionId.length === 0) {
    return errorResponse(
      'invalid_transaction_id',
      'transaction_id precisa ser uma string não-vazia',
      400,
    );
  }
  const categoryId = body.category_id;
  if (typeof categoryId !== 'string' || categoryId.length === 0) {
    return errorResponse(
      'invalid_category_id',
      'category_id precisa ser uma string não-vazia',
      400,
    );
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
  if (!supabaseUrl || !supabaseAnonKey) {
    return errorResponse('internal_error', 'configuração do servidor ausente', 500);
  }

  // JWT do usuário, nunca service_role: a RLS decide o dono da transação e da
  // categoria, mesmo que o payload tente apontar para uma linha alheia.
  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: transaction, error: transactionError } = await supabase
    .from('transactions')
    .select('description')
    .eq('id', transactionId)
    .maybeSingle();
  if (transactionError || !transaction) {
    return errorResponse('transacao_nao_encontrada', 'transação não encontrada', 404);
  }

  const { data: category, error: categoryError } = await supabase
    .from('categories')
    .select('id')
    .eq('id', categoryId)
    .maybeSingle();
  if (categoryError || !category) {
    return errorResponse('categoria_invalida', 'categoria não pertence ao usuário', 400);
  }

  const { error: updateError } = await supabase
    .from('transactions')
    .update({ category_id: categoryId })
    .eq('id', transactionId);
  if (updateError) {
    return errorResponse('write_failed', 'não foi possível categorizar a transação', 500);
  }

  const key = normalizeDescription(String(transaction.description ?? ''));
  if (key.length > 0) {
    const { data: existing, error: existingError } = await supabase
      .from('category_hints')
      .select('hits')
      .eq('normalized_description', key)
      .maybeSingle();
    if (existingError) {
      return errorResponse('write_failed', 'não foi possível ler o hint', 500);
    }

    if (existing) {
      const { error: hintUpdateError } = await supabase
        .from('category_hints')
        .update({
          category_id: categoryId,
          hits: (existing.hits as number) + 1,
          updated_at: new Date().toISOString(),
        })
        .eq('normalized_description', key);
      if (hintUpdateError) {
        return errorResponse('write_failed', 'não foi possível atualizar o hint', 500);
      }
    } else {
      const { error: hintInsertError } = await supabase
        .from('category_hints')
        .insert({ normalized_description: key, category_id: categoryId });
      if (hintInsertError) {
        return errorResponse('write_failed', 'não foi possível gravar o hint', 500);
      }
    }
  }

  return Response.json(
    { transaction_id: transactionId, category_id: categoryId, status: 'categorized' },
    { status: 200 },
  );
}
