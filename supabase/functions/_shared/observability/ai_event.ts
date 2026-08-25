export interface AiEvent {
  taskType: string;
  providerName: string;
  model: string;
  status: string;
  promptTokens?: number;
  completionTokens?: number;
  costMicros: number;
  latencyMs: number;
  contentSha256: string;
  messageId?: string;
  rejectionCode?: string;
}

export class AiUsageWriteError extends Error {
  constructor() {
    super('ai_usage_write_failed');
  }
}

export async function hashContent(content: string): Promise<string> {
  const bytes = new TextEncoder().encode(content);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

export async function logAiEvent(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  event: AiEvent,
): Promise<void> {
  console.info(JSON.stringify(event));
  const { error } = await supabase.from('ai_usage').insert({
    task_type: event.taskType,
    provider_name: event.providerName,
    model: event.model,
    status: event.status,
    prompt_tokens: event.promptTokens,
    completion_tokens: event.completionTokens,
    cost_micros: event.costMicros,
    latency_ms: event.latencyMs,
    content_sha256: event.contentSha256,
    message_id: event.messageId,
    rejection_code: event.rejectionCode,
  });
  if (error) {
    throw new AiUsageWriteError();
  }
}
