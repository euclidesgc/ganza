import { assertEquals } from '@std/assert';
import { envVarsFor } from './env.ts';

const fonte = {
  SUPABASE_URL: 'http://kong:8000',
  SUPABASE_ANON_KEY: 'anon-fake',
  SUPABASE_SERVICE_ROLE_KEY: 'service-role-fake',
  SUPABASE_DB_URL: 'postgres://fake',
  SUPABASE_JWT_SECRET: 'jwt-fake',
};

function chaves(nome: string): string[] {
  return envVarsFor(nome, fonte).map(([chave]) => chave);
}

Deno.test('transactions não recebe SUPABASE_SERVICE_ROLE_KEY', () => {
  assertEquals(chaves('transactions').includes('SUPABASE_SERVICE_ROLE_KEY'), false);
});

Deno.test('health não recebe SUPABASE_SERVICE_ROLE_KEY', () => {
  assertEquals(chaves('health').includes('SUPABASE_SERVICE_ROLE_KEY'), false);
});

Deno.test('ai-credentials recebe SUPABASE_SERVICE_ROLE_KEY', () => {
  assertEquals(chaves('ai-credentials').includes('SUPABASE_SERVICE_ROLE_KEY'), true);
});
