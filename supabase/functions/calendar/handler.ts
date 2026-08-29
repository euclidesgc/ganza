import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import {
  completeAuthorization,
  type GoogleOAuthConfig,
  startAuthorization,
} from './google_oauth.ts';
import { obtainAccessToken } from './calendar_credentials.ts';
import { GoogleCalendarUnavailableError, listAllEvents } from './google_calendar.ts';
import {
  type CalendarProposalResult,
  cancelCalendarProposal,
  confirmCalendarProposal,
} from './calendar_proposals.ts';

interface ApiError {
  code: string;
  message: string;
}

function errorResponse(code: string, message: string, status: number): Response {
  return Response.json({ error: { code, message } satisfies ApiError }, { status });
}

interface RuntimeConfig {
  supabaseUrl: string;
  supabaseAnonKey: string;
  supabaseServiceRoleKey: string;
  google: GoogleOAuthConfig;
  redirectUri: string;
}

function loadConfig(): RuntimeConfig | null {
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const clientId = Deno.env.get('GOOGLE_OAUTH_CLIENT_ID');
  const clientSecret = Deno.env.get('GOOGLE_OAUTH_CLIENT_SECRET');
  const redirectUri = Deno.env.get('GOOGLE_OAUTH_REDIRECT_URI');
  if (
    !supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey || !clientId || !clientSecret ||
    !redirectUri
  ) {
    return null;
  }
  return {
    supabaseUrl,
    supabaseAnonKey,
    supabaseServiceRoleKey,
    google: { clientId, clientSecret },
    redirectUri,
  };
}

