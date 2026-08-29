import type { SupabaseClient } from '@supabase/supabase-js';
import type { GoogleOAuthConfig } from './google_oauth.ts';

const GOOGLE_TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token';

export type AccessTokenResult =
  | { ok: true; accessToken: string; expiresAt: string }
  | { ok: false; reason: 'connection_not_found' }
  | { ok: false; reason: 'reconnect_required' }
  | { ok: false; reason: 'google_unavailable' };

// `google_calendar_connection_secret_reveal` só concede EXECUTE a
// service_role na migration 0017 — o SELECT liberado a `authenticated` nem
// inclui a coluna de referência ao Vault. Quem chama esta função já validou
// que `connectionId` pertence ao requisitante, sob RLS, antes de chegar aqui.
export async function obtainAccessToken(
  serviceRoleClient: SupabaseClient,
  connectionId: string,
  google: GoogleOAuthConfig,
): Promise<AccessTokenResult> {
  const { data: refreshValue, error: revealError } = await serviceRoleClient.rpc(
    'google_calendar_connection_secret_reveal',
    { p_connection_id: connectionId },
  );

  if (revealError) {
    console.error('calendar_credentials: revelação de credencial falhou', {
      code: revealError.code,
    });
    return { ok: false, reason: 'connection_not_found' };
  }
  if (typeof refreshValue !== 'string' || refreshValue.length === 0) {
    return { ok: false, reason: 'connection_not_found' };
  }

  let response: Response;
  try {
    response = await fetch(GOOGLE_TOKEN_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'refresh_token',
        refresh_token: refreshValue,
        client_id: google.clientId,
        client_secret: google.clientSecret,
      }).toString(),
    });
  } catch {
    console.error('calendar_credentials: renovação de acesso falhou por rede');
    return { ok: false, reason: 'google_unavailable' };
  }

  if (!response.ok) {
    const body = await response.json().catch(() => null);
    const errorCode = (body as Record<string, unknown> | null)?.error;
    if (errorCode === 'invalid_grant') {
      return { ok: false, reason: 'reconnect_required' };
    }
    console.error('calendar_credentials: renovação de acesso recusada', {
      status: response.status,
    });
    return { ok: false, reason: 'google_unavailable' };
  }

  const data = await response.json().catch(() => null);
  if (typeof data !== 'object' || data === null) {
    return { ok: false, reason: 'google_unavailable' };
  }

  const record = data as Record<string, unknown>;
  const accessToken = record.access_token;
  const expiresIn = record.expires_in;
  if (typeof accessToken !== 'string' || typeof expiresIn !== 'number') {
    return { ok: false, reason: 'google_unavailable' };
  }

  return {
    ok: true,
    accessToken,
    expiresAt: new Date(Date.now() + expiresIn * 1000).toISOString(),
  };
}
