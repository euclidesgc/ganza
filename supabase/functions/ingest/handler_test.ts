import { assertEquals } from '@std/assert';
import handler from './handler.ts';

const SUPABASE_URL = 'https://stub.supabase.local';
const SUPABASE_ANON_KEY = 'anon-key-stub';
const SERVICE_ROLE_KEY = 'service-role-stub';

function requestCom(body: unknown, method = 'POST'): Request {
  return new Request('http://localhost/functions/v1/ingest', {
    method,
    headers: {
      'Authorization': 'Bearer token-do-usuario',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
}

async function comAmbiente<T>(executar: () => Promise<T>): Promise<T> {
  const anteriores: [string, string | undefined][] = [
    ['SUPABASE_URL', Deno.env.get('SUPABASE_URL')],
    ['SUPABASE_ANON_KEY', Deno.env.get('SUPABASE_ANON_KEY')],
    ['SUPABASE_SERVICE_ROLE_KEY', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')],
  ];
  Deno.env.set('SUPABASE_URL', SUPABASE_URL);
  Deno.env.set('SUPABASE_ANON_KEY', SUPABASE_ANON_KEY);
  Deno.env.set('SUPABASE_SERVICE_ROLE_KEY', SERVICE_ROLE_KEY);
  try {
    return await executar();
  } finally {
    for (const [chave, valor] of anteriores) {
      if (valor === undefined) Deno.env.delete(chave);
      else Deno.env.set(chave, valor);
    }
  }
}

Deno.test('método errado devolve 405', async () => {
  const response = await handler(
    new Request('http://localhost/functions/v1/ingest', { method: 'GET' }),
  );
  assertEquals(response.status, 405);
});

Deno.test('sem Authorization devolve 401', async () => {
  const response = await handler(
    new Request('http://localhost/functions/v1/ingest', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ content: 'almoço' }),
    }),
  );
  assertEquals(response.status, 401);
});

Deno.test('content vazio devolve 400 antes de qualquer chamada à IA', async () => {
  await comAmbiente(async () => {
    const response = await handler(requestCom({ content: '   ' }));
    assertEquals(response.status, 400);
    const corpo = await response.json();
    assertEquals((corpo as { error: { code: string } }).error.code, 'content_invalido');
  });
});

Deno.test('content acima de 4000 devolve 400', async () => {
  await comAmbiente(async () => {
    const response = await handler(requestCom({ content: 'a'.repeat(4001) }));
    assertEquals(response.status, 400);
  });
});

Deno.test('caminho feliz devolve 200 com propostas e grava só em proposed_actions', async () => {
  await comAmbiente(async () => {
    const originalFetch = globalThis.fetch;
    const chamadas: string[] = [];

    globalThis.fetch = ((entrada: string | URL | Request, init?: RequestInit) => {
      const url = typeof entrada === 'string' ? entrada : entrada.toString();
      chamadas.push(url);
      const metodo = init?.method ?? 'GET';

      if (url.includes('/rest/v1/ai_routes')) {
        return Promise.resolve(
          new Response(
            JSON.stringify({ provider_id: 'p1', model: 'gemini-2.0-flash' }),
            { status: 200, headers: { 'Content-Type': 'application/json' } },
          ),
        );
      }
      if (url.includes('/rest/v1/ai_providers')) {
        return Promise.resolve(
          new Response(
            JSON.stringify({
              kind: 'gemini',
              base_url: 'https://generativelanguage.googleapis.com',
              secret_ref: 'gemini_api_key',
            }),
            { status: 200, headers: { 'Content-Type': 'application/json' } },
          ),
        );
      }
      if (url.includes('/rest/v1/vault.decrypted_secrets')) {
        return Promise.resolve(
          new Response(JSON.stringify({ decrypted_secret: 'chave-fake' }), {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
          }),
        );
      }
      if (url.includes('/rest/v1/ai_usage') && metodo === 'HEAD') {
        return Promise.resolve(new Response(null, { status: 200 }));
      }
      if (url.includes('/rest/v1/ai_usage') && metodo === 'GET') {
        return Promise.resolve(
          new Response(JSON.stringify([]), {
            status: 200,
            headers: { 'Content-Type': 'application/json', 'content-range': '0-0/0' },
          }),
        );
      }
      if (url.includes('/rest/v1/messages')) {
        return Promise.resolve(
          new Response(JSON.stringify({ id: 'm1' }), {
            status: 201,
            headers: { 'Content-Type': 'application/json' },
          }),
        );
      }
      if (url.includes('/rest/v1/proposed_actions')) {
        return Promise.resolve(
          new Response(JSON.stringify([]), {
            status: 201,
            headers: { 'Content-Type': 'application/json' },
          }),
        );
      }
      if (url.includes('generativelanguage.googleapis.com')) {
        return Promise.resolve(
          new Response(
            JSON.stringify({
              candidates: [
                {
                  content: {
                    parts: [
                      {
                        text: JSON.stringify([
                          {
                            kind: 'create_transaction',
                            payload: { direction: 'out', amount: 4500, description: 'almoço' },
                          },
                        ]),
                      },
                    ],
                  },
                },
              ],
            }),
            { status: 200, headers: { 'Content-Type': 'application/json' } },
          ),
        );
      }
      return Promise.resolve(new Response(null, { status: 404 }));
    }) as typeof fetch;

    try {
      const response = await handler(requestCom({ content: 'almoço no bar, 45 reais' }));
      assertEquals(response.status, 200);
      const corpo = await response.json();
      const propostas = (corpo as { proposals: unknown[] }).proposals;
      assertEquals(propostas.length, 1);
      assertEquals(
        chamadas.some((url) => url.includes('/rest/v1/transactions')),
        false,
      );
    } finally {
      globalThis.fetch = originalFetch;
    }
  });
});
