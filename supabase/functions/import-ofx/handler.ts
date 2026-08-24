import { createClient } from '@supabase/supabase-js';
import { parseOfx } from '../_shared/ofx.ts';

interface ApiError {
  code: string;
  message: string;
}

function errorResponse(code: string, message: string, status: number): Response {
  return Response.json({ error: { code, message } satisfies ApiError }, { status });
}

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

  const ofx = (raw as Record<string, unknown>).ofx;
  if (typeof ofx !== 'string' || ofx.trim().length === 0) {
    return errorResponse('invalid_ofx', 'ofx precisa ser uma string não-vazia', 400);
  }

  const parsed = parseOfx(ofx);
  if (parsed.length === 0) {
    return errorResponse('ofx_sem_movimentos', 'nenhum movimento encontrado no OFX', 400);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
  if (!supabaseUrl || !supabaseAnonKey) {
    return errorResponse('internal_error', 'configuração do servidor ausente', 500);
  }

  // JWT do usuário, nunca service_role: a RLS decide o dono e o `user_id`
  // default vem do `auth.uid()`, nunca do payload.
  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let created = 0;
  for (const movement of parsed) {
    const { data: existing } = await supabase
      .from('transactions')
      .select('id')
      .eq('external_id', movement.fitId)
      .maybeSingle();
    if (existing) continue;

    const { error: insertError } = await supabase.from('transactions').insert({
      direction: movement.amountCents < 0 ? 'out' : 'in',
      amount: Math.abs(movement.amountCents),
      description: movement.memo !== '' ? movement.memo : 'Movimento bancário',
      occurred_at: `${movement.postedDate}T00:00:00Z`,
      source: 'bank_sync',
      external_id: movement.fitId,
    });
    if (insertError) {
      return errorResponse('write_failed', 'não foi possível gravar o movimento', 500);
    }
    created += 1;
  }

  return Response.json({ created, total: parsed.length }, { status: 200 });
}
