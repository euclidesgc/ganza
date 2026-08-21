import { createClient } from '@supabase/supabase-js';

interface ApiError {
  code: string;
  message: string;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function errorResponse(code: string, message: string, status: number): Response {
  const body: { error: ApiError } = { error: { code, message } };
  return Response.json(body, { status });
}

function isUuid(value: unknown): value is string {
  return typeof value === 'string' && UUID.test(value);
}

function isAction(value: unknown): value is 'save' | 'test' | 'delete' {
  return value === 'save' || value === 'test' || value === 'delete';
}

function normalizedModel(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (trimmed.length < 1 || trimmed.length > 100) return null;
  return trimmed;
}

function isValidApiKey(value: unknown): value is string {
  return typeof value === 'string' && value.length >= 8 && value.length <= 4000;
}

// Bate direto no GoTrue com o Authorization original, sem client de sessão:
// é o único jeito de saber quem é o requisitante antes de decidir o que
// mandar para a service_role — o corpo da requisição nunca é fonte disso.
async function resolveRequesterId(
  supabaseUrl: string,
  supabaseAnonKey: string,
  authorization: string,
): Promise<string | null> {
  const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: { Authorization: authorization, apikey: supabaseAnonKey },
  });
  if (!response.ok) return null;
  const data = await response.json();
  if (typeof data !== 'object' || data === null) return null;
  const id = (data as Record<string, unknown>).id;
  return typeof id === 'string' ? id : null;
}

async function handleSave(
  body: Record<string, unknown>,
  authorization: string,
  supabaseUrl: string,
  supabaseAnonKey: string,
  supabaseServiceRoleKey: string,
): Promise<Response> {
  const providerKindId = body.provider_kind_id;
  if (!isUuid(providerKindId)) {
    return errorResponse('invalid_provider_kind_id', 'provider_kind_id precisa ser um uuid', 400);
  }

  const model = normalizedModel(body.model);
  if (model === null) {
    return errorResponse('invalid_model', 'model precisa ser um texto de 1 a 100 caracteres', 400);
  }

  const apiKey = body.api_key;
  if (!isValidApiKey(apiKey)) {
    return errorResponse(
      'invalid_api_key',
      'api_key precisa ser um texto de 8 a 4000 caracteres',
      400,
    );
  }

  const requesterId = await resolveRequesterId(supabaseUrl, supabaseAnonKey, authorization);
  if (requesterId === null) {
    return errorResponse('unauthorized', 'sessão inválida ou expirada', 401);
  }

  const serviceClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await serviceClient.rpc('ai_credential_save', {
    user_id: requesterId,
    provider_kind_id: providerKindId,
    model,
    api_key: apiKey,
  });

  if (error) {
    if (error.code === '23505') {
      return errorResponse(
        'provider_already_configured',
        'já existe uma credencial para este provedor',
        409,
      );
    }
    console.error('ai_credential_save falhou', { code: error.code });
    return errorResponse('internal_error', 'não foi possível salvar a credencial', 500);
  }

  return Response.json(
    { id: data, provider_kind_id: providerKindId, model, key_last4: apiKey.slice(-4) },
    { status: 201 },
  );
}

async function handleTest(
  body: Record<string, unknown>,
  authorization: string,
  supabaseUrl: string,
  supabaseAnonKey: string,
  supabaseServiceRoleKey: string,
): Promise<Response> {
  const credentialId = body.credential_id;
  if (!isUuid(credentialId)) {
    return errorResponse('invalid_credential_id', 'credential_id precisa ser um uuid', 400);
  }

  // Passo 1: resolve o secret_ref com o JWT do requisitante — a RLS de
  // ai_user_credentials filtra por dono sozinha. Passo 2, abaixo, só abre a
  // service_role depois disso, e só para o uuid que este passo devolveu.
  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await userClient
    .from('ai_user_credentials')
    .select('secret_ref')
    .eq('id', credentialId)
    .maybeSingle();

  if (error) {
    console.error('ai_user_credentials select falhou', { code: error.code });
    return errorResponse('internal_error', 'não foi possível localizar a credencial', 500);
  }

  if (!data || typeof data.secret_ref !== 'string') {
    return errorResponse('not_found', 'credencial não encontrada', 404);
  }

  const secretRef = data.secret_ref;

  const serviceClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Só decifra para provar que o Vault entrega a chave de volta; chamar o
  // provedor de verdade é da camada de IA da Fase 6 (ai_providers/execute()).
  const { error: revealError } = await serviceClient.rpc('ai_credential_reveal', {
    secret_ref: secretRef,
  });

  if (revealError) {
    console.error('ai_credential_reveal falhou', { code: revealError.code });
    return errorResponse('provider_key_invalid', 'não foi possível validar a chave', 502);
  }

  return Response.json({ ok: true }, { status: 200 });
}

async function handleDelete(
  body: Record<string, unknown>,
  authorization: string,
  supabaseUrl: string,
  supabaseAnonKey: string,
): Promise<Response> {
  const credentialId = body.credential_id;
  if (!isUuid(credentialId)) {
    return errorResponse('invalid_credential_id', 'credential_id precisa ser um uuid', 400);
  }

  // Sem service_role aqui: a RLS de dono já restringe a linha e o gatilho de
  // 0008 apaga o segredo do Vault junto — escalar privilégio seria supérfluo.
  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await userClient
    .from('ai_user_credentials')
    .delete()
    .eq('id', credentialId)
    .select('id')
    .maybeSingle();

  if (error) {
    console.error('ai_user_credentials delete falhou', { code: error.code });
    return errorResponse('internal_error', 'não foi possível apagar a credencial', 500);
  }

  if (!data) {
    return errorResponse('not_found', 'credencial não encontrada', 404);
  }

  return Response.json({ ok: true }, { status: 200 });
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

  if (!isAction(body.action)) {
    return errorResponse('invalid_action', 'action precisa ser "save", "test" ou "delete"', 400);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
    return errorResponse('internal_error', 'configuração do servidor ausente', 500);
  }

  if (body.action === 'save') {
    return handleSave(body, authorization, supabaseUrl, supabaseAnonKey, supabaseServiceRoleKey);
  }

  if (body.action === 'test') {
    return handleTest(body, authorization, supabaseUrl, supabaseAnonKey, supabaseServiceRoleKey);
  }

  return handleDelete(body, authorization, supabaseUrl, supabaseAnonKey);
}
