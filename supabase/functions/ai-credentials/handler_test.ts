import { assertEquals } from '@std/assert';
import handler from './handler.ts';

const SUPABASE_URL = 'https://stub.supabase.local';
const SUPABASE_ANON_KEY = 'anon-key-stub';
const SUPABASE_SERVICE_ROLE_KEY = 'service-role-key-stub';

const AMBIENTE_COMPLETO = { SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY };

const JWT_DO_REQUISITANTE = 'Bearer jwt-do-requisitante';
const DEAD_UUID = '00000000-0000-4000-8000-00000000dead';
const SECRET_REF_REAL = '11111111-1111-4111-8111-111111111111';
const PROVIDER_KIND_ID = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const CREDENTIAL_ID = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

const SAVE_VALIDO = {
  action: 'save',
  provider_kind_id: PROVIDER_KIND_ID,
  model: 'gemini-2.0-flash',
  api_key: 'placeholder-de-teste-t44-Z9K2',
};

const TEST_VALIDO = { action: 'test', credential_id: CREDENTIAL_ID };

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

async function comConsoleStub<T>(
  executar: () => Promise<T>,
): Promise<{ resultado: T; mensagens: string[] }> {
  const originais = {
    log: console.log,
    info: console.info,
    warn: console.warn,
    error: console.error,
  };
  const mensagens: string[] = [];
  const capturar = (...args: unknown[]) => {
    mensagens.push(args.map((arg) => JSON.stringify(arg)).join(' '));
  };
  console.log = capturar;
  console.info = capturar;
  console.warn = capturar;
  console.error = capturar;

  try {
    const resultado = await executar();
    return { resultado, mensagens };
  } finally {
    console.log = originais.log;
    console.info = originais.info;
    console.warn = originais.warn;
    console.error = originais.error;
  }
}

function requisicao(opcoes: {
  autorizacao?: string | null;
  corpo?: unknown;
} = {}): Request {
  const headers = new Headers({ 'Content-Type': 'application/json' });
  if (opcoes.autorizacao !== null) {
    headers.set('Authorization', opcoes.autorizacao ?? JWT_DO_REQUISITANTE);
  }
  const init: RequestInit = { method: 'POST', headers };
  if (opcoes.corpo !== undefined) {
    init.body = JSON.stringify(opcoes.corpo);
  }
  return new Request('http://localhost/ai-credentials', init);
}

function headersContem(headers: Headers, agulha: string): boolean {
  return [...headers].join('|').includes(agulha);
}

function chamadaContem(chamada: ChamadaFetch, agulha: string): boolean {
  return (
    chamada.url + JSON.stringify(chamada.corpo ?? null) + [...chamada.headers].join('|')
  ).includes(agulha);
}

Deno.test('save: user_id do corpo é ignorado, o dono vem do JWT via GoTrue', async () => {
  const { resultado, chamadas } = await comFetchStub(
    (chamada) => {
      if (chamada.url.includes('/auth/v1/user')) {
        return Response.json({ id: 'dono-real-uuid' }, { status: 200 });
      }
      return Response.json('credencial-uuid-1', { status: 200 });
    },
    () =>
      comAmbiente(
        AMBIENTE_COMPLETO,
        () =>
          handler(
            requisicao({
              autorizacao: JWT_DO_REQUISITANTE,
              corpo: { ...SAVE_VALIDO, user_id: DEAD_UUID },
            }),
          ),
      ),
  );

  assertEquals(resultado.status < 300, true);
  assertEquals(chamadas.length >= 1, true);
  assertEquals(chamadas[0].headers.get('Authorization'), JWT_DO_REQUISITANTE);
  for (const chamada of chamadas) {
    assertEquals(chamadaContem(chamada, DEAD_UUID), false);
  }
});

Deno.test('save: model numérico é rejeitado antes de qualquer chamada de rede', async () => {
  const { resultado, chamadas } = await comFetchStub(
    () => Response.json('não deveria ser chamado', { status: 200 }),
    () =>
      comAmbiente(
        AMBIENTE_COMPLETO,
        () => handler(requisicao({ corpo: { ...SAVE_VALIDO, model: 12345 } })),
      ),
  );

  assertEquals(resultado.status, 400);
  assertEquals((await resultado.json()).error.code, 'invalid_model');
  assertEquals(chamadas.length, 0);
});

Deno.test('test: secret_ref e user_id do corpo são ignorados; a decifra só usa o que o passo 1 devolveu', async () => {
  const { resultado, chamadas } = await comFetchStub(
    (chamada) => {
      if (chamada.url.includes('/rest/v1/ai_user_credentials')) {
        return Response.json([{ secret_ref: SECRET_REF_REAL }], { status: 200 });
      }
      return Response.json('chave-decifrada-mock', { status: 200 });
    },
    () =>
      comAmbiente(
        AMBIENTE_COMPLETO,
        () =>
          handler(
            requisicao({
              autorizacao: JWT_DO_REQUISITANTE,
              corpo: { ...TEST_VALIDO, user_id: DEAD_UUID, secret_ref: DEAD_UUID },
            }),
          ),
      ),
  );

  assertEquals(resultado.status, 200);

  const indicesComServiceRole = chamadas
    .map((chamada, indice) => ({ chamada, indice }))
    .filter(({ chamada }) => headersContem(chamada.headers, SUPABASE_SERVICE_ROLE_KEY))
    .map(({ indice }) => indice);

  assertEquals(indicesComServiceRole.length >= 1, true);
  const menorIndice = Math.min(...indicesComServiceRole);
  assertEquals(menorIndice > 0, true);

  for (let indice = 0; indice < menorIndice; indice++) {
    assertEquals(chamadas[indice].headers.get('Authorization'), JWT_DO_REQUISITANTE);
    assertEquals(headersContem(chamadas[indice].headers, SUPABASE_SERVICE_ROLE_KEY), false);
  }

  for (const indice of indicesComServiceRole) {
    assertEquals(chamadaContem(chamadas[indice], SECRET_REF_REAL), true);
    assertEquals(chamadaContem(chamadas[indice], DEAD_UUID), false);
  }
});

