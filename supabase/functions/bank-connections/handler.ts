import { createClient, type SupabaseClient } from '@supabase/supabase-js';

interface ApiError {
  code: string;
  message: string;
}

const BANK_AGGREGATOR_API_URL = 'https://api.pluggy.ai';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Rede indisponível e resposta HTTP não-ok da Pluggy convergem para o mesmo
// tratamento (502): o chamador não precisa distinguir as duas.
class PluggyUnavailableError extends Error {}

type BankConnectionRow = Record<string, unknown>;
type ConnectionAction = 'connect_token' | 'persist_item' | 'status' | 'disconnect';
type ConnectionStatus = 'pending' | 'connected' | 'error' | 'disconnected';

function errorResponse(code: string, message: string, status: number): Response {
  const body: { error: ApiError } = { error: { code, message } };
  return Response.json(body, { status });
}

function isUuid(value: unknown): value is string {
  return typeof value === 'string' && UUID.test(value);
}

function isNonEmptyString(value: unknown): value is string {
  const trimmed = typeof value === 'string' ? value.trim() : '';
  return trimmed.length > 0 && trimmed.length <= 200;
}

function isConnectionAction(value: unknown): value is ConnectionAction {
  return value === 'connect_token' || value === 'persist_item' || value === 'status' ||
    value === 'disconnect';
}

function mapPluggyStatus(status: string): ConnectionStatus {
  if (status === 'UPDATED') return 'connected';
  if (status === 'LOGIN_ERROR' || status === 'OUTDATED') return 'error';
  return 'pending';
}

interface PluggyItem {
  status: string;
  institutionName: string;
}

function parsePluggyItem(data: unknown): PluggyItem | null {
  if (typeof data !== 'object' || data === null) return null;
  const record = data as Record<string, unknown>;
  const status = record.status;
  const connector = record.connector;
  if (typeof status !== 'string') return null;
  if (typeof connector !== 'object' || connector === null) return null;
  const name = (connector as Record<string, unknown>).name;
  if (typeof name !== 'string') return null;
  return { status, institutionName: name };
}

async function pluggyAuthenticate(clientId: string, clientSecret: string): Promise<string> {
  let response: Response;
  try {
    response = await fetch(`${BANK_AGGREGATOR_API_URL}/auth`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ clientId, clientSecret }),
    });
  } catch {
    throw new PluggyUnavailableError('falha de rede ao autenticar na Pluggy');
  }
  if (!response.ok) {
    throw new PluggyUnavailableError(`autenticação na Pluggy falhou (${response.status})`);
  }
  const data = await response.json().catch(() => null);
  const apiKey = (data as Record<string, unknown> | null)?.apiKey;
  if (typeof apiKey !== 'string') {
    throw new PluggyUnavailableError('resposta de autenticação da Pluggy sem apiKey');
  }
  return apiKey;
}

async function pluggyFetch(path: string, apiKey: string, init: RequestInit = {}): Promise<unknown> {
  let response: Response;
  try {
    response = await fetch(`${BANK_AGGREGATOR_API_URL}${path}`, {
      ...init,
      headers: {
        ...(init.headers ?? {}),
        'X-API-KEY': apiKey,
        'Content-Type': 'application/json',
      },
    });
  } catch {
    throw new PluggyUnavailableError(`falha de rede ao chamar a Pluggy em ${path}`);
  }
  if (!response.ok) {
    throw new PluggyUnavailableError(`Pluggy respondeu ${response.status} em ${path}`);
  }
  if (response.status === 204) return null;
  return await response.json().catch(() => null);
}

