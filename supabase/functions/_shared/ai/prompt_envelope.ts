const invisibleChars = /[\u200b-\u200f\u202a-\u202e\u2066-\u2069]/g;
const markerOpen = '<ganza:data:';
const markerClose = '</ganza:data:';
const maxPartChars = 4000;
const maxTotalChars = 16000;

export interface EnvelopeSource {
  origin: string;
  text: string;
}

export interface EnvelopeDataPart {
  origin: string;
  text: string;
  truncated: boolean;
}

export interface Envelope {
  systemInstruction: string;
  dataParts: EnvelopeDataPart[];
}

export type BuildEnvelopeResult = Envelope | { code: 'envelope_too_large' };

function sanitize(text: string): string {
  return text
    .replace(invisibleChars, '')
    .replace(new RegExp(`${markerClose}[^>]*>`, 'g'), '');
}

export function buildEnvelope(
  systemInstruction: string,
  sources: EnvelopeSource[],
): BuildEnvelopeResult {
  const nonce = crypto.randomUUID();
  const dataParts: EnvelopeDataPart[] = [];
  let total = 0;

  for (const source of sources) {
    const sanitized = sanitize(source.text);
    const truncated = sanitized.length > maxPartChars;
    const text = truncated ? sanitized.slice(0, maxPartChars) : sanitized;
    total += text.length;
    if (total > maxTotalChars) {
      return { code: 'envelope_too_large' };
    }
    dataParts.push({
      origin: source.origin,
      text: `${markerOpen}${nonce}>\n${text}\n${markerClose}${nonce}>`,
      truncated,
    });
  }

  return { systemInstruction, dataParts };
}