Deno.test('test: credencial de outro usuário devolve 404 e nunca chega na service_role', async () => {
  const { resultado, chamadas } = await comFetchStub(
    (chamada) => {
      if (chamada.url.includes('/rest/v1/ai_user_credentials')) {
        return Response.json([], { status: 200 });
      }
      return Response.json('não deveria ser chamado', { status: 200 });
    },
    () =>
      comAmbiente(
        AMBIENTE_COMPLETO,
        () => handler(requisicao({ autorizacao: JWT_DO_REQUISITANTE, corpo: TEST_VALIDO })),
      ),
  );

  assertEquals(resultado.status, 404);
  for (const chamada of chamadas) {
    assertEquals(headersContem(chamada.headers, SUPABASE_SERVICE_ROLE_KEY), false);
  }
});

Deno.test('401: sem Authorization não chega a olhar corpo nem banco', async () => {
  const resultado = await comAmbiente(
    AMBIENTE_COMPLETO,
    () => handler(requisicao({ autorizacao: null, corpo: TEST_VALIDO })),
  );

  assertEquals(resultado.status, 401);
  assertEquals((await resultado.json()).error.code, 'unauthorized');
});

Deno.test('save: nem a chave em claro nem a resposta vazam — resposta traz só modelo, last4 e provedor', async () => {
  const { resultado: resultadoConsole, mensagens } = await comConsoleStub(() =>
    comFetchStub(
      (chamada) => {
        if (chamada.url.includes('/auth/v1/user')) {
          return Response.json({ id: 'dono-real-uuid' }, { status: 200 });
        }
        return Response.json('credencial-uuid-1', { status: 200 });
      },
      () =>
        comAmbiente(
          AMBIENTE_COMPLETO,
          () =>
            handler(
              requisicao({ autorizacao: JWT_DO_REQUISITANTE, corpo: SAVE_VALIDO }),
            ),
        ),
    )
  );

  const { resultado: resposta } = resultadoConsole;
  const textoResposta = await resposta.text();

  assertEquals(textoResposta.includes('placeholder-de-teste-t44-Z9K2'), false);
  assertEquals(textoResposta.includes('gemini-2.0-flash'), true);
  assertEquals(textoResposta.includes('Z9K2'), true);
  assertEquals(textoResposta.includes(PROVIDER_KIND_ID), true);

  for (const mensagem of mensagens) {
    assertEquals(mensagem.includes('placeholder-de-teste-t44-Z9K2'), false);
  }
});

Deno.test('test: nem o secret_ref real vaza na resposta nem no log', async () => {
  const { resultado: resultadoConsole, mensagens } = await comConsoleStub(() =>
    comFetchStub(
      (chamada) => {
        if (chamada.url.includes('/rest/v1/ai_user_credentials')) {
          return Response.json([{ secret_ref: SECRET_REF_REAL }], { status: 200 });
        }
        return Response.json('chave-decifrada-mock', { status: 200 });
      },
      () =>
        comAmbiente(
          AMBIENTE_COMPLETO,
          () =>
            handler(
              requisicao({ autorizacao: JWT_DO_REQUISITANTE, corpo: TEST_VALIDO }),
            ),
        ),
    )
  );

  const { resultado: resposta } = resultadoConsole;
  const textoResposta = await resposta.text();

  assertEquals(textoResposta.includes(SECRET_REF_REAL), false);
  for (const mensagem of mensagens) {
    assertEquals(mensagem.includes(SECRET_REF_REAL), false);
  }
});

Deno.test('delete: some do dono passa pela RLS e apaga sem tocar a service_role', async () => {
  const { resultado, chamadas } = await comFetchStub(
    (chamada) => {
      if (
        chamada.url.includes('/rest/v1/ai_user_credentials') && chamada.metodo === 'DELETE'
      ) {
        return Response.json([{ id: CREDENTIAL_ID }], { status: 200 });
      }
      return Response.json('não deveria ser chamado', { status: 200 });
    },
    () =>
      comAmbiente(
        AMBIENTE_COMPLETO,
        () =>
          handler(
            requisicao({
              autorizacao: JWT_DO_REQUISITANTE,
              corpo: { action: 'delete', credential_id: CREDENTIAL_ID },
            }),
          ),
      ),
  );

  assertEquals(resultado.status, 200);
  for (const chamada of chamadas) {
    assertEquals(headersContem(chamada.headers, SUPABASE_SERVICE_ROLE_KEY), false);
  }
});
