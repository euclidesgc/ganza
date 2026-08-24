import { assertEquals } from '@std/assert';
import { findMatch, type OccurrenceCandidate } from './conciliation.ts';

Deno.test('casa por valor igual em janela de 5 dias', () => {
  const match = findMatch(
    { amount: 4500, occurred_at: '2026-08-24T12:00:00Z' },
    [
      { id: 'o1', expected_amount: 4500, due_date: '2026-08-26' },
      { id: 'o2', expected_amount: 9999, due_date: '2026-08-25' },
    ],
  );
  assertEquals(match?.id, 'o1');
});

Deno.test('a ocorrência mais próxima da data vence', () => {
  const match = findMatch(
    { amount: 4500, occurred_at: '2026-08-24T12:00:00Z' },
    [
      { id: 'longe', expected_amount: 4500, due_date: '2026-08-29' },
      { id: 'perto', expected_amount: 4500, due_date: '2026-08-25' },
    ],
  );
  assertEquals(match?.id, 'perto');
});

Deno.test('fora da janela de 5 dias devolve null', () => {
  const match = findMatch(
    { amount: 4500, occurred_at: '2026-08-24T12:00:00Z' },
    [{ id: 'o1', expected_amount: 4500, due_date: '2026-08-30' }],
  );
  assertEquals(match, null);
});

Deno.test('valor diferente devolve null', () => {
  const match = findMatch(
    { amount: 4500, occurred_at: '2026-08-24T12:00:00Z' },
    [{ id: 'o1', expected_amount: 4600, due_date: '2026-08-24' }],
  );
  assertEquals(match, null);
});

Deno.test('ocorrência sem valor previsto é ignorada', () => {
  const match = findMatch(
    { amount: 4500, occurred_at: '2026-08-24T12:00:00Z' },
    [{ id: 'o1', expected_amount: null, due_date: '2026-08-24' }] as OccurrenceCandidate[],
  );
  assertEquals(match, null);
});
