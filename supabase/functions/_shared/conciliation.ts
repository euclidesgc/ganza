export interface Movement {
  amount: number;
  occurred_at: string;
}

export interface OccurrenceCandidate {
  id: string;
  expected_amount: number | null;
  due_date: string;
}

const CENTS_TOLERANCE = 1;
const DAYS_WINDOW = 5;

function dayIndex(dateIso: string): number {
  return Math.floor(new Date(`${dateIso}T00:00:00Z`).getTime() / 86_400_000);
}

// Match por valor igual (± centavos) em janela de ±5 dias; a ocorrência mais
// próxima da data vence. Determinístico: mesma entrada, mesmo resultado.
export function findMatch(
  movement: Movement,
  candidates: OccurrenceCandidate[],
): OccurrenceCandidate | null {
  let best: OccurrenceCandidate | null = null;
  let bestDays = Number.POSITIVE_INFINITY;

  for (const candidate of candidates) {
    if (candidate.expected_amount === null) continue;
    if (Math.abs(candidate.expected_amount - movement.amount) > CENTS_TOLERANCE) {
      continue;
    }
    const days = Math.abs(
      dayIndex(candidate.due_date) - dayIndex(movement.occurred_at.slice(0, 10)),
    );
    if (days > DAYS_WINDOW) continue;
    if (days < bestDays) {
      best = candidate;
      bestDays = days;
    }
  }

  return best;
}
