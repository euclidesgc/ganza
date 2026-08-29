import { assertEquals } from '@std/assert';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { obtainAccessToken } from './calendar_credentials.ts';
import type { GoogleOAuthConfig } from './google_oauth.ts';

const SUPABASE_URL = 'https://stub.supabase.local';
const SERVICE_ROLE_KEY = 'service-role-key-stub';
const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const GOOGLE_CONFIG: GoogleOAuthConfig = {
  clientId: 'client-id-stub',
  clientSecret: 'client-secret-stub',
};
const CONNECTION_ID = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const REFRESH_GUARDADO = 'refresh-real-guardado-no-vault-nao-pode-vazar';

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

function serviceClient(): SupabaseClient {
  return createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

Deno.test('obtainAccessToken renova o acesso e nunca inclui o refresh guardado na resposta', async () => {
  const { resultado, chamadas } = await comFetchStub(
    (chamada) => {
      if (chamada.url.includes('/rpc/google_calendar_connection_secret_reveal')) {
        return Response.json(REFRESH_GUARDADO, { status: 200 });
      }
      if (chamada.url === GOOGLE_TOKEN_URL) {
        return Response.json({ access_token: 'access-novo', expires_in: 3600 }, { status: 200 });
      }
      return new Response(null, { status: 404 });
    },
    () => obtainAccessToken(serviceClient(), CONNECTION_ID, GOOGLE_CONFIG),
  );

  if (!resultado.ok) throw new Error('esperava sucesso');
  assertEquals(resultado.accessToken, 'access-novo');
  assertEquals(JSON.stringify(resultado).includes(REFRESH_GUARDADO), false);

  const chamadaReveal = chamadas.find((c) => c.url.includes('secret_reveal'));
  if (!chamadaReveal) throw new Error('esperava chamada à RPC de revelação');
  assertEquals((chamadaReveal.corpo as Record<string, unknown>).p_connection_id, CONNECTION_ID);
  assertEquals(chamadaReveal.headers.get('apikey'), SERVICE_ROLE_KEY);
});

Deno.test(
  'obtainAccessToken devolve reconnect_required quando o Google recusa o refresh (invalid_grant)',
  async () => {
    const { resultado } = await comFetchStub(
      (chamada) => {
        if (chamada.url.includes('secret_reveal')) {
          return Response.json(REFRESH_GUARDADO, { status: 200 });
        }
        if (chamada.url === GOOGLE_TOKEN_URL) {
          return Response.json(
            { error: 'invalid_grant', error_description: 'Token has been expired or revoked.' },
            { status: 400 },
          );
        }
        return new Response(null, { status: 404 });
      },
      () => obtainAccessToken(serviceClient(), CONNECTION_ID, GOOGLE_CONFIG),
    );
    assertEquals(resultado, { ok: false, reason: 'reconnect_required' });
  },
);

Deno.test(
  'obtainAccessToken devolve connection_not_found quando a RPC não revela valor',
  async () => {
    const { resultado, chamadas } = await comFetchStub(
      (chamada) => {
        if (chamada.url.includes('secret_reveal')) {
          return Response.json(null, { status: 200 });
        }
        return new Response(null, { status: 404 });
      },
      () => obtainAccessToken(serviceClient(), CONNECTION_ID, GOOGLE_CONFIG),
    );
    assertEquals(resultado, { ok: false, reason: 'connection_not_found' });
    assertEquals(chamadas.some((c) => c.url === GOOGLE_TOKEN_URL), false);
  },
);

Deno.test(
  'obtainAccessToken devolve google_unavailable quando o Google recusa por outro motivo',
  async () => {
    const { resultado } = await comFetchStub(
      (chamada) => {
        if (chamada.url.includes('secret_reveal')) {
          return Response.json(REFRESH_GUARDADO, { status: 200 });
        }
        if (chamada.url === GOOGLE_TOKEN_URL) {
          return Response.json({ error: 'server_error' }, { status: 503 });
        }
        return new Response(null, { status: 404 });
      },
      () => obtainAccessToken(serviceClient(), CONNECTION_ID, GOOGLE_CONFIG),
    );
    assertEquals(resultado, { ok: false, reason: 'google_unavailable' });
  },
);

Deno.test('obtainAccessToken devolve google_unavailable em falha de rede', async () => {
  const original = globalThis.fetch;
  globalThis.fetch = ((entrada: string | URL | Request) => {
    const url = typeof entrada === 'string' ? entrada : entrada.toString();
    if (url.includes('secret_reveal')) {
      return Promise.resolve(Response.json(REFRESH_GUARDADO, { status: 200 }));
    }
    return Promise.reject(new Error('rede indisponível'));
  }) as typeof fetch;

  try {
    const resultado = await obtainAccessToken(serviceClient(), CONNECTION_ID, GOOGLE_CONFIG);
    assertEquals(resultado, { ok: false, reason: 'google_unavailable' });
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test(
  'identidade: obtainAccessToken só chama a RPC de revelação e o token endpoint do Google, nunca a tabela de conexões',
  async () => {
    const { chamadas } = await comFetchStub(
      (chamada) => {
        if (chamada.url.includes('secret_reveal')) {
          return Response.json(REFRESH_GUARDADO, { status: 200 });
        }
        if (chamada.url === GOOGLE_TOKEN_URL) {
          return Response.json({ access_token: 'AT', expires_in: 3600 }, { status: 200 });
        }
        return new Response(null, { status: 404 });
      },
      () => obtainAccessToken(serviceClient(), CONNECTION_ID, GOOGLE_CONFIG),
    );
    for (const chamada of chamadas) {
      assertEquals(chamada.url.includes('/rest/v1/google_calendar_connections'), false);
    }
  },
);

Deno.test('obtainAccessToken nunca escreve o refresh guardado no console em nenhum desfecho', async () => {
  const mensagens: string[] = [];
  const originais = {
    log: console.log,
    info: console.info,
    warn: console.warn,
    error: console.error,
  };
  const capturar = (...args: unknown[]) => {
    mensagens.push(args.map((arg) => JSON.stringify(arg)).join(' '));
  };
  console.log = capturar;
  console.info = capturar;
  console.warn = capturar;
  console.error = capturar;

  try {
    await comFetchStub(
      (chamada) => {
        if (chamada.url.includes('secret_reveal')) {
          return Response.json(REFRESH_GUARDADO, { status: 200 });
        }
        if (chamada.url === GOOGLE_TOKEN_URL) {
          return Response.json({ error: 'invalid_grant' }, { status: 400 });
        }
        return new Response(null, { status: 404 });
      },
      () => obtainAccessToken(serviceClient(), CONNECTION_ID, GOOGLE_CONFIG),
    );
  } finally {
    console.log = originais.log;
    console.info = originais.info;
    console.warn = originais.warn;
    console.error = originais.error;
  }

  for (const mensagem of mensagens) {
    assertEquals(mensagem.includes(REFRESH_GUARDADO), false);
  }
});
