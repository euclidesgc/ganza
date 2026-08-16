// Serviço principal do edge-runtime: recebe tudo em /functions/v1/<nome> e
// despacha para a pasta correspondente. É o padrão do Supabase self-hosted —
// sem ele, cada função precisaria de um worker próprio.
import { STATUS_CODE } from 'jsr:@std/http/status';

const JWT_SECRET = Deno.env.get('SUPABASE_JWT_SECRET') ?? Deno.env.get('JWT_SECRET');
const VERIFY_JWT = Deno.env.get('VERIFY_JWT') === 'true';

// Funções que respondem sem sessão. Tudo que toca dado do usuário fica fora
// desta lista: a autorização real é a RLS, mas deixar a porta aberta faria o
// endpoint aceitar chamada anônima antes mesmo de chegar no banco.
const PUBLICAS = new Set(['health']);

function semAutorizacao(mensagem: string): Response {
  return new Response(JSON.stringify({ error: mensagem }), {
    status: STATUS_CODE.Unauthorized,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const nome = url.pathname.replace(/^\/+/, '').split('/')[0];

  if (!nome) {
    return new Response(JSON.stringify({ error: 'função não informada' }), {
      status: STATUS_CODE.BadRequest,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  if (VERIFY_JWT && !PUBLICAS.has(nome) && !req.headers.get('Authorization')) {
    return semAutorizacao('sessão ausente');
  }

  const caminho = `/home/deno/functions/${nome}`;

  try {
    // @ts-expect-error — EdgeRuntime é global do runtime, sem tipos publicados.
    const worker = await EdgeRuntime.userWorkers.create({
      servicePath: caminho,
      memoryLimitMb: 150,
      workerTimeoutMs: 60_000,
      noModuleCache: false,
      envVars: [
        ['SUPABASE_URL', Deno.env.get('SUPABASE_URL') ?? ''],
        ['SUPABASE_ANON_KEY', Deno.env.get('SUPABASE_ANON_KEY') ?? ''],
        ['SUPABASE_SERVICE_ROLE_KEY', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''],
        ['SUPABASE_DB_URL', Deno.env.get('SUPABASE_DB_URL') ?? ''],
        ['SUPABASE_JWT_SECRET', JWT_SECRET ?? ''],
      ],
    });

    return await worker.fetch(req);
  } catch {
    return new Response(JSON.stringify({ error: `função "${nome}" não encontrada` }), {
      status: STATUS_CODE.NotFound,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
