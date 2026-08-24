export type RecurrenceMode = 'calendar' | 'interval_from_completion';

export function isoWeekday(date: Date): number {
  const day = date.getUTCDay();
  return day === 0 ? 7 : day;
}

// Data pura, sem relógio: o `anchor` entra por parâmetro para o teste ser
// determinístico. Trabalha em UTC porque a coluna `due_date` é `date` (sem
// fuso) e o que importa é o dia do calendário, não o instante.
export function nextDueDate(
  mode: RecurrenceMode,
  rule: number | null,
  intervalDays: number | null,
  anchor: Date,
): Date {
  const year = anchor.getUTCFullYear();
  const month = anchor.getUTCMonth();
  const day = anchor.getUTCDate();

  if (mode === 'calendar') {
    const weekday = rule ?? 1;
    const diff = (weekday - isoWeekday(anchor) + 7) % 7;
    return new Date(Date.UTC(year, month, day + diff));
  }

  return new Date(Date.UTC(year, month, day + (intervalDays ?? 1)));
}
