import { assertEquals } from '@std/assert';
import handler from './handler.ts';

const SUPABASE_URL = 'https://stub.supabase.local';
const SUPABASE_ANON_KEY = 'anon-key-stub';

function requestCom(body: unknown, method = 'POST'): Request {
  return new Request('http://localhost/functions/v1/routine-occurrences', {
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
  ocorrencia: unknown;
  rotina: unknown;
}

function stubFetch(opcoes: Opcoes): { chamadas: string[]; restaurar: () => void } {
  const chamadas: string[] = [];
  const originalFetch = globalThis.fetch;

  globalThis.fetch = ((entrada: string | URL | Request, init?: RequestInit) => {
    const url = typeof entrada === 'string' ? entrada : entrada.toString();
    const metodo = init?.method ?? 'GET';
    chamadas.push(`${metodo} ${url}`);

    if (url.includes('/rest/v1/routine_occurrences') && metodo === 'GET') {
      return Promise.resolve(
        new Response(JSON.stringify(opcoes.ocorrencia), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        }),
      );
    }
    if (url.includes('/rest/v1/routines') && metodo === 'GET') {
      return Promise.resolve(
        new Response(JSON.stringify(opcoes.rotina), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        }),
      );
    }
    if (url.includes('/rest/v1/routine_occurrences') && metodo === 'PATCH') {
      return Promise.resolve(new Response(null, { status: 204 }));
    }
    if (url.includes('/rest/v1/routine_occurrences') && metodo === 'POST') {
      return Promise.resolve(new Response(null, { status: 201 }));
    }
    if (url.includes('/rest/v1/occurrence_events') && metodo === 'POST') {
      return Promise.resolve(new Response(null, { status: 201 }));
    }
    return Promise.resolve(new Response(null, { status: 404 }));
  }) as typeof fetch;

  return { chamadas, restaurar: () => globalThis.fetch = originalFetch };
}

const PENDENTE = {
  ocorrencia: {
    id: 'o1',
    routine_id: 'r1',
    sequence: 1,
    due_date: '2026-08-24',
    status: 'pending',
  },
  rotina: {
    recurrence_mode: 'interval_from_completion',
    recurrence_rule: null,
    interval_days: 15,
  },
};

Deno.test('método errado devolve 405', async () => {
  const response = await handler(
    new Request('http://localhost/functions/v1/routine-occurrences', { method: 'GET' }),
  );
  assertEquals(response.status, 405);
});

Deno.test('sem Authorization devolve 401', async () => {
  const response = await handler(
    new Request('http://localhost/functions/v1/routine-occurrences', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ occurrence_id: 'o1', action: 'done' }),
    }),
  );
  assertEquals(response.status, 401);
});

Deno.test('action inválida devolve 400', async () => {
  const response = await handler(requestCom({ occurrence_id: 'o1', action: 'apagar' }));
  assertEquals(response.status, 400);
});

Deno.test('postpone sem due_date devolve 400', async () => {
  const response = await handler(requestCom({ occurrence_id: 'o1', action: 'postpone' }));
  assertEquals(response.status, 400);
});

Deno.test('ocorrência alheia devolve 404', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch({ ...PENDENTE, ocorrencia: null });
    try {
      const response = await handler(requestCom({ occurrence_id: 'o1', action: 'done' }));
      assertEquals(response.status, 404);
    } finally {
      stub.restaurar();
    }
  });
});

Deno.test('ocorrência já resolvida devolve 409', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch({
      ...PENDENTE,
      ocorrencia: { ...PENDENTE.ocorrencia, status: 'done' },
    });
    try {
      const response = await handler(requestCom({ occurrence_id: 'o1', action: 'done' }));
      assertEquals(response.status, 409);
    } finally {
      stub.restaurar();
    }
  });
});

Deno.test('done gera a próxima ocorrência e loga', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch(PENDENTE);
    try {
      const response = await handler(requestCom({ occurrence_id: 'o1', action: 'done' }));
      assertEquals(response.status, 200);
      assertEquals(
        stub.chamadas.some((c) =>
          c.startsWith('PATCH') && c.includes('/rest/v1/routine_occurrences')
        ),
        true,
      );
      assertEquals(
        stub.chamadas.some((c) =>
          c.startsWith('POST') && c.includes('/rest/v1/routine_occurrences')
        ),
        true,
      );
      assertEquals(
        stub.chamadas.some((c) => c.startsWith('POST') && c.includes('/rest/v1/occurrence_events')),
        true,
      );
    } finally {
      stub.restaurar();
    }
  });
});

Deno.test('postpone move sem inserir ocorrência nova', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch(PENDENTE);
    try {
      const response = await handler(
        requestCom({ occurrence_id: 'o1', action: 'postpone', due_date: '2026-08-26' }),
      );
      assertEquals(response.status, 200);
      assertEquals(
        stub.chamadas.some((c) =>
          c.startsWith('PATCH') && c.includes('/rest/v1/routine_occurrences')
        ),
        true,
      );
      assertEquals(
        stub.chamadas.some((c) =>
          c.startsWith('POST') && c.includes('/rest/v1/routine_occurrences')
        ),
        false,
      );
      assertEquals(
        stub.chamadas.some((c) => c.startsWith('POST') && c.includes('/rest/v1/occurrence_events')),
        true,
      );
    } finally {
      stub.restaurar();
    }
  });
});

Deno.test('skip marca e loga sem inserir', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch(PENDENTE);
    try {
      const response = await handler(requestCom({ occurrence_id: 'o1', action: 'skip' }));
      assertEquals(response.status, 200);
      assertEquals(
        stub.chamadas.some((c) =>
          c.startsWith('POST') && c.includes('/rest/v1/routine_occurrences')
        ),
        false,
      );
      assertEquals(
        stub.chamadas.some((c) => c.startsWith('POST') && c.includes('/rest/v1/occurrence_events')),
        true,
      );
    } finally {
      stub.restaurar();
    }
  });
});

Deno.test('cancel marca e loga sem inserir', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch(PENDENTE);
    try {
      const response = await handler(requestCom({ occurrence_id: 'o1', action: 'cancel' }));
      assertEquals(response.status, 200);
      assertEquals(
        stub.chamadas.some((c) =>
          c.startsWith('POST') && c.includes('/rest/v1/routine_occurrences')
        ),
        false,
      );
      assertEquals(
        stub.chamadas.some((c) => c.startsWith('POST') && c.includes('/rest/v1/occurrence_events')),
        true,
      );
    } finally {
      stub.restaurar();
    }
  });
});
