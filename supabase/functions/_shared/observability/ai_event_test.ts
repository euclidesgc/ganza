import { assertEquals } from '@std/assert';
import { type AiEvent, hashContent, logAiEvent } from './ai_event.ts';

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

Deno.test('o log nunca contém o conteúdo', async () => {
  const conteudo = 'Almoço no Bar do Zé R$ 45,00';
  const sha = await hashContent(conteudo);

  const linhas: string[] = [];
  const originalInfo = console.info;
  console.info = (msg?: unknown) => linhas.push(String(msg));
  try {
    logAiEvent(evento(sha));
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

Deno.test('contentSha256 é determinístico e muda com um caractere', async () => {
  const a = await hashContent('Almoço no Bar do Zé R$ 45,00');
  const b = await hashContent('Almoço no Bar do Zé R$ 45,00');
  const c = await hashContent('Almoço no Bar do Zé R$ 45,01');

  assertEquals(a, b);
  assertEquals(a !== c, true);
  assertEquals(/^[0-9a-f]{64}$/.test(a), true);
});
