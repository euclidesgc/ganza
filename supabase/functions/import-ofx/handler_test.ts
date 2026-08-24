import { assertEquals } from '@std/assert';
import handler from './handler.ts';

const SUPABASE_URL = 'https://stub.supabase.local';
const SUPABASE_ANON_KEY = 'anon-key-stub';

const OFX = [
  '<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20260824<TRNAMT>-45.00<FITID>abc123<MEMO>almoço',
  '<STMTTRN><TRNTYPE>CREDIT<DTPOSTED>20260825<TRNAMT>1000.00<FITID>def456<MEMO>salário',
].join('\n');

function requestCom(body: unknown, method = 'POST'): Request {
  return new Request('http://localhost/functions/v1/import-ofx', {
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
  ];
  Deno.env.set('SUPABASE_URL', SUPABASE_URL);
  Deno.env.set('SUPABASE_ANON_KEY', SUPABASE_ANON_KEY);
  try {
    return await executar();
  } finally {
    for (const [chave, valor] of anteriores) {
      if (valor === undefined) Deno.env.delete(chave);
      else Deno.env.set(chave, valor);
    }
  }
}

function stubFetch(existingIds: string[]): { inserts: string[]; restaurar: () => void } {
  const inserts: string[] = [];
  const originalFetch = globalThis.fetch;

  globalThis.fetch = ((entrada: string | URL | Request, init?: RequestInit) => {
    const url = typeof entrada === 'string' ? entrada : entrada.toString();
    const metodo = init?.method ?? 'GET';

    if (url.includes('/rest/v1/transactions') && metodo === 'GET') {
      const fitId = url.match(/external_id=eq\.([^&]+)/)?.[1] ?? '';
      const exists = existingIds.includes(fitId);
      return Promise.resolve(
        new Response(exists ? JSON.stringify({ id: 't1' }) : 'null', {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        }),
      );
    }
    if (url.includes('/rest/v1/transactions') && metodo === 'POST') {
      const body = JSON.parse(String(init?.body));
      inserts.push(body.external_id as string);
      return Promise.resolve(new Response(null, { status: 201 }));
    }
    return Promise.resolve(new Response(null, { status: 404 }));
  }) as typeof fetch;

  return { inserts, restaurar: () => globalThis.fetch = originalFetch };
}

Deno.test('método errado devolve 405', async () => {
  const response = await handler(
    new Request('http://localhost/functions/v1/import-ofx', { method: 'GET' }),
  );
  assertEquals(response.status, 405);
});

Deno.test('sem Authorization devolve 401', async () => {
  const response = await handler(
    new Request('http://localhost/functions/v1/import-ofx', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ofx: OFX }),
    }),
  );
  assertEquals(response.status, 401);
});

Deno.test('ofx vazio devolve 400', async () => {
  const response = await handler(requestCom({ ofx: '' }));
  assertEquals(response.status, 400);
});

Deno.test('ofx sem movimentos devolve 400', async () => {
  const response = await handler(requestCom({ ofx: 'sem STMTTRN' }));
  assertEquals(response.status, 400);
});

Deno.test('caminho feliz cria os movimentos bank_sync', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch([]);
    try {
      const response = await handler(requestCom({ ofx: OFX }));
      assertEquals(response.status, 200);
      const corpo = await response.json() as { created: number };
      assertEquals(corpo.created, 2);
      assertEquals(stub.inserts.length, 2);
      assertEquals(stub.inserts.includes('abc123'), true);
      assertEquals(stub.inserts.includes('def456'), true);
    } finally {
      stub.restaurar();
    }
  });
});

Deno.test('reimportar não duplica', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch(['abc123', 'def456']);
    try {
      const response = await handler(requestCom({ ofx: OFX }));
      assertEquals(response.status, 200);
      const corpo = await response.json() as { created: number };
      assertEquals(corpo.created, 0);
      assertEquals(stub.inserts.length, 0);
    } finally {
      stub.restaurar();
    }
  });
});
