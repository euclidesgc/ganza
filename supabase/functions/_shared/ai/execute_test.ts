import { assertEquals } from '@std/assert';
import { type ResolvedProvider, transcribeAudio } from './execute.ts';

const provider: ResolvedProvider = {
  kind: 'gemini',
  baseUrl: 'https://generativelanguage.googleapis.com',
  model: 'gemini-2.0-flash',
  apiKey: 'chave-fake',
};

Deno.test('transcribeAudio monta a inline_data e devolve o texto', async () => {
  const originalFetch = globalThis.fetch;
  let capturado: unknown;

  globalThis.fetch = ((_entrada: string | URL | Request, init?: RequestInit) => {
    capturado = JSON.parse(String(init?.body));
    return Promise.resolve(
      new Response(
        JSON.stringify({
          candidates: [{ content: { parts: [{ text: 'gastei 45 no almoço' }] } }],
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      ),
    );
  }) as typeof fetch;

  try {
    const texto = await transcribeAudio(provider, 'BASE64AUDIO', 'audio/mp4');
    assertEquals(texto, 'gastei 45 no almoço');

    const body = capturado as {
      contents: { parts: { inline_data?: { mime_type: string; data: string } }[] }[];
    };
    const inline = body.contents[0].parts.find((p) => p.inline_data)?.inline_data;
    assertEquals(inline?.mime_type, 'audio/mp4');
    assertEquals(inline?.data, 'BASE64AUDIO');
  } finally {
    globalThis.fetch = originalFetch;
  }
});
