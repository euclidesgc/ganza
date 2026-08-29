import { assertEquals } from '@std/assert';
import { envVarsFor } from './env.ts';

const fonte = {
  SUPABASE_URL: 'http://kong:8000',
  SUPABASE_ANON_KEY: 'anon-fake',
  SUPABASE_SERVICE_ROLE_KEY: 'service-role-fake',
  SUPABASE_DB_URL: 'postgres://fake',
  SUPABASE_JWT_SECRET: 'jwt-fake',
  PLUGGY_CLIENT_ID: 'pluggy-client-id-fake',
  PLUGGY_CLIENT_SECRET: 'pluggy-client-secret-fake',
  GOOGLE_OAUTH_CLIENT_ID: 'google-client-id-fake',
  GOOGLE_OAUTH_CLIENT_SECRET: 'google-client-secret-fake',
  GOOGLE_OAUTH_REDIRECT_URI: 'https://ganza.app/oauth/google/callback',
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

Deno.test('transcribe recebe SUPABASE_SERVICE_ROLE_KEY', () => {
  assertEquals(chaves('transcribe').includes('SUPABASE_SERVICE_ROLE_KEY'), true);
});

Deno.test('bank-connections não recebe SUPABASE_SERVICE_ROLE_KEY', () => {
  assertEquals(chaves('bank-connections').includes('SUPABASE_SERVICE_ROLE_KEY'), false);
});

Deno.test('bank-connections recebe PLUGGY_CLIENT_ID e PLUGGY_CLIENT_SECRET', () => {
  const chavesDaFuncao = chaves('bank-connections');
  assertEquals(chavesDaFuncao.includes('PLUGGY_CLIENT_ID'), true);
  assertEquals(chavesDaFuncao.includes('PLUGGY_CLIENT_SECRET'), true);
});

Deno.test('transactions não recebe credenciais da Pluggy', () => {
  const chavesDaFuncao = chaves('transactions');
  assertEquals(chavesDaFuncao.includes('PLUGGY_CLIENT_ID'), false);
  assertEquals(chavesDaFuncao.includes('PLUGGY_CLIENT_SECRET'), false);
});

Deno.test('calendar recebe SUPABASE_SERVICE_ROLE_KEY', () => {
  assertEquals(chaves('calendar').includes('SUPABASE_SERVICE_ROLE_KEY'), true);
});

Deno.test('calendar recebe as três variáveis do OAuth do Google', () => {
  const chavesDaFuncao = chaves('calendar');
  assertEquals(chavesDaFuncao.includes('GOOGLE_OAUTH_CLIENT_ID'), true);
  assertEquals(chavesDaFuncao.includes('GOOGLE_OAUTH_CLIENT_SECRET'), true);
  assertEquals(chavesDaFuncao.includes('GOOGLE_OAUTH_REDIRECT_URI'), true);
});

Deno.test('bank-connections não recebe as variáveis do OAuth do Google', () => {
  const chavesDaFuncao = chaves('bank-connections');
  assertEquals(chavesDaFuncao.includes('GOOGLE_OAUTH_CLIENT_ID'), false);
  assertEquals(chavesDaFuncao.includes('GOOGLE_OAUTH_CLIENT_SECRET'), false);
  assertEquals(chavesDaFuncao.includes('GOOGLE_OAUTH_REDIRECT_URI'), false);
});
