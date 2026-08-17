import { assertEquals } from '@std/assert';
import handler from './handler.ts';

// URL e chave são só rótulos: o `fetch` é sempre stubado nos testes que
// tocam o banco, nunca sai desta máquina.
const SUPABASE_URL = 'https://stub.supabase.local';
const SUPABASE_ANON_KEY = 'anon-key-stub';

interface ChamadaFetch {
  url: string;
  metodo: string | undefined;
  headers: Headers;
  corpo: unknown;
}

/** Troca env vars pela duração de `executar`, restaurando o valor anterior mesmo em erro. */
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

/**
 * Troca o `fetch` global pela duração de `executar`, sempre restaurando o
 * original ao final — inclusive se `executar` lançar. Só os testes que
 * chegam a tocar no banco (o insert via supabase-js) precisam disto; os de
 * validação pura retornam antes de qualquer chamada de rede.
 */
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
    headers.set('Authorization', opcoes.autorizacao ?? 'Bearer token-de-teste');
  }
  const init: RequestInit = { method: opcoes.metodo ?? 'POST', headers };
  if (opcoes.corpoBruto !== undefined) {
    init.body = opcoes.corpoBruto;
  } else if (opcoes.corpo !== undefined) {
    init.body = JSON.stringify(opcoes.corpo);
  }
  return new Request('http://localhost/transactions', init);
}

const PAYLOAD_VALIDO = { direction: 'out', amount: 4500, description: 'Uber' };

// Os testes de validação (400/401/405) apagam SUPABASE_URL/SUPABASE_ANON_KEY
// de propósito: se algum deles chegasse a tocar no banco seria em si um
// defeito — a validação existe exatamente para barrar antes disso.
const SEM_SUPABASE = { SUPABASE_URL: undefined, SUPABASE_ANON_KEY: undefined };

Deno.test('201: caminho feliz cria a transação e devolve a linha do banco', async () => {
  const linhaCriada = {
    id: 'transacao-1',
    user_id: 'dono-uuid',
    direction: 'out',
    amount: 4500,
    description: 'Uber',
    source: 'manual',
    reconciliation_status: 'pending',
    occurred_at: '2026-08-15T12:00:00Z',
    created_at: '2026-08-16T00:00:00Z',
  };

  const { resultado: resposta, chamadas } = await comFetchStub(
    () => Response.json(linhaCriada, { status: 201 }),
    () =>
      comAmbiente(
        { SUPABASE_URL, SUPABASE_ANON_KEY },
        () => handler(requisicao({ autorizacao: 'Bearer jwt-do-dono', corpo: PAYLOAD_VALIDO })),
      ),
  );

  assertEquals(resposta.status, 201);
  assertEquals(await resposta.json(), linhaCriada);

  assertEquals(chamadas.length, 1);
  assertEquals(chamadas[0].metodo, 'POST');
  assertEquals(chamadas[0].url.includes('/rest/v1/transactions'), true);
  assertEquals(chamadas[0].headers.get('Authorization'), 'Bearer jwt-do-dono');
  assertEquals(chamadas[0].corpo, PAYLOAD_VALIDO);
});

Deno.test('400 invalid_json: corpo não é um JSON válido', async () => {
  const resposta = await comAmbiente(
    SEM_SUPABASE,
    () => handler(requisicao({ autorizacao: 'Bearer token', corpoBruto: '{ isso não é json' })),
  );

  assertEquals(resposta.status, 400);
  assertEquals((await resposta.json()).error.code, 'invalid_json');
});

Deno.test('400 invalid_direction: direction fora de {in,out}', async () => {
  const resposta = await comAmbiente(
    SEM_SUPABASE,
    () =>
      handler(
        requisicao({
          autorizacao: 'Bearer token',
          corpo: { ...PAYLOAD_VALIDO, direction: 'sideways' },
        }),
      ),
  );

  assertEquals(resposta.status, 400);
  assertEquals((await resposta.json()).error.code, 'invalid_direction');
});

