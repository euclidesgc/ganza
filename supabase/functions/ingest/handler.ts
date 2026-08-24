import { createClient } from '@supabase/supabase-js';
import { buildEnvelope } from '../_shared/ai/prompt_envelope.ts';
import { parseProposals } from '../_shared/ai/proposal_schema.ts';
import { writeProposals } from '../_shared/ai/proposal_writer.ts';
import { assertWithinLimits } from '../_shared/ai/limits.ts';
import { hashContent, logAiEvent } from '../_shared/observability/ai_event.ts';
import { callProvider, resolveProvider } from '../_shared/ai/execute.ts';

interface ApiError {
  code: string;
  message: string;
}

const MAX_CONTENT = 4000;

const SYSTEM_INSTRUCTION = [
  'Você extrai registros de uma mensagem em português e devolve JSON estrito.',
  'Devolva apenas uma lista JSON de propostas, cada uma com "kind" e "payload".',
  'kinds permitidos: create_transaction, create_task, create_note, create_routine, create_commitment, attach_document.',
  'create_transaction exige payload com direction ("in"|"out"), amount (centavos inteiros) e description.',
  'create_routine exige payload com name, recurrence_mode ("calendar" ou "interval_from_completion"); no modo "calendar" inclua recurrence_rule (1=segunda..7=domingo); no modo "interval_from_completion" inclua interval_days (inteiro positivo).',
  'Não invente campos nem verbos. Se não houver registro, devolva [].',
].join('\n');

function errorResponse(code: string, message: string, status: number): Response {
  return Response.json({ error: { code, message } satisfies ApiError }, { status });
}

function normalizedContent(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (trimmed.length < 1 || trimmed.length > MAX_CONTENT) return null;
  return trimmed;
}

export default async function handler(req: Request): Promise<Response> {
  if (req.method !== 'POST') {
    return errorResponse('method_not_allowed', 'use POST', 405);
  }

  const authorization = req.headers.get('Authorization');
  if (!authorization) {
    return errorResponse('unauthorized', 'sessão ausente', 401);
  }

  let raw: unknown;
  try {
    raw = await req.json();
  } catch {
    return errorResponse('invalid_json', 'corpo da requisição não é um JSON válido', 400);
  }
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    return errorResponse('invalid_json', 'corpo da requisição precisa ser um objeto JSON', 400);
  }

  const content = normalizedContent((raw as Record<string, unknown>).content);
  if (content === null) {
    return errorResponse(
      'content_invalido',
      `content precisa ter entre 1 e ${MAX_CONTENT} caracteres`,
      400,
    );
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !supabaseAnonKey) {
    return errorResponse('internal_error', 'configuração do servidor ausente', 500);
  }

  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const limits = await assertWithinLimits(userClient, {
    taskType: 'extract_record',
    content,
  });
  if (!limits.ok) {
    return errorResponse(limits.code, limits.code, limits.status);
  }

  const { data: message, error: messageError } = await userClient
    .from('messages')
    .insert({ role: 'user', content, origin: 'user_typed' })
    .select('id')
    .single();
  if (messageError || !message) {
    console.error('messages insert falhou', { code: messageError?.code });
    return errorResponse('internal_error', 'não foi possível registrar a mensagem', 500);
  }

  let provider;
  try {
    if (!serviceRoleKey) throw new Error('missing_service_role');
    const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    provider = await resolveProvider('extract_record', serviceClient);
  } catch {
    return errorResponse('internal_error', 'provedor de IA indisponível', 502);
  }

  const envelope = buildEnvelope(SYSTEM_INSTRUCTION, [
    { origin: 'user_typed', text: content },
  ]);
  if ('code' in envelope) {
    return errorResponse('envelope_too_large', 'mensagem grande demais', 413);
  }

  const startedAt = Date.now();
  let modelText: string;
  try {
    modelText = await callProvider(
      provider,
      envelope.systemInstruction,
      envelope.dataParts,
    );
  } catch (error) {
    const code = error instanceof Error ? error.message : 'provider_error';
    await logAiEvent({
      taskType: 'extract_record',
      providerName: provider.kind,
      model: provider.model,
      status: 'error',
      costMicros: 0,
      latencyMs: Date.now() - startedAt,
      contentSha256: await hashContent(content),
      messageId: message.id as string,
      rejectionCode: code,
    });
    return errorResponse('provider_error', 'a IA não conseguiu responder', 502);
  }

  await logAiEvent({
    taskType: 'extract_record',
    providerName: provider.kind,
    model: provider.model,
    status: 'success',
    costMicros: 0,
    latencyMs: Date.now() - startedAt,
    contentSha256: await hashContent(content),
    messageId: message.id as string,
  });

  let parsedRaw: unknown;
  try {
    parsedRaw = JSON.parse(modelText);
  } catch {
    return errorResponse('provider_error', 'a IA devolveu uma resposta inválida', 502);
  }

  const parsed = parseProposals(parsedRaw);
  if (!parsed.ok) {
    return errorResponse('provider_error', parsed.code, 502);
  }

  const written = await writeProposals(
    userClient,
    message.id as string,
    parsedRaw,
  );
  if (!written.ok) {
    return errorResponse('write_failed', written.code, 500);
  }

  return Response.json({ proposals: parsed.value }, { status: 200 });
}
