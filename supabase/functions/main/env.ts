export interface EnvFonte {
  SUPABASE_URL?: string;
  SUPABASE_ANON_KEY?: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
  SUPABASE_DB_URL?: string;
  SUPABASE_JWT_SECRET?: string;
  PLUGGY_CLIENT_ID?: string;
  PLUGGY_CLIENT_SECRET?: string;
}

const FUNCOES_COM_SERVICE_ROLE = new Set(['ai-credentials', 'ingest', 'transcribe']);
const FUNCOES_COM_PLUGGY = new Set(['bank-connections']);

export function envVarsFor(nome: string, fonte: EnvFonte): [string, string][] {
  const vars: [string, string][] = [
    ['SUPABASE_URL', fonte.SUPABASE_URL ?? ''],
    ['SUPABASE_ANON_KEY', fonte.SUPABASE_ANON_KEY ?? ''],
    ['SUPABASE_DB_URL', fonte.SUPABASE_DB_URL ?? ''],
    ['SUPABASE_JWT_SECRET', fonte.SUPABASE_JWT_SECRET ?? ''],
  ];

  if (FUNCOES_COM_SERVICE_ROLE.has(nome)) {
    vars.push(['SUPABASE_SERVICE_ROLE_KEY', fonte.SUPABASE_SERVICE_ROLE_KEY ?? '']);
  }

  if (FUNCOES_COM_PLUGGY.has(nome)) {
    vars.push(['PLUGGY_CLIENT_ID', fonte.PLUGGY_CLIENT_ID ?? '']);
    vars.push(['PLUGGY_CLIENT_SECRET', fonte.PLUGGY_CLIENT_SECRET ?? '']);
  }

  return vars;
}
