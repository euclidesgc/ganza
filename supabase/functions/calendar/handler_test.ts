import { assertEquals } from '@std/assert';
import handler from './handler.ts';

const SUPABASE_URL = 'https://stub.supabase.local';
const SUPABASE_ANON_KEY = 'anon-key-stub';
const SUPABASE_SERVICE_ROLE_KEY = 'service-role-key-stub';
const GOOGLE_OAUTH_CLIENT_ID = 'google-client-id-stub';
const GOOGLE_OAUTH_CLIENT_SECRET = 'google-client-secret-stub';
const GOOGLE_OAUTH_REDIRECT_URI = 'https://ganza.app/oauth/google/callback';
const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';

const AMBIENTE_COMPLETO = {
  SUPABASE_URL,
  SUPABASE_ANON_KEY,
  SUPABASE_SERVICE_ROLE_KEY,
  GOOGLE_OAUTH_CLIENT_ID,
  GOOGLE_OAUTH_CLIENT_SECRET,
  GOOGLE_OAUTH_REDIRECT_URI,
};

const JWT_DO_USUARIO = 'Bearer jwt-do-usuario';
const CONNECTION_ID = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const REFRESH_GUARDADO = 'refresh-guardado-no-vault';
const VERIFICADOR_PKCE_DE_TESTE = 'verificador-pkce-de-teste-stub';

interface ChamadaFetch {
  url: string;
  metodo: string;
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
  responder: (chamada: ChamadaFetch, indice: number) => Response,
  executar: () => Promise<T>,
): Promise<{ resultado: T; chamadas: ChamadaFetch[] }> {
  const original = globalThis.fetch;
  const chamadas: ChamadaFetch[] = [];
  globalThis.fetch = ((entrada: string | URL | Request, init?: RequestInit) => {
    const chamada: ChamadaFetch = {
      url: typeof entrada === 'string' ? entrada : entrada.toString(),
      metodo: init?.method ?? 'GET',
      headers: new Headers(init?.headers ?? {}),
      corpo: init?.body
        ? (typeof init.body === 'string' && init.body.trim().startsWith('{')
          ? JSON.parse(init.body)
          : init.body)
        : undefined,
    };
    const indice = chamadas.length;
    chamadas.push(chamada);
    return Promise.resolve(responder(chamada, indice));
  }) as typeof fetch;

  try {
    const resultado = await executar();
    return { resultado, chamadas };
  } finally {
    globalThis.fetch = original;
  }
}

function requisicao(
  path: string,
  opcoes: { metodo?: string; autorizacao?: string | null; corpo?: unknown } = {},
): Request {
  const headers = new Headers({ 'Content-Type': 'application/json' });
  if (opcoes.autorizacao !== null) {
    headers.set('Authorization', opcoes.autorizacao ?? JWT_DO_USUARIO);
  }
  const init: RequestInit = { method: opcoes.metodo ?? 'GET', headers };
  if (opcoes.corpo !== undefined) {
    init.body = JSON.stringify(opcoes.corpo);
  }
  return new Request(`http://localhost${path}`, init);
}

