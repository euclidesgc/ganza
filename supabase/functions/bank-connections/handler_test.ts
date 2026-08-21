import { assertEquals } from '@std/assert';
import handler from './handler.ts';

// URL e credenciais são só rótulos: o `fetch` é sempre stubado nos testes que
// tocam a Pluggy ou o banco, nunca sai desta máquina.
const SUPABASE_URL = 'https://stub.supabase.local';
const SUPABASE_ANON_KEY = 'anon-key-stub';
const PLUGGY_CLIENT_ID = 'client-id-de-teste';
const PLUGGY_CLIENT_SECRET = 'client-secret-de-teste';

const AMBIENTE_COMPLETO = {
  SUPABASE_URL,
  SUPABASE_ANON_KEY,
  PLUGGY_CLIENT_ID,
  PLUGGY_CLIENT_SECRET,
};

const SEM_AMBIENTE = {
  SUPABASE_URL: undefined,
  SUPABASE_ANON_KEY: undefined,
  PLUGGY_CLIENT_ID: undefined,
  PLUGGY_CLIENT_SECRET: undefined,
};

const JWT_DO_DONO = 'Bearer jwt-do-dono';
const CONNECTION_ID = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const ITEM_ID = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const PLUGGY_API_HOST = 'api.pluggy.ai';

interface ChamadaFetch {
  url: string;
  metodo: string | undefined;
  headers: Headers;
  corpo: unknown;
}

