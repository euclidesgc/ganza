import { assertEquals } from 'jsr:@std/assert';

// O contrato que o Coolify e o app dependem: 200 só quando o banco responde,
// 503 caso contrário. Sem SUPABASE_DB_URL o endpoint não pode fingir saúde.
Deno.test('sem SUPABASE_DB_URL o health degrada em vez de mentir 200', async () => {
  const anterior = Deno.env.get('SUPABASE_DB_URL');
  Deno.env.delete('SUPABASE_DB_URL');

  const { default: handler } = await import('./handler.ts');
  const resposta = await handler();

  assertEquals(resposta.status, 503);
  assertEquals((await resposta.json()).status, 'degraded');

  if (anterior) Deno.env.set('SUPABASE_DB_URL', anterior);
});