function base64Url(value: string): string {
  return btoa(value).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function fakeIdToken(sub: string): string {
  const header = base64Url(JSON.stringify({ alg: 'none', typ: 'JWT' }));
  const payload = base64Url(JSON.stringify({ sub }));
  return `${header}.${payload}.assinatura-stub`;
}

function janelaValida(): { min: string; max: string } {
  const agora = Date.now();
  const dia = 24 * 60 * 60 * 1000;
  return {
    min: new Date(agora - 5 * dia).toISOString(),
    max: new Date(agora + 30 * dia).toISOString(),
  };
}

function ehEscritaEmConexoes(chamada: ChamadaFetch): boolean {
  return chamada.url.includes('/rest/v1/google_calendar_connections') &&
    chamada.metodo !== 'GET';
}

Deno.test(
  'authorize, connection, events e proposals recusam requisição sem Authorization; nenhuma chamada de rede é feita',
  async () => {
    const rotas: [string, string][] = [
      ['POST', '/calendar/authorize'],
      ['GET', '/calendar/connection'],
      ['GET', `/calendar/events?time_min=${janelaValida().min}&time_max=${janelaValida().max}`],
      ['POST', '/calendar/proposals'],
    ];

    for (const [metodo, path] of rotas) {
      const { resultado, chamadas } = await comFetchStub(
        () => new Response(null, { status: 404 }),
        () =>
          comAmbiente(
            AMBIENTE_COMPLETO,
            () => handler(requisicao(path, { metodo, autorizacao: null })),
          ),
      );
      assertEquals(resultado.status, 401, `${metodo} ${path} deveria recusar sem Authorization`);
      assertEquals((await resultado.json()).error.code, 'unauthorized');
      assertEquals(
        chamadas.length,
        0,
        `${metodo} ${path} não deveria chamar rede sem Authorization`,
      );
    }
  },
);

Deno.test('authorize: com JWT chama startAuthorization e devolve authorization_url', async () => {
  const { resultado, chamadas } = await comFetchStub(
    (chamada) => {
      if (chamada.url.includes('/rpc/google_oauth_authorization_start')) {
        return Response.json('11111111-1111-4111-8111-111111111111', { status: 200 });
      }
      return new Response(null, { status: 404 });
    },
    () =>
      comAmbiente(
        AMBIENTE_COMPLETO,
        () => handler(requisicao('/calendar/authorize', { metodo: 'POST' })),
      ),
  );

  assertEquals(resultado.status, 200);
  const corpo = await resultado.json();
  assertEquals(typeof corpo.authorization_url, 'string');
  assertEquals(corpo.authorization_url.includes('access_type=offline'), true);
  assertEquals(chamadas[0].headers.get('Authorization'), JWT_DO_USUARIO);
});

Deno.test('callback: funciona sem Authorization, a única rota pública do roteador de Calendar', async () => {
  const idToken = fakeIdToken('google-sub-1');
  const { resultado, chamadas } = await comFetchStub(
    (chamada) => {
      if (chamada.url.includes('prepare_callback')) {
        return Response.json([{
          secret_value: VERIFICADOR_PKCE_DE_TESTE,
          redirect_uri: GOOGLE_OAUTH_REDIRECT_URI,
        }], {
          status: 200,
        });
      }
      if (chamada.url === GOOGLE_TOKEN_URL) {
        return Response.json(
          { access_token: 'AT', refresh_token: 'RT', id_token: idToken, expires_in: 3600 },
          { status: 200 },
        );
      }
      if (chamada.url.includes('complete_callback')) {
        return Response.json(CONNECTION_ID, { status: 200 });
      }
      return new Response(null, { status: 404 });
    },
    () =>
      comAmbiente(
        AMBIENTE_COMPLETO,
        () =>
          handler(
            requisicao('/calendar/callback?code=auth-code&state=state-valido', {
              autorizacao: null,
            }),
          ),
      ),
  );

  assertEquals(resultado.status, 200);
  assertEquals(resultado.headers.get('Content-Type')?.includes('text/html'), true);
  assertEquals(chamadas.some((c) => c.url.includes('complete_callback')), true);
});

Deno.test(
  'callback: state inexistente ou vencido não cria vínculo, devolve erro e não chama complete_callback',
  async () => {
    const { resultado, chamadas } = await comFetchStub(
      (chamada) => {
        if (chamada.url.includes('prepare_callback')) {
          return Response.json([], { status: 200 });
        }
        return new Response(null, { status: 404 });
      },
      () =>
        comAmbiente(
          AMBIENTE_COMPLETO,
          () =>
            handler(
              requisicao('/calendar/callback?code=auth-code&state=state-inexistente', {
                autorizacao: null,
              }),
            ),
        ),
    );

    assertEquals(resultado.status, 400);
    assertEquals(
      chamadas.some((c) =>
        c.url.includes('complete_callback') || c.url.includes('discard_callback')
      ),
      false,
    );
  },
);

Deno.test('connection: sem vínculo devolve disconnected', async () => {
  const { resultado } = await comFetchStub(
    (chamada) => {
      if (chamada.url.includes('/rest/v1/google_calendar_connections')) {
        return Response.json([], { status: 200 });
      }
      return new Response(null, { status: 404 });
    },
    () => comAmbiente(AMBIENTE_COMPLETO, () => handler(requisicao('/calendar/connection'))),
  );

  assertEquals(resultado.status, 200);
  assertEquals(await resultado.json(), { status: 'disconnected' });
});

Deno.test('connection: renovação bem-sucedida devolve connected sem escrever na tabela', async () => {
  const { resultado, chamadas } = await comFetchStub(
    (chamada) => {
      if (chamada.url.includes('/rest/v1/google_calendar_connections')) {
        return Response.json([{ id: CONNECTION_ID, primary_calendar_id: 'primary' }], {
          status: 200,
        });
      }
      if (chamada.url.includes('secret_reveal')) {
        return Response.json(REFRESH_GUARDADO, { status: 200 });
      }
      if (chamada.url === GOOGLE_TOKEN_URL) {
        return Response.json({ access_token: 'AT-novo', expires_in: 3600 }, { status: 200 });
      }
      return new Response(null, { status: 404 });
    },
    () => comAmbiente(AMBIENTE_COMPLETO, () => handler(requisicao('/calendar/connection'))),
  );

  assertEquals(resultado.status, 200);
  assertEquals(await resultado.json(), { status: 'connected', primary_calendar_id: 'primary' });
  assertEquals(chamadas.some(ehEscritaEmConexoes), false);
});

// FD-008: a renovação recusada pelo Google (refresh revogado) é o caso que
// prova que `reconnect_required` é derivado a cada leitura, não persistido —
// a migration 0017 não tem RPC que escreva esse status.
Deno.test(
  'connection: renovação recusada pelo Google (invalid_grant) devolve reconnect_required sem escrever em google_calendar_connections',
  async () => {
    const { resultado, chamadas } = await comFetchStub(
      (chamada) => {
        if (chamada.url.includes('/rest/v1/google_calendar_connections')) {
          return Response.json([{ id: CONNECTION_ID, primary_calendar_id: 'primary' }], {
            status: 200,
          });
        }
        if (chamada.url.includes('secret_reveal')) {
          return Response.json(REFRESH_GUARDADO, { status: 200 });
        }
        if (chamada.url === GOOGLE_TOKEN_URL) {
          return Response.json({ error: 'invalid_grant' }, { status: 400 });
        }
        return new Response(null, { status: 404 });
      },
      () => comAmbiente(AMBIENTE_COMPLETO, () => handler(requisicao('/calendar/connection'))),
    );

    assertEquals(resultado.status, 200);
    assertEquals(await resultado.json(), { status: 'reconnect_required' });
    assertEquals(
      chamadas.filter(ehEscritaEmConexoes).length,
      0,
      'nenhuma chamada deveria escrever em google_calendar_connections',
    );
  },
);

Deno.test('events: janela fora do horizonte devolve invalid_payload', async () => {
  const { resultado, chamadas } = await comFetchStub(
    () => new Response(null, { status: 404 }),
    () =>
      comAmbiente(
        AMBIENTE_COMPLETO,
        () =>
          handler(
            requisicao(
              '/calendar/events?time_min=2000-01-01T00:00:00Z&time_max=2000-02-01T00:00:00Z',
            ),
          ),
      ),
  );

  assertEquals(resultado.status, 400);
  assertEquals((await resultado.json()).error.code, 'invalid_payload');
  assertEquals(chamadas.length, 0);
});

Deno.test('events: sem vínculo devolve connection_required', async () => {
  const { resultado } = await comFetchStub(
    (chamada) => {
      if (chamada.url.includes('/rest/v1/google_calendar_connections')) {
        return Response.json([], { status: 200 });
      }
      return new Response(null, { status: 404 });
    },
    () =>
      comAmbiente(
        AMBIENTE_COMPLETO,
        () =>
          handler(
            requisicao(
              `/calendar/events?time_min=${janelaValida().min}&time_max=${janelaValida().max}`,
            ),
          ),
      ),
  );

  assertEquals(resultado.status, 409);
  assertEquals((await resultado.json()).error.code, 'connection_required');
});

Deno.test('events: lista eventos normalizados de todos os calendários acessíveis', async () => {
  const { resultado } = await comFetchStub(
    (chamada) => {
      if (chamada.url.includes('/rest/v1/google_calendar_connections')) {
        return Response.json([{ id: CONNECTION_ID, primary_calendar_id: 'primary' }], {
          status: 200,
        });
      }
      if (chamada.url.includes('secret_reveal')) {
        return Response.json(REFRESH_GUARDADO, { status: 200 });
      }
      if (chamada.url === GOOGLE_TOKEN_URL) {
        return Response.json({ access_token: 'AT', expires_in: 3600 }, { status: 200 });
      }
      if (chamada.url.includes('/users/me/calendarList')) {
        return Response.json({ items: [{ id: 'primary', summary: 'Principal' }] }, {
          status: 200,
        });
      }
      if (chamada.url.includes('/calendars/primary/events')) {
        return Response.json(
          {
            items: [
              {
                id: 'ev-1',
                summary: 'Dentista',
                start: { dateTime: '2026-08-28T14:00:00-03:00' },
                end: { dateTime: '2026-08-28T15:00:00-03:00' },
              },
            ],
          },
          { status: 200 },
        );
      }
      return new Response(null, { status: 404 });
    },
    () =>
      comAmbiente(
        AMBIENTE_COMPLETO,
        () =>
          handler(
            requisicao(
              `/calendar/events?time_min=${janelaValida().min}&time_max=${janelaValida().max}`,
            ),
          ),
      ),
  );

  assertEquals(resultado.status, 200);
  const corpo = await resultado.json();
  assertEquals(corpo.events.length, 1);
  assertEquals(corpo.events[0].calendar_id, 'primary');
  assertEquals(corpo.events[0].event_id, 'ev-1');
});

Deno.test('proposals: cancelar não faz nenhuma chamada ao Google', async () => {
  const { resultado, chamadas } = await comFetchStub(
    (chamada) => {
      if (chamada.url.includes('/rest/v1/proposed_actions') && chamada.metodo === 'GET') {
        return Response.json([{ id: 'prop-1', status: 'pending', kind: 'create_calendar_event' }], {
          status: 200,
        });
      }
      if (chamada.url.includes('/rest/v1/proposed_actions') && chamada.metodo === 'PATCH') {
        return new Response(null, { status: 204 });
      }
      return new Response(null, { status: 404 });
    },
    () =>
      comAmbiente(
        AMBIENTE_COMPLETO,
        () =>
          handler(
            requisicao('/calendar/proposals', {
              metodo: 'POST',
              corpo: { proposal_id: 'prop-1', action: 'cancel' },
            }),
          ),
      ),
  );

  assertEquals(resultado.status, 200);
  assertEquals(await resultado.json(), { status: 'cancelled', proposal_id: 'prop-1' });
  assertEquals(chamadas.some((c) => c.url.includes('googleapis.com')), false);
});

Deno.test('proposals: confirmar sem vínculo devolve connection_required', async () => {
  const { resultado } = await comFetchStub(
    (chamada) => {
      if (chamada.url.includes('/rest/v1/google_calendar_connections')) {
        return Response.json([], { status: 200 });
      }
      return new Response(null, { status: 404 });
    },
    () =>
      comAmbiente(
        AMBIENTE_COMPLETO,
        () =>
          handler(
            requisicao('/calendar/proposals', {
              metodo: 'POST',
              corpo: { proposal_id: 'prop-1', action: 'confirm' },
            }),
          ),
      ),
  );

  assertEquals(resultado.status, 409);
  assertEquals((await resultado.json()).error.code, 'connection_required');
});

Deno.test('proposals: confirmar cria o evento no Google e marca a proposta como confirmed', async () => {
  const proposalRow = {
    id: 'prop-1',
    status: 'pending',
    kind: 'create_calendar_event',
    payload: {
      title: 'Dentista',
      calendar_id: 'primary',
      time_zone: 'America/Sao_Paulo',
      start: '2026-08-28T14:00:00-03:00',
      end: '2026-08-28T15:00:00-03:00',
      all_day: false,
    },
  };

  const { resultado, chamadas } = await comFetchStub(
    (chamada) => {
      if (chamada.url.includes('/rest/v1/google_calendar_connections')) {
        return Response.json([{ id: CONNECTION_ID, primary_calendar_id: 'primary' }], {
          status: 200,
        });
      }
      if (chamada.url.includes('secret_reveal')) {
        return Response.json(REFRESH_GUARDADO, { status: 200 });
      }
      if (chamada.url === GOOGLE_TOKEN_URL) {
        return Response.json({ access_token: 'AT', expires_in: 3600 }, { status: 200 });
      }
      if (chamada.url.includes('/rest/v1/proposed_actions') && chamada.metodo === 'GET') {
        return Response.json([proposalRow], { status: 200 });
      }
      if (chamada.url.includes('privateExtendedProperty')) {
        return Response.json({ items: [] }, { status: 200 });
      }
      if (chamada.url.includes('/calendars/primary/events') && chamada.metodo === 'POST') {
        return Response.json({ id: 'ev-criado', start: {}, end: {} }, { status: 200 });
      }
      if (chamada.url.includes('/rest/v1/proposed_actions') && chamada.metodo === 'PATCH') {
        return new Response(null, { status: 204 });
      }
      return new Response(null, { status: 404 });
    },
    () =>
      comAmbiente(
        AMBIENTE_COMPLETO,
        () =>
          handler(
            requisicao('/calendar/proposals', {
              metodo: 'POST',
              corpo: { proposal_id: 'prop-1', action: 'confirm' },
            }),
          ),
      ),
  );

  assertEquals(resultado.status, 200);
  assertEquals(await resultado.json(), { status: 'confirmed', proposal_id: 'prop-1' });
  assertEquals(
    chamadas.some((c) => c.url.includes('/calendars/primary/events') && c.metodo === 'POST'),
    true,
  );
});

Deno.test('rota desconhecida devolve 404', async () => {
  const { resultado } = await comFetchStub(
    () => new Response(null, { status: 404 }),
    () => comAmbiente(AMBIENTE_COMPLETO, () => handler(requisicao('/calendar/rota-inexistente'))),
  );
  assertEquals(resultado.status, 404);
});
