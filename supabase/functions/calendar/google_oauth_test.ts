import { assertEquals } from '@std/assert';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import {
  completeAuthorization,
  type GoogleOAuthConfig,
  startAuthorization,
} from './google_oauth.ts';
import { hashContent } from '../_shared/observability/ai_event.ts';

const SUPABASE_URL = 'https://stub.supabase.local';
const ANON_KEY = 'anon-key-stub';
const SERVICE_ROLE_KEY = 'service-role-key-stub';
const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const GOOGLE_CONFIG: GoogleOAuthConfig = {
  clientId: 'client-id-stub',
  clientSecret: 'client-secret-stub',
};
const GOOGLE_CLIENT_ID = GOOGLE_CONFIG.clientId;
const REDIRECT_URI = 'https://ganza.app/oauth/google/callback';
const JWT_DO_USUARIO = 'Bearer jwt-do-usuario';
const AUTORIZACAO_ID = '11111111-1111-4111-8111-111111111111';
const CONEXAO_ID = '22222222-2222-4222-8222-222222222222';
const VERIFIER = 'verificador-pkce-guardado-no-vault';

interface ChamadaFetch {
  url: string;
  metodo: string | undefined;
  headers: Headers;
  corpo: unknown;
}

async function comFetchStub<T>(
  responder: (chamada: ChamadaFetch) => Response,
  executar: () => Promise<T>,
): Promise<{ resultado: T; chamadas: ChamadaFetch[] }> {
  const original = globalThis.fetch;
  const chamadas: ChamadaFetch[] = [];
  globalThis.fetch = ((entrada: string | URL | Request, init?: RequestInit) => {
    const chamada: ChamadaFetch = {
      url: typeof entrada === 'string' ? entrada : entrada.toString(),
      metodo: init?.method,
      headers: new Headers(init?.headers ?? {}),
      corpo: init?.body
        ? (typeof init.body === 'string' && init.body.startsWith('{')
          ? JSON.parse(init.body)
          : init.body)
        : undefined,
    };
    chamadas.push(chamada);
    return Promise.resolve(responder(chamada));
  }) as typeof fetch;

  try {
    const resultado = await executar();
    return { resultado, chamadas };
  } finally {
    globalThis.fetch = original;
  }
}

