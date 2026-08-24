import { assertEquals } from '@std/assert';
import handler from './handler.ts';

const SUPABASE_URL = 'https://stub.supabase.local';
const SUPABASE_ANON_KEY = 'anon-key-stub';

function requestCom(body: unknown, method = 'POST'): Request {
  return new Request('http://localhost/functions/v1/categorize', {
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
  categoria: unknown;
  hint: unknown;
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
    if (url.includes('/rest/v1/transactions') && metodo === 'PATCH') {
      return Promise.resolve(new Response(null, { status: 204 }));
    }
    if (url.includes('/rest/v1/categories') && metodo === 'GET') {
      return Promise.resolve(
        new Response(JSON.stringify(opcoes.categoria), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        }),
      );
    }
    if (url.includes('/rest/v1/category_hints') && metodo === 'GET') {
      return Promise.resolve(
        new Response(JSON.stringify(opcoes.hint), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        }),
      );
    }
    if (url.includes('/rest/v1/category_hints') && metodo === 'POST') {
      return Promise.resolve(new Response(null, { status: 201 }));
    }
    if (url.includes('/rest/v1/category_hints') && metodo === 'PATCH') {
      return Promise.resolve(new Response(null, { status: 204 }));
    }
    return Promise.resolve(new Response(null, { status: 404 }));
  }) as typeof fetch;

  return { chamadas, restaurar: () => globalThis.fetch = originalFetch };
}

const PENDENTE = {
  transacao: { description: 'Almoço no Bar do Zé' },
  categoria: { id: 'c1' },
  hint: null,
};

Deno.test('método errado devolve 405', async () => {
  const response = await handler(
    new Request('http://localhost/functions/v1/categorize', { method: 'GET' }),
  );
  assertEquals(response.status, 405);
});

Deno.test('sem Authorization devolve 401', async () => {
  const response = await handler(
    new Request('http://localhost/functions/v1/categorize', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ transaction_id: 't1', category_id: 'c1' }),
    }),
  );
  assertEquals(response.status, 401);
});

Deno.test('transaction_id ausente devolve 400', async () => {
  const response = await handler(requestCom({ category_id: 'c1' }));
  assertEquals(response.status, 400);
});

Deno.test('category_id ausente devolve 400', async () => {
  const response = await handler(requestCom({ transaction_id: 't1' }));
  assertEquals(response.status, 400);
});

Deno.test('transação alheia devolve 404', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch({ ...PENDENTE, transacao: null });
    try {
      const response = await handler(requestCom({ transaction_id: 't1', category_id: 'c1' }));
      assertEquals(response.status, 404);
      const corpo = await response.json();
      assertEquals((corpo as { error: { code: string } }).error.code, 'transacao_nao_encontrada');
    } finally {
      stub.restaurar();
    }
  });
});

Deno.test('categoria alheia devolve 400', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch({ ...PENDENTE, categoria: null });
    try {
      const response = await handler(requestCom({ transaction_id: 't1', category_id: 'c1' }));
      assertEquals(response.status, 400);
      const corpo = await response.json();
      assertEquals((corpo as { error: { code: string } }).error.code, 'categoria_invalida');
    } finally {
      stub.restaurar();
    }
  });
});

Deno.test('caminho feliz atualiza a transação e insere o hint', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch(PENDENTE);
    try {
      const response = await handler(requestCom({ transaction_id: 't1', category_id: 'c1' }));
      assertEquals(response.status, 200);
      assertEquals(
        stub.chamadas.some((c) => c.startsWith('PATCH') && c.includes('/rest/v1/transactions')),
        true,
      );
      assertEquals(
        stub.chamadas.some((c) => c.startsWith('POST') && c.includes('/rest/v1/category_hints')),
        true,
      );
    } finally {
      stub.restaurar();
    }
  });
});

Deno.test('hint existente é atualizado com hits + 1, sem insert', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch({ ...PENDENTE, hint: { hits: 3 } });
    try {
      const response = await handler(requestCom({ transaction_id: 't1', category_id: 'c1' }));
      assertEquals(response.status, 200);
      assertEquals(
        stub.chamadas.some((c) => c.startsWith('PATCH') && c.includes('/rest/v1/category_hints')),
        true,
      );
    } finally {
      stub.restaurar();
    }
  });
});
