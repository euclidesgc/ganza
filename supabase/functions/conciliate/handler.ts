import { createClient } from '@supabase/supabase-js';
import { findMatch } from '../_shared/conciliation.ts';

interface ApiError {
  code: string;
  message: string;
}

function errorResponse(code: string, message: string, status: number): Response {
  return Response.json({ error: { code, message } satisfies ApiError }, { status });
}

// Separado do index.ts para poder ser testado sem subir servidor.
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

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
  if (!supabaseUrl || !supabaseAnonKey) {
    return errorResponse('internal_error', 'configuração do servidor ausente', 500);
  }

  // JWT do usuário, nunca service_role: a RLS decide o dono da transação e das
  // ocorrências, mesmo que o payload tente conciliar linha alheia.
  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: transaction, error: transactionError } = await supabase
    .from('transactions')
    .select('id, amount, occurred_at, source, reconciliation_status')
    .eq('id', transactionId)
    .maybeSingle();
  if (transactionError || !transaction) {
    return errorResponse('transacao_nao_encontrada', 'transação não encontrada', 404);
  }
  if (transaction.source !== 'bank_sync' || transaction.reconciliation_status !== 'pending') {
    return errorResponse(
      'transacao_nao_conciliavel',
      'a transação não é um movimento bancário pendente',
      409,
    );
  }

  const { data: occurrences, error: occurrencesError } = await supabase
    .from('commitment_occurrences')
    .select('id, expected_amount, due_date')
    .eq('status', 'pending');
  if (occurrencesError) {
    return errorResponse('internal_error', 'não foi possível ler as ocorrências', 500);
  }

  const match = findMatch(
    { amount: transaction.amount, occurred_at: transaction.occurred_at },
    (occurrences ?? []).map((occurrence) => ({
      id: occurrence.id,
      expected_amount: occurrence.expected_amount,
      due_date: occurrence.due_date,
    })),
  );

  if (!match) {
    return Response.json({ matched: false }, { status: 200 });
  }

  const { error: occurrenceUpdateError } = await supabase
    .from('commitment_occurrences')
    .update({
      transaction_id: transactionId,
      actual_amount: transaction.amount,
      status: 'matched',
    })
    .eq('id', match.id);
  if (occurrenceUpdateError) {
    return errorResponse('write_failed', 'não foi possível vincular a ocorrência', 500);
  }

  await supabase
    .from('transactions')
    .update({ reconciliation_status: 'matched' })
    .eq('id', transactionId);

  return Response.json({ matched: true, occurrence_id: match.id }, { status: 200 });
}
