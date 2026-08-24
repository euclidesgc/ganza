import { assertEquals } from '@std/assert';
import { isoWeekday, nextDueDate } from './routine_math.ts';

function dia(dia: number, mes: number, ano: number): Date {
  return new Date(Date.UTC(ano, mes - 1, dia));
}

function fmt(date: Date): string {
  const ano = date.getUTCFullYear();
  const mes = String(date.getUTCMonth() + 1).padStart(2, '0');
  const dia = String(date.getUTCDate()).padStart(2, '0');
  return `${ano}-${mes}-${dia}`;
}

Deno.test('isoWeekday: 2026-08-24 é segunda (1)', () => {
  assertEquals(isoWeekday(dia(24, 8, 2026)), 1);
});

Deno.test('calendar cai no próximo dia da semana', () => {
  // 2026-08-25 é terça; o próximo sábado (6) é 2026-08-29.
  assertEquals(fmt(nextDueDate('calendar', 6, null, dia(25, 8, 2026))), '2026-08-29');
});

Deno.test('calendar no próprio dia da semana devolve o mesmo dia', () => {
  // 2026-08-24 é segunda (1); pedir segunda devolve o próprio dia.
  assertEquals(fmt(nextDueDate('calendar', 1, null, dia(24, 8, 2026))), '2026-08-24');
});

Deno.test('interval_from_completion soma intervalDays ao anchor', () => {
  assertEquals(
    fmt(nextDueDate('interval_from_completion', null, 15, dia(24, 8, 2026))),
    '2026-09-08',
  );
});

Deno.test('interval atravessa a virada de mês', () => {
  assertEquals(
    fmt(nextDueDate('interval_from_completion', null, 10, dia(28, 8, 2026))),
    '2026-09-07',
  );
});
