// Serviço principal do edge-runtime: recebe tudo em /functions/v1/<nome> e
// despacha para a pasta correspondente. É o padrão do Supabase self-hosted —
// sem ele, cada função precisaria de um worker próprio.
import { STATUS_CODE } from '@std/http/status';
import { envVarsFor } from './env.ts';

const JWT_SECRET = Deno.env.get('SUPABASE_JWT_SECRET') ?? Deno.env.get('JWT_SECRET');
const VERIFY_JWT = Deno.env.get('VERIFY_JWT') === 'true';

// Funções que respondem sem sessão. Tudo que toca dado do usuário fica fora
// desta lista: a autorização real é a RLS, mas deixar a porta aberta faria o
// endpoint aceitar chamada anônima antes mesmo de chegar no banco.
//
// `calendar` entra aqui só por causa do callback OAuth do Google
// (GET /calendar/callback): a navegação volta do consentimento sem sessão do
// app, então o roteador não tem como exigir Authorization sem quebrar esse
// fluxo. Toda outra rota de `calendar` (authorize, connection, events,
// proposals) continua exigindo o header e é `calendar/handler.ts` — não este
// roteador — quem recusa sem ele; o callback, por sua vez, só aceita o state
// consumido pelas RPCs da migration 0017 como prova de identidade.
const PUBLICAS = new Set(['health', 'calendar']);

function erro(code: string, message: string, status: number): Response {
  return new Response(JSON.stringify({ error: { code, message } }), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const nome = url.pathname.replace(/^\/+/, '').split('/')[0];

  if (!nome) {
    return erro('missing_function', 'função não informada', STATUS_CODE.BadRequest);
  }

  if (VERIFY_JWT && !PUBLICAS.has(nome) && !req.headers.get('Authorization')) {
    return erro('unauthorized', 'sessão ausente', STATUS_CODE.Unauthorized);
  }

  const caminho = `/home/deno/functions/${nome}`;

  try {
    // @ts-expect-error — EdgeRuntime é global do runtime, sem tipos publicados.
    const worker = await EdgeRuntime.userWorkers.create({
      servicePath: caminho,
      memoryLimitMb: 150,
      workerTimeoutMs: 60_000,
      noModuleCache: false,
      envVars: envVarsFor(nome, {
        SUPABASE_URL: Deno.env.get('SUPABASE_URL'),
        SUPABASE_ANON_KEY: Deno.env.get('SUPABASE_ANON_KEY'),
        SUPABASE_SERVICE_ROLE_KEY: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),
        SUPABASE_DB_URL: Deno.env.get('SUPABASE_DB_URL'),
        SUPABASE_JWT_SECRET: JWT_SECRET,
        PLUGGY_CLIENT_ID: Deno.env.get('PLUGGY_CLIENT_ID'),
        PLUGGY_CLIENT_SECRET: Deno.env.get('PLUGGY_CLIENT_SECRET'),
        GOOGLE_OAUTH_CLIENT_ID: Deno.env.get('GOOGLE_OAUTH_CLIENT_ID'),
        GOOGLE_OAUTH_CLIENT_SECRET: Deno.env.get('GOOGLE_OAUTH_CLIENT_SECRET'),
        GOOGLE_OAUTH_REDIRECT_URI: Deno.env.get('GOOGLE_OAUTH_REDIRECT_URI'),
      }),
    });

    return await worker.fetch(req);
  } catch {
    return erro('function_not_found', `função "${nome}" não encontrada`, STATUS_CODE.NotFound);
  }
});
