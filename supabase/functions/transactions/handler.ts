import { createClient } from '@supabase/supabase-js';

interface ApiError {
  code: string;
  message: string;
}

const ISO_8601_DATETIME = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$/;

function errorResponse(code: string, message: string, status: number): Response {
  const body: { error: ApiError } = { error: { code, message } };
  return Response.json(body, { status });
}

function isDirection(value: unknown): value is 'in' | 'out' {
  return value === 'in' || value === 'out';
}

function isValidAmount(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value > 0;
}

function normalizedDescription(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (trimmed.length < 1 || trimmed.length > 200) return null;
  return trimmed;
}

function isIsoDateTime(value: unknown): value is string {
  return typeof value === 'string' && ISO_8601_DATETIME.test(value) &&
    !Number.isNaN(new Date(value).getTime());
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

  const direction = body.direction;
  if (!isDirection(direction)) {
    return errorResponse('invalid_direction', 'direction precisa ser "in" ou "out"', 400);
  }

  const amount = body.amount;
  if (!isValidAmount(amount)) {
    return errorResponse(
      'invalid_amount',
      'amount precisa ser um número inteiro, em centavos, maior que zero',
      400,
    );
  }

  const description = normalizedDescription(body.description);
  if (description === null) {
    return errorResponse(
      'invalid_description',
      'description precisa ter entre 1 e 200 caracteres após remover espaços nas pontas',
      400,
    );
  }

  let occurredAt: string | undefined;
  if (body.occurred_at !== undefined) {
    if (!isIsoDateTime(body.occurred_at)) {
      return errorResponse(
        'invalid_occurred_at',
        'occurred_at precisa ser uma data e hora ISO-8601 válida',
        400,
      );
    }
    occurredAt = body.occurred_at;
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
  if (!supabaseUrl || !supabaseAnonKey) {
    return errorResponse('internal_error', 'configuração do servidor ausente', 500);
  }

  // JWT do usuário, nunca service_role: a RLS decide quem pode inserir e a
  // quem pertence a linha, mesmo que o payload tente forjar outro dono.
  // autoRefreshToken desligado porque o client vive só a duração desta
  // invocação: sem isso o SDK arma um timer de refresh que nunca é limpo,
  // o que também aparece em teste como "leak" de recurso.
  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const row: Record<string, unknown> = { direction, amount, description };
  if (occurredAt) row.occurred_at = occurredAt;

  const { data, error, status } = await supabase
    .from('transactions')
    .insert(row)
    .select()
    .single();

  if (error) {
    if (status === 401) {
      return errorResponse('unauthorized', 'sessão inválida ou expirada', 401);
    }
    console.error('transactions insert falhou', { code: error.code });
    return errorResponse('internal_error', 'não foi possível registrar a transação', 500);
  }

  return Response.json(data, { status: 201 });
}