function userClient(config: RuntimeConfig, authorization: string): SupabaseClient {
  return createClient(config.supabaseUrl, config.supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

// service_role só nas duas pernas sem JWT de usuário: o callback do OAuth
// (chega sem sessão do app) e a revelação do refresh guardado no Vault
// (grant fica só para service_role na migration 0017). Ler ou escrever a
// conexão do próprio usuário sempre passa pelo cliente JWT acima.
function serviceClient(config: RuntimeConfig): SupabaseClient {
  return createClient(config.supabaseUrl, config.supabaseServiceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

interface OwnConnection {
  id: string;
  primaryCalendarId: string;
}

async function findOwnConnection(client: SupabaseClient): Promise<OwnConnection | null> {
  const { data, error } = await client
    .from('google_calendar_connections')
    .select('id, primary_calendar_id')
    .maybeSingle();
  if (error || !data) return null;
  const record = data as Record<string, unknown>;
  const id = record.id;
  const primaryCalendarId = record.primary_calendar_id;
  if (typeof id !== 'string' || typeof primaryCalendarId !== 'string') return null;
  return { id, primaryCalendarId };
}

async function handleAuthorize(config: RuntimeConfig, authorization: string): Promise<Response> {
  const result = await startAuthorization(userClient(config, authorization), {
    googleClientId: config.google.clientId,
    redirectUri: config.redirectUri,
  });

  if (result.ok) {
    return Response.json({ authorization_url: result.authorizationUrl }, { status: 200 });
  }
  if (result.reason === 'unauthenticated') {
    return errorResponse('unauthorized', 'sessão inválida ou expirada', 401);
  }
  return errorResponse('internal_error', 'não foi possível iniciar a autorização', 500);
}

function htmlResponse(status: number, message: string): Response {
  const body =
    `<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"></head><body><p>${message}</p></body></html>`;
  return new Response(body, { status, headers: { 'Content-Type': 'text/html; charset=utf-8' } });
}

// Sem JWT nesta rota (FD-007): o único insumo de identidade é o `state` da
// query, e é `completeAuthorization` quem o resolve — o handler não lê nem
// escreve nenhuma tabela Calendar diretamente aqui.
async function handleCallback(config: RuntimeConfig, url: URL): Promise<Response> {
  const result = await completeAuthorization(
    serviceClient(config),
    {
      code: url.searchParams.get('code'),
      state: url.searchParams.get('state'),
      error: url.searchParams.get('error'),
    },
    config.google,
  );

  if (result.ok) {
    return htmlResponse(200, 'Conexão com o Google Calendar concluída. Volte ao aplicativo.');
  }

  switch (result.reason) {
    case 'authorization_denied':
      return htmlResponse(200, 'Conexão cancelada. Você pode tentar novamente quando quiser.');
    case 'invalid_state':
      return htmlResponse(
        400,
        'Este link de conexão não é mais válido. Tente novamente pelo aplicativo.',
      );
    case 'invalid_payload':
      return htmlResponse(
        400,
        'A resposta do Google veio incompleta. Tente novamente pelo aplicativo.',
      );
    default:
      return htmlResponse(
        502,
        'O Google Calendar está indisponível agora. Tente novamente em instantes.',
      );
  }
}

// FD-008: o status devolvido aqui é derivado tentando renovar o acesso, nunca
// lido de/gravado em `google_calendar_connections.status` — a migration 0017
// não tem RPC que escreva `reconnect_required`, então persistir esse valor
// não é possível nem desejável; a leitura seguinte deriva de novo.
async function handleConnection(config: RuntimeConfig, authorization: string): Promise<Response> {
  const connection = await findOwnConnection(userClient(config, authorization));
  if (!connection) {
    return Response.json({ status: 'disconnected' }, { status: 200 });
  }

  const renewal = await obtainAccessToken(serviceClient(config), connection.id, config.google);
  if (renewal.ok) {
    return Response.json(
      { status: 'connected', primary_calendar_id: connection.primaryCalendarId },
      { status: 200 },
    );
  }
  if (renewal.reason === 'reconnect_required') {
    return Response.json({ status: 'reconnect_required' }, { status: 200 });
  }
  if (renewal.reason === 'connection_not_found') {
    return Response.json({ status: 'disconnected' }, { status: 200 });
  }
  return errorResponse('google_unavailable', 'não foi possível confirmar a conexão agora', 502);
}

const MAX_PAST_DAYS = 90;
const MAX_FUTURE_DAYS = 365;
const DAY_MS = 24 * 60 * 60 * 1000;

function parseWindow(url: URL): { timeMin: string; timeMax: string } | null {
  const timeMinRaw = url.searchParams.get('time_min');
  const timeMaxRaw = url.searchParams.get('time_max');
  if (!timeMinRaw || !timeMaxRaw) return null;

  const timeMin = new Date(timeMinRaw);
  const timeMax = new Date(timeMaxRaw);
  if (Number.isNaN(timeMin.getTime()) || Number.isNaN(timeMax.getTime())) return null;
  if (timeMin.getTime() >= timeMax.getTime()) return null;

  const now = Date.now();
  const earliest = now - MAX_PAST_DAYS * DAY_MS;
  const latest = now + MAX_FUTURE_DAYS * DAY_MS;
  if (timeMin.getTime() < earliest || timeMax.getTime() > latest) return null;

  return { timeMin: timeMin.toISOString(), timeMax: timeMax.toISOString() };
}

async function handleEvents(
  config: RuntimeConfig,
  authorization: string,
  url: URL,
): Promise<Response> {
  const window = parseWindow(url);
  if (!window) {
    return errorResponse(
      'invalid_payload',
      'time_min e time_max precisam ser datas ISO dentro do horizonte permitido',
      400,
    );
  }

  const client = userClient(config, authorization);
  const connection = await findOwnConnection(client);
  if (!connection) {
    return errorResponse(
      'connection_required',
      'conecte o Google Calendar antes de listar a agenda',
      409,
    );
  }

  const access = await obtainAccessToken(serviceClient(config), connection.id, config.google);
  if (!access.ok) {
    if (access.reason === 'reconnect_required') {
      return errorResponse('reconnect_required', 'a conexão com o Google Calendar expirou', 409);
    }
    if (access.reason === 'connection_not_found') {
      return errorResponse(
        'connection_required',
        'conecte o Google Calendar antes de listar a agenda',
        409,
      );
    }
    return errorResponse(
      'google_unavailable',
      'não foi possível renovar o acesso ao Google Calendar agora',
      502,
    );
  }

  try {
    const events = await listAllEvents(access.accessToken, window.timeMin, window.timeMax);
    return Response.json({ events }, { status: 200 });
  } catch (err) {
    if (err instanceof GoogleCalendarUnavailableError) {
      return errorResponse(
        'google_unavailable',
        'não foi possível consultar o Google Calendar agora',
        502,
      );
    }
    throw err;
  }
}

function isProposalAction(value: unknown): value is 'confirm' | 'cancel' {
  return value === 'confirm' || value === 'cancel';
}

const PROPOSAL_ERROR_STATUS: Record<string, number> = {
  proposal_not_found: 404,
  proposal_not_pending: 409,
  invalid_payload: 400,
  event_not_found: 404,
  event_ambiguous: 409,
  recurring_event_unsupported: 409,
  google_unavailable: 502,
  write_failed: 500,
};

function proposalResultResponse(result: CalendarProposalResult): Response {
  if (result.ok) {
    return Response.json(
      { status: result.status, proposal_id: result.proposalId },
      { status: 200 },
    );
  }
  const status = PROPOSAL_ERROR_STATUS[result.code] ?? 500;
  return errorResponse(result.code, 'não foi possível concluir a proposta', status);
}

async function handleProposals(
  config: RuntimeConfig,
  authorization: string,
  req: Request,
): Promise<Response> {
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

  if (!isProposalAction(body.action)) {
    return errorResponse('invalid_action', 'action precisa ser "confirm" ou "cancel"', 400);
  }

  const client = userClient(config, authorization);

  if (body.action === 'cancel') {
    return proposalResultResponse(await cancelCalendarProposal(client, proposalId));
  }

  const connection = await findOwnConnection(client);
  if (!connection) {
    return errorResponse(
      'connection_required',
      'conecte o Google Calendar antes de confirmar',
      409,
    );
  }

  const access = await obtainAccessToken(serviceClient(config), connection.id, config.google);
  if (!access.ok) {
    if (access.reason === 'reconnect_required') {
      return errorResponse('reconnect_required', 'a conexão com o Google Calendar expirou', 409);
    }
    if (access.reason === 'connection_not_found') {
      return errorResponse(
        'connection_required',
        'conecte o Google Calendar antes de confirmar',
        409,
      );
    }
    return errorResponse(
      'google_unavailable',
      'não foi possível renovar o acesso ao Google Calendar agora',
      502,
    );
  }

  return proposalResultResponse(
    await confirmCalendarProposal(client, access.accessToken, proposalId),
  );
}

// Separado do index.ts para poder ser testado sem subir servidor: o
// `Deno.serve` do index é a borda, isto é o comportamento. O roteamento por
// path (em vez do padrão `action` no corpo usado por outras functions) é
// exigido pelo callback: o Google redireciona por GET com querystring, sem
// como carregar um corpo JSON.
export default async function handler(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const route = url.pathname.split('/').filter(Boolean).pop();

  if (route === 'callback') {
    if (req.method !== 'GET') {
      return errorResponse('method_not_allowed', 'use GET', 405);
    }
    const config = loadConfig();
    if (!config) return errorResponse('internal_error', 'configuração do servidor ausente', 500);
    return await handleCallback(config, url);
  }

  // Toda outra rota de Calendar exige o JWT do usuário: o callback acima é
  // a única exceção pública, pela impossibilidade de carregar sessão do app
  // depois da navegação externa ao Google (FD-007).
  const authorization = req.headers.get('Authorization');
  if (!authorization) {
    return errorResponse('unauthorized', 'sessão ausente', 401);
  }

  const config = loadConfig();
  if (!config) return errorResponse('internal_error', 'configuração do servidor ausente', 500);

  if (route === 'authorize') {
    if (req.method !== 'POST') return errorResponse('method_not_allowed', 'use POST', 405);
    return await handleAuthorize(config, authorization);
  }

  if (route === 'connection') {
    if (req.method !== 'GET') return errorResponse('method_not_allowed', 'use GET', 405);
    return await handleConnection(config, authorization);
  }

  if (route === 'events') {
    if (req.method !== 'GET') return errorResponse('method_not_allowed', 'use GET', 405);
    return await handleEvents(config, authorization, url);
  }

  if (route === 'proposals') {
    if (req.method !== 'POST') return errorResponse('method_not_allowed', 'use POST', 405);
    return await handleProposals(config, authorization, req);
  }

  return errorResponse('not_found', 'rota não encontrada', 404);
}
