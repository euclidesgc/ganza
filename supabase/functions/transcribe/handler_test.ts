import { assertEquals } from '@std/assert';
import handler, { MAX_AUDIO_BYTES } from './handler.ts';

const SUPABASE_URL = 'https://stub.supabase.local';
const SUPABASE_ANON_KEY = 'anon-key-stub';
const SERVICE_ROLE_KEY = 'service-role-stub';

function requestCom(body: unknown, method = 'POST'): Request {
  return new Request('http://localhost/functions/v1/transcribe', {
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

interface FetchCall {
  body: string | undefined;
  method: string;
  url: string;
}

function stubFetch(
  transcript = 'gastei 45 no almoço',
  aiUsageStatus = 201,
): { chamadas: FetchCall[]; restaurar: () => void } {
  const chamadas: FetchCall[] = [];
  const originalFetch = globalThis.fetch;

  globalThis.fetch = ((entrada: string | URL | Request, init?: RequestInit) => {
    const url = typeof entrada === 'string' ? entrada : entrada.toString();
    const metodo = init?.method ?? 'GET';
    chamadas.push({
      body: typeof init?.body === 'string' ? init.body : undefined,
      method: metodo,
      url,
    });

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
    if (url.includes('/rest/v1/ai_usage') && metodo === 'POST') {
      return Promise.resolve(
        aiUsageStatus === 201 ? new Response(null, { status: 201 }) : new Response(
          JSON.stringify({ code: '42501', message: 'detalhe interno' }),
          { status: aiUsageStatus, headers: { 'Content-Type': 'application/json' } },
        ),
      );
    }
    if (url.includes('/rest/v1/messages') && metodo === 'POST') {
      return Promise.resolve(
        new Response(JSON.stringify({ id: 'm1' }), {
          status: 201,
          headers: { 'Content-Type': 'application/json' },
        }),
      );
    }
    if (url.includes('/rest/v1/messages') && metodo === 'DELETE') {
      return Promise.resolve(new Response(null, { status: 204 }));
    }
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
    if (url.includes('generativelanguage.googleapis.com')) {
      return Promise.resolve(
        new Response(
          JSON.stringify({
            candidates: [{ content: { parts: [{ text: transcript }] } }],
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        ),
      );
    }
    return Promise.resolve(new Response(null, { status: 404 }));
  }) as typeof fetch;

  return { chamadas, restaurar: () => globalThis.fetch = originalFetch };
}

Deno.test('método errado devolve 405', async () => {
  const response = await handler(
    new Request('http://localhost/functions/v1/transcribe', { method: 'GET' }),
  );
  assertEquals(response.status, 405);
});

Deno.test('sem Authorization devolve 401', async () => {
  const response = await handler(
    new Request('http://localhost/functions/v1/transcribe', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ audio_base64: 'x', mime_type: 'audio/mp4' }),
    }),
  );
  assertEquals(response.status, 401);
});

Deno.test('audio vazio devolve 400', async () => {
  const response = await handler(
    requestCom({ audio_base64: '', mime_type: 'audio/mp4' }),
  );
  assertEquals(response.status, 400);
});

Deno.test('audio_base64 ausente devolve 400', async () => {
  const response = await handler(requestCom({ mime_type: 'audio/mp4' }));
  assertEquals(response.status, 400);
});

Deno.test('audio acima do teto de bytes devolve 413', async () => {
  const audioBase64 = 'A'.repeat(4 * Math.ceil((MAX_AUDIO_BYTES + 1) / 3));
  const response = await handler(requestCom({ audio_base64: audioBase64, mime_type: 'audio/mp4' }));
  assertEquals(response.status, 413);
});

Deno.test('mime_type fora do conjunto devolve 400', async () => {
  const response = await handler(
    requestCom({ audio_base64: 'QVVESU8=', mime_type: 'video/mp4' }),
  );
  assertEquals(response.status, 400);
});

Deno.test('áudio sem fala não grava mensagem, proposta ou transação', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch('   ');
    try {
      const response = await handler(
        requestCom({ audio_base64: 'QVVESU8=', mime_type: 'audio/mp4' }),
      );
      assertEquals(response.status, 422);
      assertEquals(await response.json(), {
        error: { code: 'audio_not_understood', message: 'não entendi o áudio' },
      });
      assertEquals(
        stub.chamadas.some(
          (call) => call.method === 'POST' && call.url.includes('/rest/v1/messages'),
        ),
        false,
      );
      assertEquals(
        stub.chamadas.some((call) => call.url.includes('/rest/v1/proposed_actions')),
        false,
      );
      assertEquals(
        stub.chamadas.some((call) => call.url.includes('/rest/v1/transactions')),
        false,
      );
    } finally {
      stub.restaurar();
    }
  });
});

Deno.test('caminho feliz transcreve e grava a mensagem', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch();
    try {
      const response = await handler(
        requestCom({ audio_base64: 'QVVESU8=', mime_type: 'audio/mp4' }),
      );
      assertEquals(response.status, 200);
      const corpo = await response.json() as { transcript: string; message_id: string };
      assertEquals(corpo.transcript, 'gastei 45 no almoço');
      assertEquals(corpo.message_id, 'm1');
      const mensagem = stub.chamadas.find((call) =>
        call.method === 'POST' && call.url.includes('/rest/v1/messages')
      );
      assertEquals(JSON.parse(mensagem?.body ?? '{}'), {
        role: 'user',
        content: '',
        origin: 'transcript',
        media_type: 'audio',
        transcript: 'gastei 45 no almoço',
      });
      const aiUsage = stub.chamadas.find((call) =>
        call.method === 'POST' && call.url.includes('/rest/v1/ai_usage')
      );
      const aiUsageBody = JSON.parse(aiUsage?.body ?? '{}') as {
        message_id: string;
        task_type: string;
      };
      assertEquals(aiUsageBody.task_type, 'transcribe_audio');
      assertEquals(aiUsageBody.message_id, 'm1');
      assertEquals(
        stub.chamadas.some(
          (call) => call.method === 'POST' && call.url.includes('/rest/v1/ai_usage'),
        ),
        true,
      );
      assertEquals(
        stub.chamadas.some((call) => call.url.includes('/rest/v1/proposed_actions')),
        false,
      );
      assertEquals(
        stub.chamadas.some((call) => call.url.includes('/rest/v1/transactions')),
        false,
      );
    } finally {
      stub.restaurar();
    }
  });
});

Deno.test('falha de ai_usage remove a mensagem e devolve erro seguro', async () => {
  await comAmbiente(async () => {
    const stub = stubFetch('gastei 45 no almoço', 500);
    try {
      const response = await handler(
        requestCom({ audio_base64: 'QVVESU8=', mime_type: 'audio/mp4' }),
      );
      assertEquals(response.status, 500);
      assertEquals(await response.json(), {
        error: {
          code: 'ai_usage_write_failed',
          message: 'não foi possível registrar a auditoria da IA',
        },
      });
      assertEquals(
        stub.chamadas.some(
          (call) => call.method === 'DELETE' && call.url.includes('/rest/v1/messages?id=eq.m1'),
        ),
        true,
      );
      assertEquals(
        stub.chamadas.some((call) => call.url.includes('/rest/v1/proposed_actions')),
        false,
      );
      assertEquals(
        stub.chamadas.some((call) => call.url.includes('/rest/v1/transactions')),
        false,
      );
    } finally {
      stub.restaurar();
    }
  });
});