function client(apiKey: string, authorization?: string): SupabaseClient {
  return createClient(SUPABASE_URL, apiKey, {
    global: authorization ? { headers: { Authorization: authorization } } : undefined,
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

function base64Url(value: string): string {
  return btoa(value).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function fakeIdToken(sub: string): string {
  const header = base64Url(JSON.stringify({ alg: 'none', typ: 'JWT' }));
  const payload = base64Url(JSON.stringify({ sub }));
  return `${header}.${payload}.assinatura-stub`;
}

async function pkceChallengeIndependente(verifier: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier));
  let binary = '';
  for (const byte of new Uint8Array(digest)) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

Deno.test(
  'identidade: startAuthorization usa o cliente com o JWT recebido, sem parâmetro de dono e sem acesso direto às tabelas',
  async () => {
    const { resultado, chamadas } = await comFetchStub(
      (chamada) => {
        if (chamada.url.includes('/rest/v1/rpc/google_oauth_authorization_start')) {
          return Response.json(AUTORIZACAO_ID, { status: 200 });
        }
        return new Response(null, { status: 404 });
      },
      () =>
        startAuthorization(client(ANON_KEY, JWT_DO_USUARIO), {
          googleClientId: GOOGLE_CLIENT_ID,
          redirectUri: REDIRECT_URI,
        }),
    );

    assertEquals(resultado.ok, true);
    assertEquals(chamadas.length, 1);

    const chamada = chamadas[0];
    assertEquals(chamada.headers.get('apikey'), ANON_KEY);
    assertEquals(chamada.headers.get('Authorization'), JWT_DO_USUARIO);

    const corpo = chamada.corpo as Record<string, unknown>;
    assertEquals('user_id' in corpo, false);
    assertEquals('p_user_id' in corpo, false);
    assertEquals(typeof corpo.p_state_sha256, 'string');
    assertEquals((corpo.p_state_sha256 as string).startsWith('\\x'), true);
    assertEquals(corpo.p_redirect_uri, REDIRECT_URI);

    for (const feita of chamadas) {
      assertEquals(feita.url.includes('/rest/v1/google_oauth_authorizations'), false);
      assertEquals(feita.url.includes('/rest/v1/google_calendar_connections'), false);
    }
  },
);

Deno.test(
  'startAuthorization monta a URL de consentimento com state, PKCE, access_type=offline, prompt=consent e o escopo do calendário',
  async () => {
    const { resultado } = await comFetchStub(
      () => Response.json(AUTORIZACAO_ID, { status: 200 }),
      () =>
        startAuthorization(client(ANON_KEY, JWT_DO_USUARIO), {
          googleClientId: GOOGLE_CLIENT_ID,
          redirectUri: REDIRECT_URI,
        }),
    );

    if (!resultado.ok) throw new Error('esperava sucesso');
    const url = new URL(resultado.authorizationUrl);
    assertEquals(url.searchParams.get('access_type'), 'offline');
    assertEquals(url.searchParams.get('prompt'), 'consent');
    assertEquals(url.searchParams.get('code_challenge_method'), 'S256');
    assertEquals((url.searchParams.get('state') ?? '').length > 0, true);
    assertEquals((url.searchParams.get('code_challenge') ?? '').length > 0, true);
    const escopos = (url.searchParams.get('scope') ?? '').split(' ');
    assertEquals(escopos.includes('https://www.googleapis.com/auth/calendar.events'), true);
  },
);

Deno.test(
  'startAuthorization deriva code_challenge por SHA-256 do verificador enviado à RPC (S256, RFC 7636)',
  async () => {
    const { resultado, chamadas } = await comFetchStub(
      () => Response.json(AUTORIZACAO_ID, { status: 200 }),
      () =>
        startAuthorization(client(ANON_KEY, JWT_DO_USUARIO), {
          googleClientId: GOOGLE_CLIENT_ID,
          redirectUri: REDIRECT_URI,
        }),
    );

    if (!resultado.ok) throw new Error('esperava sucesso');
    const corpo = chamadas[0].corpo as Record<string, unknown>;
    const verifier = corpo.p_secret_value as string;
    const url = new URL(resultado.authorizationUrl);
    assertEquals(url.searchParams.get('code_challenge'), await pkceChallengeIndependente(verifier));
  },
);

Deno.test(
  'startAuthorization grava o hash SHA-256 do mesmo state que vai na URL de consentimento',
  async () => {
    const { resultado, chamadas } = await comFetchStub(
      () => Response.json(AUTORIZACAO_ID, { status: 200 }),
      () =>
        startAuthorization(client(ANON_KEY, JWT_DO_USUARIO), {
          googleClientId: GOOGLE_CLIENT_ID,
          redirectUri: REDIRECT_URI,
        }),
    );

    if (!resultado.ok) throw new Error('esperava sucesso');
    const url = new URL(resultado.authorizationUrl);
    const stateNaUrl = url.searchParams.get('state')!;
    const corpo = chamadas[0].corpo as Record<string, unknown>;
    assertEquals(corpo.p_state_sha256, `\\x${await hashContent(stateNaUrl)}`);
  },
);

Deno.test(
  'startAuthorization devolve unauthenticated quando a RPC recusa por auth.uid() nulo (28000)',
  async () => {
    const { resultado } = await comFetchStub(
      () => Response.json({ code: '28000', message: 'authentication required' }, { status: 400 }),
      () =>
        startAuthorization(client(ANON_KEY, 'Bearer jwt-invalido'), {
          googleClientId: GOOGLE_CLIENT_ID,
          redirectUri: REDIRECT_URI,
        }),
    );
    assertEquals(resultado, { ok: false, reason: 'unauthenticated' });
  },
);

Deno.test('startAuthorization devolve start_failed em erro genérico da RPC', async () => {
  const { resultado } = await comFetchStub(
    () => Response.json({ code: '55000', message: 'algo deu errado' }, { status: 500 }),
    () =>
      startAuthorization(client(ANON_KEY, JWT_DO_USUARIO), {
        googleClientId: GOOGLE_CLIENT_ID,
        redirectUri: REDIRECT_URI,
      }),
  );
  assertEquals(resultado, { ok: false, reason: 'start_failed' });
});

// Consumido e expirado colapsam no mesmo resultado: a RPC de preparação já
// filtra `expires_at > now()` e não devolve linha em nenhum dos dois casos,
// então a ponte do callback não tem como (nem precisa) diferenciá-los.
Deno.test(
  'completeAuthorization: state já consumido ou vencido pelo purge não cria vínculo',
  async () => {
    const { resultado, chamadas } = await comFetchStub(
      (chamada) => {
        if (chamada.url.includes('/rpc/google_oauth_authorization_prepare_callback')) {
          return Response.json([], { status: 200 });
        }
        return new Response(null, { status: 404 });
      },
      () =>
        completeAuthorization(
          client(SERVICE_ROLE_KEY),
          { code: 'auth-code', state: 'state-consumido-ou-vencido', error: null },
          GOOGLE_CONFIG,
        ),
    );

    assertEquals(resultado, { ok: false, reason: 'invalid_state' });
    assertEquals(
      chamadas.some((c) =>
        c.url.includes('complete_callback') || c.url.includes('discard_callback')
      ),
      false,
    );
  },
);

Deno.test(
  'completeAuthorization: sucesso chama prepare e depois complete, nunca discard, e não acessa tabela diretamente',
  async () => {
    const idToken = fakeIdToken('google-sub-abc');
    const { resultado, chamadas } = await comFetchStub(
      (chamada) => {
        if (chamada.url.includes('prepare_callback')) {
          return Response.json([{ secret_value: VERIFIER, redirect_uri: REDIRECT_URI }], {
            status: 200,
          });
        }
        if (chamada.url === GOOGLE_TOKEN_URL) {
          return Response.json(
            { access_token: 'AT', refresh_token: 'RT-nova', id_token: idToken, expires_in: 3600 },
            { status: 200 },
          );
        }
        if (chamada.url.includes('complete_callback')) {
          return Response.json(CONEXAO_ID, { status: 200 });
        }
        return new Response(null, { status: 404 });
      },
      () =>
        completeAuthorization(
          client(SERVICE_ROLE_KEY),
          { code: 'auth-code', state: 'state-valido', error: null },
          GOOGLE_CONFIG,
        ),
    );

    assertEquals(resultado, { ok: true, connectionId: CONEXAO_ID });

    const urls = chamadas.map((c) => c.url);
    assertEquals(urls.some((u) => u.includes('prepare_callback')), true);
    assertEquals(urls.some((u) => u === GOOGLE_TOKEN_URL), true);
    assertEquals(urls.some((u) => u.includes('complete_callback')), true);
    assertEquals(urls.some((u) => u.includes('discard_callback')), false);

    const chamadaComplete = chamadas.find((c) => c.url.includes('complete_callback'))!;
    const corpo = chamadaComplete.corpo as Record<string, unknown>;
    assertEquals(corpo.p_google_subject, 'google-sub-abc');
    assertEquals(corpo.p_primary_calendar_id, 'primary');
    assertEquals(corpo.p_secret_value, 'RT-nova');
    assertEquals('user_id' in corpo, false);
    assertEquals('p_user_id' in corpo, false);

    for (const chamada of chamadas) {
      assertEquals(chamada.url.includes('/rest/v1/google_oauth_authorizations'), false);
      assertEquals(chamada.url.includes('/rest/v1/google_calendar_connections'), false);
    }
  },
);

Deno.test(
  'completeAuthorization: negação do usuário descarta a autorização pendente sem completar',
  async () => {
    const { resultado, chamadas } = await comFetchStub(
      (chamada) => {
        if (chamada.url.includes('prepare_callback')) {
          return Response.json([{ secret_value: VERIFIER, redirect_uri: REDIRECT_URI }], {
            status: 200,
          });
        }
        if (chamada.url.includes('discard_callback')) {
          return Response.json(true, { status: 200 });
        }
        return new Response(null, { status: 404 });
      },
      () =>
        completeAuthorization(
          client(SERVICE_ROLE_KEY),
          { code: null, state: 'state-negado', error: 'access_denied' },
          GOOGLE_CONFIG,
        ),
    );

    assertEquals(resultado, { ok: false, reason: 'authorization_denied' });
    const urls = chamadas.map((c) => c.url);
    assertEquals(urls.some((u) => u.includes('discard_callback')), true);
    assertEquals(urls.some((u) => u.includes('complete_callback')), false);
    assertEquals(urls.some((u) => u === GOOGLE_TOKEN_URL), false);
  },
);

Deno.test(
  'completeAuthorization: falha na troca de code descarta a autorização pendente',
  async () => {
    const { resultado, chamadas } = await comFetchStub(
      (chamada) => {
        if (chamada.url.includes('prepare_callback')) {
          return Response.json([{ secret_value: VERIFIER, redirect_uri: REDIRECT_URI }], {
            status: 200,
          });
        }
        if (chamada.url === GOOGLE_TOKEN_URL) {
          return Response.json({ error: 'invalid_grant' }, { status: 400 });
        }
        if (chamada.url.includes('discard_callback')) {
          return Response.json(true, { status: 200 });
        }
        return new Response(null, { status: 404 });
      },
      () =>
        completeAuthorization(
          client(SERVICE_ROLE_KEY),
          { code: 'code-invalido', state: 'state-valido', error: null },
          GOOGLE_CONFIG,
        ),
    );

    assertEquals(resultado, { ok: false, reason: 'google_unavailable' });
    const urls = chamadas.map((c) => c.url);
    assertEquals(urls.some((u) => u.includes('discard_callback')), true);
    assertEquals(urls.some((u) => u.includes('complete_callback')), false);
  },
);

Deno.test(
  'completeAuthorization: ausência de code sem error descarta a autorização como payload inválido',
  async () => {
    const { resultado, chamadas } = await comFetchStub(
      (chamada) => {
        if (chamada.url.includes('prepare_callback')) {
          return Response.json([{ secret_value: VERIFIER, redirect_uri: REDIRECT_URI }], {
            status: 200,
          });
        }
        if (chamada.url.includes('discard_callback')) {
          return Response.json(true, { status: 200 });
        }
        return new Response(null, { status: 404 });
      },
      () =>
        completeAuthorization(
          client(SERVICE_ROLE_KEY),
          { code: null, state: 'state-valido', error: null },
          GOOGLE_CONFIG,
        ),
    );

    assertEquals(resultado, { ok: false, reason: 'invalid_payload' });
    assertEquals(chamadas.some((c) => c.url.includes('discard_callback')), true);
  },
);

Deno.test(
  'identidade: a resposta do callback nunca contém user_id, e a ponte só usa o hash do state',
  async () => {
    const idToken = fakeIdToken('google-sub-xyz');
    const { resultado } = await comFetchStub(
      (chamada) => {
        if (chamada.url.includes('prepare_callback')) {
          return Response.json([{ secret_value: VERIFIER, redirect_uri: REDIRECT_URI }], {
            status: 200,
          });
        }
        if (chamada.url === GOOGLE_TOKEN_URL) {
          return Response.json(
            { access_token: 'AT', refresh_token: 'RT', id_token: idToken, expires_in: 3600 },
            { status: 200 },
          );
        }
        if (chamada.url.includes('complete_callback')) {
          return Response.json(CONEXAO_ID, { status: 200 });
        }
        return new Response(null, { status: 404 });
      },
      () =>
        completeAuthorization(
          client(SERVICE_ROLE_KEY),
          { code: 'auth-code', state: 'state-valido', error: null },
          GOOGLE_CONFIG,
        ),
    );

    assertEquals('user_id' in resultado, false);
    assertEquals(JSON.stringify(resultado).includes('user_id'), false);
  },
);
