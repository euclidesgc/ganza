import type { SupabaseClient } from '@supabase/supabase-js';
import { hashContent } from '../_shared/observability/ai_event.ts';

const GOOGLE_AUTH_ENDPOINT = 'https://accounts.google.com/o/oauth2/v2/auth';
const GOOGLE_TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token';
const CALENDAR_SCOPE = 'https://www.googleapis.com/auth/calendar.events';
// `calendar.events` não autoriza nenhuma chamada de identidade (confirmado na
// referência oficial de escopos por endpoint); `openid` é o menor escopo que
// devolve um `id_token` assinado com `sub`, sem pedir e-mail nem perfil.
const IDENTITY_SCOPE = 'openid';

export interface GoogleOAuthConfig {
  clientId: string;
  clientSecret: string;
}

export type StartAuthorizationResult =
  | { ok: true; authorizationUrl: string }
  | { ok: false; reason: 'unauthenticated' }
  | { ok: false; reason: 'start_failed' };

export interface CompleteAuthorizationParams {
  code: string | null;
  state: string | null;
  error: string | null;
}

export type CompleteAuthorizationResult =
  | { ok: true; connectionId: string }
  | { ok: false; reason: 'invalid_state' }
  | { ok: false; reason: 'invalid_payload' }
  | { ok: false; reason: 'authorization_denied' }
  | { ok: false; reason: 'google_unavailable' };

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64UrlDecode(value: string): string {
  const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized.padEnd(normalized.length + ((4 - (normalized.length % 4)) % 4), '=');
  return atob(padded);
}

function randomBase64Url(byteLength: number): string {
  const bytes = new Uint8Array(byteLength);
  crypto.getRandomValues(bytes);
  return base64UrlEncode(bytes);
}

async function pkceChallenge(verifier: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier));
  return base64UrlEncode(new Uint8Array(digest));
}

function bytea(hex: string): string {
  return `\\x${hex}`;
}

function firstRow(data: unknown): Record<string, unknown> | null {
  const candidate = Array.isArray(data) ? data[0] : data;
  return typeof candidate === 'object' && candidate !== null
    ? candidate as Record<string, unknown>
    : null;
}

function subjectFromIdToken(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const parts = value.split('.');
  if (parts.length !== 3) return null;
  try {
    const payload = JSON.parse(base64UrlDecode(parts[1])) as Record<string, unknown>;
    return typeof payload.sub === 'string' && payload.sub.length > 0 ? payload.sub : null;
  } catch {
    return null;
  }
}

async function exchangeCode(
  code: string,
  codeVerifier: string,
  redirectUri: string,
  google: GoogleOAuthConfig,
): Promise<Record<string, unknown>> {
  const response = await fetch(GOOGLE_TOKEN_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      redirect_uri: redirectUri,
      client_id: google.clientId,
      client_secret: google.clientSecret,
      code_verifier: codeVerifier,
    }).toString(),
  });

  if (!response.ok) {
    throw new Error(`troca de code respondeu ${response.status}`);
  }

  const data = await response.json().catch(() => null);
  if (typeof data !== 'object' || data === null) {
    throw new Error('resposta de troca de code em formato inesperado');
  }
  return data as Record<string, unknown>;
}

async function discardAuthorization(supabase: SupabaseClient, stateHash: string): Promise<void> {
  const { error } = await supabase.rpc('google_oauth_authorization_discard_callback', {
    p_state_sha256: stateHash,
  });
  if (error) {
    console.error('google_oauth: descarte de autorização pendente falhou', { code: error.code });
  }
}

