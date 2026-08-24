const combiningMarks = /[\u0300-\u036f]/g;
const nonKeyChars = /[^a-z ]/g;
const repeatedSpaces = /\s+/g;

export function normalizeDescription(raw: string): string {
  return raw
    .normalize('NFKD')
    .replace(combiningMarks, '')
    .toLowerCase()
    .replace(nonKeyChars, ' ')
    .replace(repeatedSpaces, ' ')
    .trim()
    .slice(0, 64);
}
