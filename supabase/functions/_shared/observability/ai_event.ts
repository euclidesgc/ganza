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

export async function hashContent(content: string): Promise<string> {
  const bytes = new TextEncoder().encode(content);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

export function logAiEvent(event: AiEvent): void {
  console.info(JSON.stringify(event));
}