// JWT do usuário, nunca service_role: a RPC deriva `user_id` de `auth.uid()`
// dentro do banco (FD-007) e não aceita parâmetro de dono.
export async function startAuthorization(
  supabase: SupabaseClient,
  params: { googleClientId: string; redirectUri: string },
): Promise<StartAuthorizationResult> {
  const state = randomBase64Url(32);
  const codeVerifier = randomBase64Url(48);
  const codeChallenge = await pkceChallenge(codeVerifier);
  const stateHash = bytea(await hashContent(state));

  const { error } = await supabase.rpc('google_oauth_authorization_start', {
    p_state_sha256: stateHash,
    p_secret_value: codeVerifier,
    p_redirect_uri: params.redirectUri,
  });

  if (error) {
    if (error.code === '28000') {
      return { ok: false, reason: 'unauthenticated' };
    }
    console.error('google_oauth: início de autorização falhou', { code: error.code });
    return { ok: false, reason: 'start_failed' };
  }

  const url = new URL(GOOGLE_AUTH_ENDPOINT);
  url.searchParams.set('client_id', params.googleClientId);
  url.searchParams.set('redirect_uri', params.redirectUri);
  url.searchParams.set('response_type', 'code');
  url.searchParams.set('scope', `${IDENTITY_SCOPE} ${CALENDAR_SCOPE}`);
  url.searchParams.set('access_type', 'offline');
  url.searchParams.set('prompt', 'consent');
  url.searchParams.set('state', state);
  url.searchParams.set('code_challenge', codeChallenge);
  url.searchParams.set('code_challenge_method', 'S256');

  return { ok: true, authorizationUrl: url.toString() };
}

// Sem JWT nesta perna: a navegação de OAuth sai do app e volta sem sessão
// Supabase. O state consumido pelas RPCs abaixo é o único insumo de
// identidade aceito (FD-007); por isso o cliente recebido aqui é sempre
// service_role, e nunca lê/escreve as tabelas Calendar diretamente.
export async function completeAuthorization(
  serviceRoleClient: SupabaseClient,
  params: CompleteAuthorizationParams,
  google: GoogleOAuthConfig,
): Promise<CompleteAuthorizationResult> {
  if (!params.state) {
    return { ok: false, reason: 'invalid_state' };
  }

  const stateHash = bytea(await hashContent(params.state));

  const { data: preparedRaw, error: prepareError } = await serviceRoleClient.rpc(
    'google_oauth_authorization_prepare_callback',
    { p_state_sha256: stateHash },
  );

  const prepared = firstRow(preparedRaw);
  if (
    prepareError || !prepared || typeof prepared.secret_value !== 'string' ||
    typeof prepared.redirect_uri !== 'string'
  ) {
    return { ok: false, reason: 'invalid_state' };
  }

  if (params.error) {
    await discardAuthorization(serviceRoleClient, stateHash);
    return { ok: false, reason: 'authorization_denied' };
  }

  if (!params.code) {
    await discardAuthorization(serviceRoleClient, stateHash);
    return { ok: false, reason: 'invalid_payload' };
  }

  let tokens: Record<string, unknown>;
  try {
    tokens = await exchangeCode(
      params.code,
      prepared.secret_value,
      prepared.redirect_uri,
      google,
    );
  } catch {
    await discardAuthorization(serviceRoleClient, stateHash);
    return { ok: false, reason: 'google_unavailable' };
  }

  const googleSubject = subjectFromIdToken(tokens.id_token);
  const refreshValue = tokens.refresh_token;
  if (!googleSubject || typeof refreshValue !== 'string' || refreshValue.length === 0) {
    await discardAuthorization(serviceRoleClient, stateHash);
    return { ok: false, reason: 'google_unavailable' };
  }

  const { data: connectionId, error: completeError } = await serviceRoleClient.rpc(
    'google_oauth_authorization_complete_callback',
    {
      p_state_sha256: stateHash,
      p_google_subject: googleSubject,
      p_primary_calendar_id: 'primary',
      p_secret_value: refreshValue,
    },
  );

  if (completeError || typeof connectionId !== 'string') {
    await discardAuthorization(serviceRoleClient, stateHash);
    return { ok: false, reason: 'google_unavailable' };
  }

  return { ok: true, connectionId };
}