Deno.test('400 invalid_amount: valor não-inteiro (45.5)', async () => {
  const resposta = await comAmbiente(
    SEM_SUPABASE,
    () =>
      handler(
        requisicao({ autorizacao: 'Bearer token', corpo: { ...PAYLOAD_VALIDO, amount: 45.5 } }),
      ),
  );

  assertEquals(resposta.status, 400);
  assertEquals((await resposta.json()).error.code, 'invalid_amount');
});

Deno.test('400 invalid_amount: valor <= 0', async () => {
  const resposta = await comAmbiente(
    SEM_SUPABASE,
    () =>
      handler(requisicao({ autorizacao: 'Bearer token', corpo: { ...PAYLOAD_VALIDO, amount: 0 } })),
  );

  assertEquals(resposta.status, 400);
  assertEquals((await resposta.json()).error.code, 'invalid_amount');
});

Deno.test('400 invalid_description: string vazia após trim', async () => {
  const resposta = await comAmbiente(
    SEM_SUPABASE,
    () =>
      handler(
        requisicao({
          autorizacao: 'Bearer token',
          corpo: { ...PAYLOAD_VALIDO, description: '   ' },
        }),
      ),
  );

  assertEquals(resposta.status, 400);
  assertEquals((await resposta.json()).error.code, 'invalid_description');
});

Deno.test('400 invalid_description: mais de 200 caracteres', async () => {
  const resposta = await comAmbiente(
    SEM_SUPABASE,
    () =>
      handler(
        requisicao({
          autorizacao: 'Bearer token',
          corpo: { ...PAYLOAD_VALIDO, description: 'a'.repeat(201) },
        }),
      ),
  );

  assertEquals(resposta.status, 400);
  assertEquals((await resposta.json()).error.code, 'invalid_description');
});

Deno.test('400 invalid_occurred_at: data não é ISO-8601 válida', async () => {
  const resposta = await comAmbiente(
    SEM_SUPABASE,
    () =>
      handler(
        requisicao({
          autorizacao: 'Bearer token',
          corpo: { ...PAYLOAD_VALIDO, occurred_at: 'ontem à tarde' },
        }),
      ),
  );

  assertEquals(resposta.status, 400);
  assertEquals((await resposta.json()).error.code, 'invalid_occurred_at');
});

Deno.test('401: sem Authorization, nem chega a olhar o corpo ou o banco', async () => {
  const resposta = await comAmbiente(
    SEM_SUPABASE,
    () => handler(requisicao({ autorizacao: null, corpo: PAYLOAD_VALIDO })),
  );

  assertEquals(resposta.status, 401);
  assertEquals((await resposta.json()).error.code, 'unauthorized');
});

Deno.test('405: método diferente de POST é rejeitado antes de tudo', async () => {
  const resposta = await comAmbiente(
    SEM_SUPABASE,
    () => handler(requisicao({ metodo: 'GET', autorizacao: null })),
  );

  assertEquals(resposta.status, 405);
  assertEquals((await resposta.json()).error.code, 'method_not_allowed');
});

Deno.test('payload com user_id alheio não muda o dono', async () => {
  const payloadComAtacante = { ...PAYLOAD_VALIDO, user_id: 'atacante-uuid' };
  const linhaDoDono = {
    id: 'transacao-2',
    user_id: 'dono-real-uuid',
    direction: 'out',
    amount: 4500,
    description: 'Uber',
    source: 'manual',
    reconciliation_status: 'pending',
    created_at: '2026-08-16T00:00:00Z',
  };

  const { resultado: resposta, chamadas } = await comFetchStub(
    () => Response.json(linhaDoDono, { status: 201 }),
    () =>
      comAmbiente(
        { SUPABASE_URL, SUPABASE_ANON_KEY },
        () => handler(requisicao({ autorizacao: 'Bearer jwt-do-dono', corpo: payloadComAtacante })),
      ),
  );

  assertEquals(resposta.status, 201);
  const corpoResposta = await resposta.json() as { user_id: string };
  assertEquals(corpoResposta.user_id, 'dono-real-uuid');

  // O handler nunca repassa `user_id` do payload para o insert: quem decide
  // o dono é a RLS a partir do JWT, não o corpo da requisição. Se esta
  // asserção falhar é porque o handler passou a mandar `user_id` ao banco.
  assertEquals('user_id' in (chamadas[0].corpo as Record<string, unknown>), false);
});
