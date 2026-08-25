import { assertEquals, assertRejects } from '@std/assert';
import { type AiEvent, AiUsageWriteError, hashContent, logAiEvent } from './ai_event.ts';

function evento(sha: string): AiEvent {
  return {
    taskType: 'extract_record',
    providerName: 'gemini',
    model: 'gemini-2.0-flash',
    status: 'success',
    costMicros: 100,
    latencyMs: 42,
    contentSha256: sha,
  };
}

function stubSupabase() {
  const linhas: Record<string, unknown>[] = [];
  return {
    linhas,
    client: {
      from: () => ({
        insert: (linha: Record<string, unknown>) => {
          linhas.push(linha);
          return Promise.resolve({ error: null });
        },
      }),
    },
  };
}

Deno.test('o log nunca contém o conteúdo', async () => {
  const conteudo = 'Almoço no Bar do Zé R$ 45,00';
  const sha = await hashContent(conteudo);
  const { client } = stubSupabase();

  const linhas: string[] = [];
  const originalInfo = console.info;
  console.info = (msg?: unknown) => linhas.push(String(msg));
  try {
    await logAiEvent(client, evento(sha));
  } finally {
    console.info = originalInfo;
  }

  for (const linha of linhas) {
    assertEquals(linha.includes('Bar do Zé'), false, 'vazou estabelecimento');
    assertEquals(linha.includes('Almoço'), false, 'vazou descrição');
    assertEquals(linha.includes('45,00'), false, 'vazou valor');
    assertEquals(linha.includes('4500'), false, 'vazou centavos');
  }
});

Deno.test('logAiEvent grava a linha de ai_usage em snake_case', async () => {
  const sha = await hashContent('x');
  const { linhas, client } = stubSupabase();

  await logAiEvent(client, evento(sha));

  assertEquals(linhas.length, 1);
  assertEquals(linhas[0].task_type, 'extract_record');
  assertEquals(linhas[0].provider_name, 'gemini');
  assertEquals(linhas[0].model, 'gemini-2.0-flash');
  assertEquals(linhas[0].status, 'success');
  assertEquals(linhas[0].cost_micros, 100);
  assertEquals(linhas[0].latency_ms, 42);
  assertEquals(linhas[0].content_sha256, sha);
});

Deno.test('logAiEvent propaga falha de ai_usage com código seguro', async () => {
  const sha = await hashContent('x');
  const client = {
    from: () => ({
      insert: () => Promise.resolve({ error: { code: '42501', message: 'detalhe interno' } }),
    }),
  };

  await assertRejects(
    () => logAiEvent(client, evento(sha)),
    AiUsageWriteError,
    'ai_usage_write_failed',
  );
});

Deno.test('contentSha256 é determinístico e muda com um caractere', async () => {
  const a = await hashContent('Almoço no Bar do Zé R$ 45,00');
  const b = await hashContent('Almoço no Bar do Zé R$ 45,00');
  const c = await hashContent('Almoço no Bar do Zé R$ 45,01');

  assertEquals(a, b);
  assertEquals(a !== c, true);
  assertEquals(/^[0-9a-f]{64}$/.test(a), true);
});
