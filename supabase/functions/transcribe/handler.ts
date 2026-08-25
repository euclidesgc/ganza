import { createClient } from '@supabase/supabase-js';
import { resolveProvider, transcribeAudio } from '../_shared/ai/execute.ts';
import { assertWithinLimits } from '../_shared/ai/limits.ts';
import { hashContent, logAiEvent } from '../_shared/observability/ai_event.ts';

interface ApiError {
  code: string;
  message: string;
}

const ALLOWED_MIME = new Set([
  'audio/mp4',
  'audio/mpeg',
  'audio/wav',
  'audio/webm',
  'audio/ogg',
  'audio/flac',
]);
export const MAX_AUDIO_BYTES = 10_000_000;

function errorResponse(code: string, message: string, status: number): Response {
  return Response.json({ error: { code, message } satisfies ApiError }, { status });
}

function decodedAudioSize(audioBase64: string): number | null {
  if (audioBase64.length === 0 || audioBase64.length % 4 !== 0) {
    return null;
  }

  const padding = audioBase64.endsWith('==') ? 2 : audioBase64.endsWith('=') ? 1 : 0;
  const dataLength = audioBase64.length - padding;
  for (let index = 0; index < dataLength; index += 1) {
    const code = audioBase64.charCodeAt(index);
    const isUppercase = code >= 65 && code <= 90;
    const isLowercase = code >= 97 && code <= 122;
    const isDigit = code >= 48 && code <= 57;
    if (!isUppercase && !isLowercase && !isDigit && code !== 43 && code !== 47) {
      return null;
    }
  }
  for (let index = dataLength; index < audioBase64.length; index += 1) {
    if (audioBase64.charCodeAt(index) !== 61) {
      return null;
    }
  }

  return (audioBase64.length / 4) * 3 - padding;
}

function aiUsageWriteFailureResponse(): Response {
  return errorResponse(
    'ai_usage_write_failed',
    'não foi possível registrar a auditoria da IA',
    500,
  );
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

  const body = raw as Record<string, unknown>;
  const audioBase64 = body.audio_base64;
  if (typeof audioBase64 !== 'string') {
    return errorResponse(
      'invalid_audio',
      'audio_base64 precisa conter um áudio em base64 válido',
      400,
    );
  }

  const audioBytes = decodedAudioSize(audioBase64);
  if (audioBytes === null || audioBytes === 0) {
    return errorResponse(
      'invalid_audio',
      'audio_base64 precisa conter um áudio em base64 válido',
      400,
    );
  }
  if (audioBytes > MAX_AUDIO_BYTES) {
    return errorResponse('audio_too_large', 'áudio acima do teto permitido', 413);
  }
  const mimeType = body.mime_type;
  if (typeof mimeType !== 'string' || !ALLOWED_MIME.has(mimeType)) {
    return errorResponse('invalid_mime_type', 'mime_type fora do conjunto suportado', 400);
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

  const limits = await assertWithinLimits(userClient, { taskType: 'transcribe_audio' });
  if (!limits.ok) {
    return errorResponse(limits.code, limits.code, limits.status);
  }

  let provider;
  try {
    if (!serviceRoleKey) throw new Error('missing_service_role');
    const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    provider = await resolveProvider('transcribe_audio', serviceClient);
  } catch {
    return errorResponse('internal_error', 'provedor de IA indisponível', 502);
  }

  const startedAt = Date.now();
  let transcript: string;
  try {
    transcript = await transcribeAudio(provider, audioBase64, mimeType);
  } catch (error) {
    const code = error instanceof Error ? error.message : 'provider_error';
    try {
      await logAiEvent(userClient, {
        taskType: 'transcribe_audio',
        providerName: provider.kind,
        model: provider.model,
        status: 'error',
        costMicros: 0,
        latencyMs: Date.now() - startedAt,
        contentSha256: await hashContent(audioBase64),
        rejectionCode: code,
      });
    } catch {
      return aiUsageWriteFailureResponse();
    }
    return errorResponse('provider_error', 'a IA não conseguiu transcrever', 502);
  }

  const normalizedTranscript = transcript.trim();
  if (normalizedTranscript.length === 0) {
    try {
      await logAiEvent(userClient, {
        taskType: 'transcribe_audio',
        providerName: provider.kind,
        model: provider.model,
        status: 'success',
        costMicros: 0,
        latencyMs: Date.now() - startedAt,
        contentSha256: await hashContent(audioBase64),
      });
    } catch {
      return aiUsageWriteFailureResponse();
    }
    return errorResponse('audio_not_understood', 'não entendi o áudio', 422);
  }

  const { data: message, error: messageError } = await userClient
    .from('messages')
    .insert({
      role: 'user',
      content: '',
      origin: 'transcript',
      media_type: 'audio',
      transcript: normalizedTranscript,
    })
    .select('id')
    .single();
  if (messageError || !message) {
    return errorResponse('internal_error', 'não foi possível registrar a mensagem', 500);
  }

  try {
    await logAiEvent(userClient, {
      taskType: 'transcribe_audio',
      providerName: provider.kind,
      model: provider.model,
      status: 'success',
      costMicros: 0,
      latencyMs: Date.now() - startedAt,
      contentSha256: await hashContent(audioBase64),
      messageId: message.id as string,
    });
  } catch {
    await userClient.from('messages').delete().eq('id', message.id as string);
    return aiUsageWriteFailureResponse();
  }

  return Response.json(
    { transcript: normalizedTranscript, message_id: message.id },
    { status: 200 },
  );
}
