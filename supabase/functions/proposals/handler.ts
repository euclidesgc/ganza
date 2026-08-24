import { createClient } from '@supabase/supabase-js';
import { cancelProposal, confirmProposal } from '../_shared/ai/proposal_writer.ts';

interface ApiError {
  code: string;
  message: string;
}

function errorResponse(code: string, message: string, status: number): Response {
  return Response.json({ error: { code, message } satisfies ApiError }, { status });
}

function isAction(value: unknown): value is 'confirm' | 'cancel' {
  return value === 'confirm' || value === 'cancel';
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

  const proposalId = body.proposal_id;
  if (typeof proposalId !== 'string' || proposalId.length === 0) {
    return errorResponse(
      'invalid_proposal_id',
      'proposal_id precisa ser uma string não-vazia',
      400,
    );
  }

  const action = body.action;
  if (!isAction(action)) {
    return errorResponse('invalid_action', 'action precisa ser "confirm" ou "cancel"', 400);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
  if (!supabaseUrl || !supabaseAnonKey) {
    return errorResponse('internal_error', 'configuração do servidor ausente', 500);
  }

  // JWT do usuário, nunca service_role: a RLS decide o dono da proposta e da
  // transação, mesmo que o payload tente confirmar proposta alheia.
  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const result = action === 'confirm'
    ? await confirmProposal(supabase, proposalId)
    : await cancelProposal(supabase, proposalId);

  if (!result.ok) {
    switch (result.code) {
      case 'proposta_nao_encontrada':
        return errorResponse('proposta_nao_encontrada', 'proposta não encontrada', 404);
      case 'proposta_nao_pendente':
        return errorResponse('proposta_nao_pendente', 'a proposta já não está pendente', 409);
      case 'payload_invalido':
        return errorResponse('payload_invalido', 'o payload da proposta é inválido', 400);
      default:
        return errorResponse('write_failed', result.code, 500);
    }
  }

  const status = action === 'confirm' ? 'confirmed' : 'cancelled';
  return Response.json({ status, proposal_id: proposalId }, { status: 200 });
}
