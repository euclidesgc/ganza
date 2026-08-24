import { assertEquals } from '@std/assert';
import handler from './handler.ts';

const SUPABASE_URL = 'https://stub.supabase.local';
const SUPABASE_ANON_KEY = 'anon-key-stub';

function requestCom(body: unknown, method = 'POST'): Request {
  return new Request('http://localhost/functions/v1/proposals', {
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

// deno-lint-ignore no-explicit-any
function stubFetch(proposta: any): { chamadas: string[]; restaurar: () => void } {
  const chamadas: string[] = [];
  const originalFetch = globalThis.fetch;

  globalThis.fetch = ((entrada: string | URL | Request, init?: RequestInit) => {
    const url = typeof entrada === 'string' ? entrada : entrada.toString();
    chamadas.push(url);
    const metodo = init?.method ?? 'GET';

    if (url.includes('/rest/v1/proposed_actions') && metodo === 'GET') {
      return Promise.resolve(
        new Response(JSON.stringify(proposta), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        }),
      );
    }
    if (url.includes('/rest/v1/proposed_actions') && metodo === 'PATCH') {
      return Promise.resolve(new Response(null, { status: 204 }));
    }
    if (url.includes('/rest/v1/transactions') && metodo === 'POST') {
      return Promise.resolve(
        new Response(JSON.stringify({ id: 't1' }), {
          status: 201,
          headers: { 'Content-Type': 'application/json' },
        }),
      );
    }
    return Promise.resolve(new Response(null, { status: 404 }));
  }) as typeof fetch;

  return { chamadas, restaurar: () => globalThis.fetch = originalFetch };
}

const PROPOSTA_PENDENTE = {
  id: 'p1',
  status: 'pending',
  kind: 'create_transaction',
  payload: { direction: 'out', amount: 4500, description: 'almoço' },
};

Deno.test('método errado devolve 405', async () => {
  const response = await handler(
    new Request('http://localhost/functions/v1/proposals', { method: 'GET' }),
  );
  assertEquals(response.status, 405);
});

Deno.test('sem Authorization devolve 401', async () => {
  const response = await handler(
    new Request('http://localhost/functions/v1/proposals', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ proposal_id: 'p1', action: 'confirm' }),
    }),
  );
  assertEquals(response.status, 401);
});

Deno.test('JSON inválido devolve 400', async () => {
  const response = await handler(
    new Request('http://localhost/functions/v1/proposals', {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer token',
        'Content-Type': 'application/json',
      },
      body: 'não é json',
    }),
  );
  assertEquals(response.status, 400);
});

Deno.test('action fora de confirm/cancel devolve 400', async () => {
  const response = await handler(requestCom({ proposal_id: 'p1', action: 'apagar' }));
  assertEquals(response.status, 400);
  const corpo = await response.json();
  assertEquals((corpo as { error: { code: string } }).error.code, 'invalid_action');
});

Deno.test('proposal_id ausente devolve 400', async () => {
  const response = await handler(requestCom({ action: 'confirm' }));
  assertEquals(response.status, 400);
  const corpo = await response.json();
  assertEquals((corpo as { error: { code: string } }).error.code, 'invalid_proposal_id');
});

Deno.test('proposta inexistente devolve 404', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch(null);
    try {
      const response = await handler(requestCom({ proposal_id: 'p1', action: 'confirm' }));
      assertEquals(response.status, 404);
      const corpo = await response.json();
      assertEquals(
        (corpo as { error: { code: string } }).error.code,
        'proposta_nao_encontrada',
      );
    } finally {
      stub.restaurar();
    }
  });
});

Deno.test('proposta já não pendente devolve 409', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch({ ...PROPOSTA_PENDENTE, status: 'confirmed' });
    try {
      const response = await handler(requestCom({ proposal_id: 'p1', action: 'confirm' }));
      assertEquals(response.status, 409);
      const corpo = await response.json();
      assertEquals(
        (corpo as { error: { code: string } }).error.code,
        'proposta_nao_pendente',
      );
    } finally {
      stub.restaurar();
    }
  });
});

Deno.test('confirmar insere em transactions e devolve 200 confirmed', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch(PROPOSTA_PENDENTE);
    try {
      const response = await handler(requestCom({ proposal_id: 'p1', action: 'confirm' }));
      assertEquals(response.status, 200);
      const corpo = await response.json();
      assertEquals((corpo as { status: string }).status, 'confirmed');
      assertEquals(
        stub.chamadas.some((url) => url.includes('/rest/v1/transactions')),
        true,
      );
    } finally {
      stub.restaurar();
    }
  });
});

Deno.test('cancelar não insere em transactions e devolve 200 cancelled', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch(PROPOSTA_PENDENTE);
    try {
      const response = await handler(requestCom({ proposal_id: 'p1', action: 'cancel' }));
      assertEquals(response.status, 200);
      const corpo = await response.json();
      assertEquals((corpo as { status: string }).status, 'cancelled');
      assertEquals(
        stub.chamadas.some((url) => url.includes('/rest/v1/transactions')),
        false,
      );
    } finally {
      stub.restaurar();
    }
  });
});

Deno.test('confirmar payload inválido devolve 400 payload_invalido', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch({
      id: 'p1',
      status: 'pending',
      kind: 'create_transaction',
      payload: { direction: 'out', amount: 0, description: 'x' },
    });
    try {
      const response = await handler(requestCom({ proposal_id: 'p1', action: 'confirm' }));
      assertEquals(response.status, 400);
      const corpo = await response.json();
      assertEquals((corpo as { error: { code: string } }).error.code, 'payload_invalido');
    } finally {
      stub.restaurar();
    }
  });
});
