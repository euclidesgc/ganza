import postgres from 'postgres';

// Separado do index.ts para poder ser testado sem subir um servidor: o
// `Deno.serve` do index é a borda, isto é o comportamento.
export default async function handler(): Promise<Response> {
  const url = Deno.env.get('SUPABASE_DB_URL');

  if (!url) {
    return Response.json({ status: 'degraded', database: 'sem SUPABASE_DB_URL' }, { status: 503 });
  }

  const sql = postgres(url, { max: 1, idle_timeout: 5, connect_timeout: 5 });

  try {
    await sql`select 1`;
    return Response.json({ status: 'ok', database: 'reachable' });
  } catch {
    return Response.json({ status: 'degraded', database: 'unreachable' }, { status: 503 });
  } finally {
    await sql.end();
  }
}
