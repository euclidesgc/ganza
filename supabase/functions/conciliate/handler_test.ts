import { assertEquals } from '@std/assert';
import handler from './handler.ts';

const SUPABASE_URL = 'https://stub.supabase.local';
const SUPABASE_ANON_KEY = 'anon-key-stub';

function requestCom(body: unknown, method = 'POST'): Request {
  return new Request('http://localhost/functions/v1/conciliate', {
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

interface Opcoes {
  transacao: unknown;
  ocorrencias: unknown[];
}

function stubFetch(opcoes: Opcoes): { chamadas: string[]; restaurar: () => void } {
  const chamadas: string[] = [];
  const originalFetch = globalThis.fetch;

  globalThis.fetch = ((entrada: string | URL | Request, init?: RequestInit) => {
    const url = typeof entrada === 'string' ? entrada : entrada.toString();
    const metodo = init?.method ?? 'GET';
    chamadas.push(`${metodo} ${url}`);

    if (url.includes('/rest/v1/transactions') && metodo === 'GET') {
      return Promise.resolve(
        new Response(JSON.stringify(opcoes.transacao), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        }),
      );
    }
    if (url.includes('/rest/v1/commitment_occurrences') && metodo === 'GET') {
      return Promise.resolve(
        new Response(JSON.stringify(opcoes.ocorrencias), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        }),
      );
    }
    if (url.includes('/rest/v1/commitment_occurrences') && metodo === 'PATCH') {
      return Promise.resolve(new Response(null, { status: 204 }));
    }
    if (url.includes('/rest/v1/transactions') && metodo === 'PATCH') {
      return Promise.resolve(new Response(null, { status: 204 }));
    }
    return Promise.resolve(new Response(null, { status: 404 }));
  }) as typeof fetch;

  return { chamadas, restaurar: () => globalThis.fetch = originalFetch };
}

const PENDENTE = {
  transacao: {
    id: 't1',
    amount: 4500,
    occurred_at: '2026-08-24T12:00:00Z',
    source: 'bank_sync',
    reconciliation_status: 'pending',
  },
  ocorrencias: [
    { id: 'o1', expected_amount: 4500, due_date: '2026-08-26' },
  ],
};

Deno.test('método errado devolve 405', async () => {
  const response = await handler(
    new Request('http://localhost/functions/v1/conciliate', { method: 'GET' }),
  );
  assertEquals(response.status, 405);
});

Deno.test('sem Authorization devolve 401', async () => {
  const response = await handler(
    new Request('http://localhost/functions/v1/conciliate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ transaction_id: 't1' }),
    }),
  );
  assertEquals(response.status, 401);
});

Deno.test('transação alheia devolve 404', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch({ ...PENDENTE, transacao: null });
    try {
      const response = await handler(requestCom({ transaction_id: 't1' }));
      assertEquals(response.status, 404);
    } finally {
      stub.restaurar();
    }
  });
});

Deno.test('transação não bancária devolve 409', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch({
      ...PENDENTE,
      transacao: { ...PENDENTE.transacao, source: 'manual' },
    });
    try {
      const response = await handler(requestCom({ transaction_id: 't1' }));
      assertEquals(response.status, 409);
    } finally {
      stub.restaurar();
    }
  });
});

Deno.test('caminho feliz casa a transação com a ocorrência', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch(PENDENTE);
    try {
      const response = await handler(requestCom({ transaction_id: 't1' }));
      assertEquals(response.status, 200);
      const corpo = await response.json() as { matched: boolean; occurrence_id?: string };
      assertEquals(corpo.matched, true);
      assertEquals(corpo.occurrence_id, 'o1');
      assertEquals(
        stub.chamadas.some((c) =>
          c.startsWith('PATCH') && c.includes('/rest/v1/commitment_occurrences')
        ),
        true,
      );
      assertEquals(
        stub.chamadas.some((c) => c.startsWith('PATCH') && c.includes('/rest/v1/transactions')),
        true,
      );
    } finally {
      stub.restaurar();
    }
  });
});

Deno.test('sem match devolve matched false e não grava', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch({ ...PENDENTE, ocorrencias: [] });
    try {
      const response = await handler(requestCom({ transaction_id: 't1' }));
      assertEquals(response.status, 200);
      const corpo = await response.json() as { matched: boolean };
      assertEquals(corpo.matched, false);
      assertEquals(
        stub.chamadas.some((c) => c.startsWith('PATCH')),
        false,
      );
    } finally {
      stub.restaurar();
    }
  });
});