function userScopedClient(
  supabaseUrl: string,
  supabaseAnonKey: string,
  authorization: string,
): SupabaseClient {
  return createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

async function findOwnConnection(
  supabase: SupabaseClient,
  connectionId: string,
): Promise<BankConnectionRow | null> {
  const { data, error } = await supabase
    .from('bank_connections')
    .select()
    .eq('id', connectionId)
    .maybeSingle();

  if (error) {
    console.error('bank_connections select falhou', { code: error.code });
    return null;
  }

  return data;
}

function connectionItemId(connection: BankConnectionRow): string | null {
  const itemId = connection.item_id;
  return typeof itemId === 'string' ? itemId : null;
}

async function handleConnectToken(
  pluggyClientId: string,
  pluggyClientSecret: string,
): Promise<Response> {
  const apiKey = await pluggyAuthenticate(pluggyClientId, pluggyClientSecret);
  const data = await pluggyFetch('/connect_token', apiKey, {
    method: 'POST',
    body: JSON.stringify({}),
  });
  const accessToken = (data as Record<string, unknown> | null)?.accessToken;
  if (typeof accessToken !== 'string') {
    throw new PluggyUnavailableError('resposta da Pluggy sem accessToken');
  }
  return Response.json({ access_token: accessToken }, { status: 200 });
}

async function handlePersistItem(
  body: Record<string, unknown>,
  supabase: SupabaseClient,
  pluggyClientId: string,
  pluggyClientSecret: string,
): Promise<Response> {
  const itemId = body.item_id;
  if (!isNonEmptyString(itemId)) {
    return errorResponse('invalid_item_id', 'item_id precisa ser um texto não vazio', 400);
  }

  const apiKey = await pluggyAuthenticate(pluggyClientId, pluggyClientSecret);
  const item = parsePluggyItem(await pluggyFetch(`/items/${itemId}`, apiKey));
  if (item === null) {
    throw new PluggyUnavailableError('item da Pluggy em formato inesperado');
  }

  const { data, error } = await supabase
    .from('bank_connections')
    .insert({
      item_id: itemId,
      institution_name: item.institutionName,
      status: mapPluggyStatus(item.status),
      last_synced_at: new Date().toISOString(),
    })
    .select()
    .single();

  if (error) {
    if (error.code === '23505') {
      return errorResponse('connection_already_exists', 'esta conexão já foi registrada', 409);
    }
    console.error('bank_connections insert falhou', { code: error.code });
    return errorResponse('internal_error', 'não foi possível registrar a conexão', 500);
  }

  return Response.json(data, { status: 201 });
}

async function handleStatus(
  body: Record<string, unknown>,
  supabase: SupabaseClient,
  pluggyClientId: string,
  pluggyClientSecret: string,
): Promise<Response> {
  const connectionId = body.connection_id;
  if (!isUuid(connectionId)) {
    return errorResponse('invalid_connection_id', 'connection_id precisa ser um uuid', 400);
  }

  const connection = await findOwnConnection(supabase, connectionId);
  if (connection === null) {
    return errorResponse('not_found', 'conexão não encontrada', 404);
  }

  const itemId = connectionItemId(connection);
  if (itemId === null) {
    console.error('bank_connections sem item_id', { connection_id: connectionId });
    return errorResponse('internal_error', 'conexão sem item associado', 500);
  }

  const apiKey = await pluggyAuthenticate(pluggyClientId, pluggyClientSecret);
  const item = parsePluggyItem(await pluggyFetch(`/items/${itemId}`, apiKey));
  if (item === null) {
    throw new PluggyUnavailableError('item da Pluggy em formato inesperado');
  }

  const { data, error } = await supabase
    .from('bank_connections')
    .update({
      institution_name: item.institutionName,
      status: mapPluggyStatus(item.status),
      last_synced_at: new Date().toISOString(),
    })
    .eq('id', connectionId)
    .select()
    .single();

  if (error) {
    console.error('bank_connections update falhou', { code: error.code });
    return errorResponse('internal_error', 'não foi possível atualizar o status da conexão', 500);
  }

  return Response.json(data, { status: 200 });
}

async function handleDisconnect(
  body: Record<string, unknown>,
  supabase: SupabaseClient,
  pluggyClientId: string,
  pluggyClientSecret: string,
): Promise<Response> {
  const connectionId = body.connection_id;
  if (!isUuid(connectionId)) {
    return errorResponse('invalid_connection_id', 'connection_id precisa ser um uuid', 400);
  }

  const connection = await findOwnConnection(supabase, connectionId);
  if (connection === null) {
    return errorResponse('not_found', 'conexão não encontrada', 404);
  }

  const itemId = connectionItemId(connection);
  if (itemId === null) {
    console.error('bank_connections sem item_id', { connection_id: connectionId });
    return errorResponse('internal_error', 'conexão sem item associado', 500);
  }

  const apiKey = await pluggyAuthenticate(pluggyClientId, pluggyClientSecret);
  await pluggyFetch(`/items/${itemId}`, apiKey, { method: 'DELETE' });

  const { data, error } = await supabase
    .from('bank_connections')
    .update({ status: 'disconnected', last_synced_at: new Date().toISOString() })
    .eq('id', connectionId)
    .select()
    .single();

  if (error) {
    console.error('bank_connections update falhou', { code: error.code });
    return errorResponse('internal_error', 'não foi possível desconectar', 500);
  }

  return Response.json(data, { status: 200 });
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

  if (!isConnectionAction(body.action)) {
    return errorResponse(
      'invalid_action',
      'action precisa ser "connect_token", "persist_item", "status" ou "disconnect"',
      400,
    );
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
  if (!supabaseUrl || !supabaseAnonKey) {
    return errorResponse('internal_error', 'configuração do servidor ausente', 500);
  }

  // Segredo do projeto, não do usuário: só env, nunca tabela nem Vault — a
  // Pluggy autentica a aplicação inteira com um único par (FD-019).
  const pluggyClientId = Deno.env.get('PLUGGY_CLIENT_ID');
  const pluggyClientSecret = Deno.env.get('PLUGGY_CLIENT_SECRET');
  if (!pluggyClientId || !pluggyClientSecret) {
    return errorResponse(
      'missing_configuration',
      'credenciais da Pluggy não configuradas no servidor',
      503,
    );
  }

  const supabase = userScopedClient(supabaseUrl, supabaseAnonKey, authorization);

  try {
    if (body.action === 'connect_token') {
      return await handleConnectToken(pluggyClientId, pluggyClientSecret);
    }

    if (body.action === 'persist_item') {
      return await handlePersistItem(body, supabase, pluggyClientId, pluggyClientSecret);
    }

    if (body.action === 'status') {
      return await handleStatus(body, supabase, pluggyClientId, pluggyClientSecret);
    }

    return await handleDisconnect(body, supabase, pluggyClientId, pluggyClientSecret);
  } catch (error) {
    if (error instanceof PluggyUnavailableError) {
      console.error('pluggy indisponível', { action: body.action });
      return errorResponse('pluggy_unavailable', 'não foi possível falar com a Pluggy agora', 502);
    }
    console.error('bank-connections falhou de forma inesperada', { action: body.action });
    return errorResponse('internal_error', 'não foi possível concluir a operação', 500);
  }
}
