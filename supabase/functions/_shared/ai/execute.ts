export interface AiRoute {
  provider_id: string;
  model: string;
}

export interface AiProvider {
  kind: string;
  base_url: string;
  secret_ref: string;
}

export interface ResolvedProvider {
  kind: string;
  baseUrl: string;
  model: string;
  apiKey: string;
}

export async function resolveProvider(
  taskType: string,
  // deno-lint-ignore no-explicit-any
  service: any,
): Promise<ResolvedProvider> {
  const { data: route, error: routeError } = await service
    .from('ai_routes')
    .select('provider_id, model')
    .eq('task_type', taskType)
    .maybeSingle();
  if (routeError || !route) {
    throw new Error('route_not_found');
  }

  const { data: provider, error: providerError } = await service
    .from('ai_providers')
    .select('kind, base_url, secret_ref')
    .eq('id', route.provider_id as string)
    .maybeSingle();
  if (providerError || !provider) {
    throw new Error('provider_not_found');
  }

  const { data: secret, error: secretError } = await service
    .from('vault.decrypted_secrets')
    .select('decrypted_secret')
    .eq('name', provider.secret_ref as string)
    .maybeSingle();
  if (secretError || !secret || typeof secret.decrypted_secret !== 'string') {
    throw new Error('secret_not_found');
  }

  return {
    kind: provider.kind as string,
    baseUrl: provider.base_url as string,
    model: route.model as string,
    apiKey: secret.decrypted_secret,
  };
}

export async function callProvider(
  provider: ResolvedProvider,
  systemInstruction: string,
  dataParts: { origin: string; text: string }[],
): Promise<string> {
  if (provider.kind !== 'gemini') {
    throw new Error('unsupported_provider');
  }

  const contents = dataParts.map((part) => ({
    role: 'user',
    parts: [{ text: part.text }],
  }));

  const url = `${provider.baseUrl}/v1beta/models/${provider.model}:generateContent`;
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': provider.apiKey,
    },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: systemInstruction }] },
      contents,
    }),
  });

  if (!response.ok) {
    throw new Error(`provider_error_${response.status}`);
  }

  const payload = await response.json();
  const text = (payload as { candidates?: { content?: { parts?: { text?: string }[] } }[] })
    .candidates?.[0]?.content?.parts?.[0]?.text;
  if (typeof text !== 'string') {
    throw new Error('provider_response_invalid');
  }
  return text;
}

export async function transcribeAudio(
  provider: ResolvedProvider,
  audioBase64: string,
  mimeType: string,
): Promise<string> {
  if (provider.kind !== 'gemini') {
    throw new Error('unsupported_provider');
  }

  const url = `${provider.baseUrl}/v1beta/models/${provider.model}:generateContent`;
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': provider.apiKey,
    },
    body: JSON.stringify({
      systemInstruction: {
        parts: [{ text: 'Transcreva o áudio em português, devolvendo apenas o texto.' }],
      },
      contents: [
        {
          role: 'user',
          parts: [
            { inline_data: { mime_type: mimeType, data: audioBase64 } },
          ],
        },
      ],
    }),
  });

  if (!response.ok) {
    throw new Error(`provider_error_${response.status}`);
  }

  const payload = await response.json();
  const text = (payload as { candidates?: { content?: { parts?: { text?: string }[] } }[] })
    .candidates?.[0]?.content?.parts?.[0]?.text;
  if (typeof text !== 'string') {
    throw new Error('provider_response_invalid');
  }
  return text;
}
