export interface OfxTransaction {
  fitId: string;
  postedDate: string;
  amountCents: number;
  memo: string;
  type: string;
}

function tagValue(body: string, name: string): string | null {
  const match = body.match(new RegExp(`<${name}>([^<]*)`, 'i'));
  return match ? match[1].trim() : null;
}

function normalizeDate(raw: string): string {
  if (/^\d{8}$/.test(raw)) {
    return `${raw.slice(0, 4)}-${raw.slice(4, 6)}-${raw.slice(6, 8)}`;
  }
  return raw;
}

// Parser determinístico de OFX: funciona tanto no SGML 1.x (tags sem fechar)
// quanto no XML 2.x, porque extrai cada campo como `<TAG>valor` até o próximo
// `<`. Não é IA; não fala com rede.
export function parseOfx(raw: string): OfxTransaction[] {
  const blocks = raw.split(/<STMTTRN>/i).slice(1);
  const transactions: OfxTransaction[] = [];

  for (const block of blocks) {
    const body = block.split(/<\/STMTTRN>/i)[0];
    const fitId = tagValue(body, 'FITID');
    const postedDate = tagValue(body, 'DTPOSTED');
    const amountRaw = tagValue(body, 'TRNAMT');
    if (!fitId || !postedDate || !amountRaw) continue;

    const amount = Math.round(parseFloat(amountRaw) * 100);
    if (!Number.isFinite(amount)) continue;

    transactions.push({
      fitId,
      postedDate: normalizeDate(postedDate),
      amountCents: amount,
      memo: tagValue(body, 'MEMO') ?? '',
      type: tagValue(body, 'TRNTYPE') ?? 'OTHER',
    });
  }

  return transactions;
}
