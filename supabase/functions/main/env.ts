export interface EnvFonte {
  SUPABASE_URL?: string;
  SUPABASE_ANON_KEY?: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
  SUPABASE_DB_URL?: string;
  SUPABASE_JWT_SECRET?: string;
}

const FUNCOES_COM_SERVICE_ROLE = new Set(['ai-credentials']);

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

  return vars;
}