async function comAmbiente<T>(
  mudancas: Record<string, string | undefined>,
  executar: () => Promise<T>,
): Promise<T> {
  const anteriores = new Map<string, string | undefined>();
  for (const [chave, valor] of Object.entries(mudancas)) {
    anteriores.set(chave, Deno.env.get(chave));
    if (valor === undefined) Deno.env.delete(chave);
    else Deno.env.set(chave, valor);
  }
  try {
    return await executar();
  } finally {
    for (const [chave, valor] of anteriores) {
      if (valor === undefined) Deno.env.delete(chave);
      else Deno.env.set(chave, valor);
    }
  }
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
      corpo: init?.body ? JSON.parse(init.body as string) : undefined,
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

function requisicao(opcoes: {
  metodo?: string;
  autorizacao?: string | null;
  corpo?: unknown;
  corpoBruto?: string;
} = {}): Request {
  const headers = new Headers({ 'Content-Type': 'application/json' });
  if (opcoes.autorizacao !== null) {
    headers.set('Authorization', opcoes.autorizacao ?? JWT_DO_DONO);
  }
  const init: RequestInit = { method: opcoes.metodo ?? 'POST', headers };
  if (opcoes.corpoBruto !== undefined) {
    init.body = opcoes.corpoBruto;
  } else if (opcoes.corpo !== undefined) {
    init.body = JSON.stringify(opcoes.corpo);
  }
  return new Request('http://localhost/bank-connections', init);
}

function respostaPluggyAuth(): Response {
  return Response.json({ apiKey: 'pluggy-api-key-de-teste' }, { status: 200 });
}

function respostaPluggyItem(status = 'UPDATED'): Response {
  return Response.json({ status, connector: { name: 'Banco de Teste' } }, { status: 200 });
}

Deno.test('401: sem Authorization, nem chega a olhar o corpo ou a Pluggy', async () => {
  const resposta = await comAmbiente(
    SEM_AMBIENTE,
    () => handler(requisicao({ autorizacao: null, corpo: { action: 'connect_token' } })),
  );

  assertEquals(resposta.status, 401);
  assertEquals((await resposta.json()).error.code, 'unauthorized');
});

Deno.test('405: método diferente de POST é rejeitado antes de tudo', async () => {
  const resposta = await comAmbiente(
    SEM_AMBIENTE,
    () => handler(requisicao({ metodo: 'GET', autorizacao: null })),
  );

  assertEquals(resposta.status, 405);
  assertEquals((await resposta.json()).error.code, 'method_not_allowed');
});

Deno.test('400 invalid_json: corpo não é um JSON válido', async () => {
  const resposta = await comAmbiente(
    SEM_AMBIENTE,
    () => handler(requisicao({ corpoBruto: '{ isso não é json' })),
  );

  assertEquals(resposta.status, 400);
  assertEquals((await resposta.json()).error.code, 'invalid_json');
});

Deno.test('400 invalid_action: action fora do conjunto conhecido', async () => {
  const resposta = await comAmbiente(
    SEM_AMBIENTE,
    () => handler(requisicao({ corpo: { action: 'sync_now' } })),
  );

  assertEquals(resposta.status, 400);
  assertEquals((await resposta.json()).error.code, 'invalid_action');
});

Deno.test('400 invalid_connection_id: disconnect sem connection_id não chega a tocar Pluggy nem banco', async () => {
  const { resultado: resposta, chamadas } = await comFetchStub(
    () => Response.json('não deveria ser chamado', { status: 200 }),
    () =>
      comAmbiente(
        AMBIENTE_COMPLETO,
        () => handler(requisicao({ corpo: { action: 'disconnect' } })),
      ),
  );

  assertEquals(resposta.status, 400);
  assertEquals((await resposta.json()).error.code, 'invalid_connection_id');
  assertEquals(chamadas.length, 0);
});

Deno.test('400 invalid_item_id: persist_item sem item_id não chega a tocar Pluggy nem banco', async () => {
  const { resultado: resposta, chamadas } = await comFetchStub(
    () => Response.json('não deveria ser chamado', { status: 200 }),
    () =>
      comAmbiente(
        AMBIENTE_COMPLETO,
        () => handler(requisicao({ corpo: { action: 'persist_item' } })),
      ),
  );

  assertEquals(resposta.status, 400);
  assertEquals((await resposta.json()).error.code, 'invalid_item_id');
  assertEquals(chamadas.length, 0);
});

Deno.test('503 missing_configuration: sem PLUGGY_CLIENT_ID/SECRET a função não chama nada', async () => {
  const { resultado: resposta, chamadas } = await comFetchStub(
    () => Response.json('não deveria ser chamado', { status: 200 }),
    () =>
      comAmbiente(
        {
          SUPABASE_URL,
          SUPABASE_ANON_KEY,
          PLUGGY_CLIENT_ID: undefined,
          PLUGGY_CLIENT_SECRET: undefined,
        },
        () => handler(requisicao({ corpo: { action: 'connect_token' } })),
      ),
  );

  assertEquals(resposta.status, 503);
  assertEquals((await resposta.json()).error.code, 'missing_configuration');
  assertEquals(chamadas.length, 0);
});

Deno.test('404: desconectar um identificador de conexão de outro usuário', async () => {
  const { resultado: resposta, chamadas } = await comFetchStub(
    (chamada) => {
      if (chamada.url.includes('/rest/v1/bank_connections')) {
        return Response.json([], { status: 200 });
      }
      return Response.json('não deveria ser chamado', { status: 200 });
    },
    () =>
      comAmbiente(
        AMBIENTE_COMPLETO,
        () =>
          handler(
            requisicao({ corpo: { action: 'disconnect', connection_id: CONNECTION_ID } }),
          ),
      ),
  );

  assertEquals(resposta.status, 404);
  assertEquals((await resposta.json()).error.code, 'not_found');

  for (const chamada of chamadas) {
    assertEquals(chamada.url.includes(PLUGGY_API_HOST), false);
  }
});

Deno.test('502 pluggy_unavailable: a Pluggy fora do ar nunca vira 200 com corpo vazio', async () => {
  const resposta = await comFetchStub(
    (chamada) => {
      if (chamada.url.includes('/auth')) {
        return Response.json({ error: 'indisponível' }, { status: 500 });
      }
      return Response.json('não deveria ser chamado', { status: 200 });
    },
    () =>
      comAmbiente(
        AMBIENTE_COMPLETO,
        () => handler(requisicao({ corpo: { action: 'connect_token' } })),
      ),
  ).then(({ resultado }) => resultado);

  assertEquals(resposta.status, 502);
  const corpo = await resposta.json();
  assertEquals(corpo.error.code, 'pluggy_unavailable');
  assertEquals(typeof corpo.error.message, 'string');
  assertEquals(corpo.error.message.length > 0, true);
});

Deno.test('200: connect_token emite o token de conexão da Pluggy', async () => {
  const { resultado: resposta, chamadas } = await comFetchStub(
    (chamada) => {
      if (chamada.url.includes('/auth')) return respostaPluggyAuth();
      if (chamada.url.includes('/connect_token')) {
        return Response.json({ accessToken: 'connect-token-fake-de-teste' }, { status: 200 });
      }
      return Response.json('não deveria ser chamado', { status: 200 });
    },
    () =>
      comAmbiente(
        AMBIENTE_COMPLETO,
        () => handler(requisicao({ corpo: { action: 'connect_token' } })),
      ),
  );

  assertEquals(resposta.status, 200);
  assertEquals(await resposta.json(), { access_token: 'connect-token-fake-de-teste' });
  assertEquals(chamadas.some((chamada) => chamada.headers.get('X-API-KEY') !== null), true);
});

Deno.test('201: persist_item busca o item na Pluggy e grava a conexão do dono', async () => {
  const linhaCriada = {
    id: CONNECTION_ID,
    user_id: 'dono-uuid',
    item_id: ITEM_ID,
    institution_name: 'Banco de Teste',
    status: 'connected',
    last_synced_at: '2026-08-21T00:00:00Z',
    created_at: '2026-08-21T00:00:00Z',
    updated_at: '2026-08-21T00:00:00Z',
  };

  const { resultado: resposta, chamadas } = await comFetchStub(
    (chamada) => {
      if (chamada.url.includes('/auth')) return respostaPluggyAuth();
      if (chamada.url.includes(`/items/${ITEM_ID}`)) return respostaPluggyItem('UPDATED');
      if (chamada.url.includes('/rest/v1/bank_connections')) {
        return Response.json(linhaCriada, { status: 201 });
      }
      return Response.json('não deveria ser chamado', { status: 200 });
    },
    () =>
      comAmbiente(
        AMBIENTE_COMPLETO,
        () =>
          handler(
            requisicao({ corpo: { action: 'persist_item', item_id: ITEM_ID } }),
          ),
      ),
  );

  assertEquals(resposta.status, 201);
  assertEquals(await resposta.json(), linhaCriada);

  const chamadaInsert = chamadas.find((chamada) =>
    chamada.url.includes('/rest/v1/bank_connections')
  );
  assertEquals(chamadaInsert?.headers.get('Authorization'), JWT_DO_DONO);
  assertEquals(
    (chamadaInsert?.corpo as Record<string, unknown> | undefined)?.status,
    'connected',
  );
});

Deno.test('200: status relê o item na Pluggy e atualiza a conexão do dono', async () => {
  const linhaAtualizada = {
    id: CONNECTION_ID,
    user_id: 'dono-uuid',
    item_id: ITEM_ID,
    institution_name: 'Banco de Teste',
    status: 'error',
    last_synced_at: '2026-08-21T00:00:00Z',
  };

  const { resultado: resposta } = await comFetchStub(
    (chamada) => {
      if (chamada.url.includes('/auth')) return respostaPluggyAuth();
      if (chamada.url.includes(`/items/${ITEM_ID}`)) return respostaPluggyItem('LOGIN_ERROR');
      if (chamada.url.includes('/rest/v1/bank_connections')) {
        if (chamada.metodo === 'GET') {
          return Response.json([{ id: CONNECTION_ID, item_id: ITEM_ID }], { status: 200 });
        }
        return Response.json(linhaAtualizada, { status: 200 });
      }
      return Response.json('não deveria ser chamado', { status: 200 });
    },
    () =>
      comAmbiente(
        AMBIENTE_COMPLETO,
        () =>
          handler(
            requisicao({ corpo: { action: 'status', connection_id: CONNECTION_ID } }),
          ),
      ),
  );

  assertEquals(resposta.status, 200);
  assertEquals(await resposta.json(), linhaAtualizada);
});

Deno.test('200: disconnect apaga o item na Pluggy e marca a conexão como desconectada', async () => {
  const linhaDesconectada = {
    id: CONNECTION_ID,
    user_id: 'dono-uuid',
    item_id: ITEM_ID,
    institution_name: 'Banco de Teste',
    status: 'disconnected',
  };

  const { resultado: resposta, chamadas } = await comFetchStub(
    (chamada) => {
      if (chamada.url.includes('/auth')) return respostaPluggyAuth();
      if (chamada.url.includes(`/items/${ITEM_ID}`) && chamada.metodo === 'DELETE') {
        return new Response(null, { status: 204 });
      }
      if (chamada.url.includes('/rest/v1/bank_connections')) {
        if (chamada.metodo === 'GET') {
          return Response.json([{ id: CONNECTION_ID, item_id: ITEM_ID }], { status: 200 });
        }
        return Response.json(linhaDesconectada, { status: 200 });
      }
      return Response.json('não deveria ser chamado', { status: 200 });
    },
    () =>
      comAmbiente(
        AMBIENTE_COMPLETO,
        () =>
          handler(
            requisicao({ corpo: { action: 'disconnect', connection_id: CONNECTION_ID } }),
          ),
      ),
  );

  assertEquals(resposta.status, 200);
  assertEquals(await resposta.json(), linhaDesconectada);

  const chamadaDelete = chamadas.find((chamada) => chamada.metodo === 'DELETE');
  assertEquals(chamadaDelete !== undefined, true);
});
